import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/app_state.dart';

/// Widget “orb” del timer:
/// - disegna un anello di progresso con CustomPainter
/// - mostra un cerchio centrale con gradiente
/// - quando `running`, pulsa (scale in/out) tramite AnimationController
/// - quando `finished`, mostra un glow più evidente (AnimatedOpacity)
class OrbTimer extends StatefulWidget {
  const OrbTimer({
    super.key,
    required this.progress,
    required this.state,
    required this.accentColor,
  });

  /// Progresso del timer (atteso 0..1).
  /// Viene clamped nel painter per sicurezza.
  final double progress;

  /// Stato del timer (ready/running/paused/finished).
  final FocusTimerState state;

  /// Colore principale usato per anello e riempimento (coerente con la label).
  final Color accentColor;

  @override
  State<OrbTimer> createState() => _OrbTimerState();
}

class _OrbTimerState extends State<OrbTimer>
    with SingleTickerProviderStateMixin {
  /// Controller che gestisce l’animazione di “pulse”.
  ///
  /// - `vsync: this` usa il ticker del framework per non animare offscreen
  /// - durata 1800ms per un ritmo morbido
  ///
  /// Un AnimationController va sempre disposed quando non serve più. 
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse(); // Allinea subito l’animazione allo stato iniziale.
  }

  @override
  void didUpdateWidget(covariant OrbTimer oldWidget) {
    super.didUpdateWidget(oldWidget);

    /// Se cambia lo stato del timer, aggiorna se l’animazione deve andare o fermarsi.
    if (oldWidget.state != widget.state) {
      _syncPulse();
    }
  }

  /// Avvia o ferma la pulsazione in base allo stato.
  ///
  /// - running: `_pulse.repeat(reverse: true)` crea un loop avanti/indietro 
  /// - altri stati: stop (mantiene l’ultimo valore del controller)
  void _syncPulse() {
    if (widget.state == FocusTimerState.running) {
      _pulse.repeat(reverse: true); 
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    /// Dispose del controller prima di `super.dispose()` per evitare leak. 
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    /// Colore accent principale e una variante più scura (lightness -0.14)
    /// per creare un gradiente con un minimo di profondità.
    final accent = widget.accentColor;
    final accent2 = _shiftLightness(accent, -0.14);

    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          /// Anello di progresso disegnato a mano (CustomPainter).
          CustomPaint(
            size: const Size(250, 250),
            painter: _ProgressRingPainter(
              progress: widget.progress,
              bg: c.outlineVariant.withValues(alpha: 0.28),
              fg: accent,
            ),
          ),

          /// Glow “di completamento”: appare solo quando finished.
          /// AnimatedOpacity fa un fade-in/out morbido.
          AnimatedOpacity(
            opacity: widget.state == FocusTimerState.finished ? 1 : 0,
            duration: const Duration(milliseconds: 420),
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.38),
                    blurRadius: 55,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
          ),

          /// Cerchio centrale “orb” che pulsa quando running.
          /// AnimatedBuilder ricostruisce solo questa parte quando `_pulse` cambia.
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final running = widget.state == FocusTimerState.running;

              /// Scale leggero (max ~ +4.5%) per un effetto breathing.
              final scale = running ? 1 + _pulse.value * 0.045 : 1.0;

              return Transform.scale(
                scale: scale,
                child: AnimatedContainer(
                  /// Quando cambi stato (es. paused), cambia blurRadius con animazione.
                  duration: const Duration(milliseconds: 300),
                  width: 168,
                  height: 168,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.88),
                        accent2.withValues(alpha: 0.70),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.30),

                        /// In pausa: ombra più “calma”; in running: più intensa.
                        blurRadius:
                            widget.state == FocusTimerState.paused ? 16 : 32,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Crea una variante del colore modificandone la lightness in HSL.
  ///
  /// - converte Color -> HSLColor
  /// - aggiunge `delta` alla lightness (clamp 0..1)
  /// - riconverte in Color
  ///
  /// `withLightness()` crea una copia con lightness sostituita. 
  Color _shiftLightness(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    final l = (hsl.lightness + delta).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }
}

/// Painter dell’anello di progresso.
/// Disegna:
/// 1) cerchio base (bg)
/// 2) arco (fg) con sweep proporzionale al progress
class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.bg,
    required this.fg,
  });

  /// Progresso 0..1.
  final double progress;

  /// Colore dell’anello “vuoto”.
  final Color bg;

  /// Colore dell’arco di avanzamento.
  final Color fg;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const stroke = 12.0;

    /// Raggio: metà larghezza meno lo stroke (così l’anello non esce dal canvas).
    final radius = size.width / 2 - stroke;

    final base = Paint()
      ..color = bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final arc = Paint()
      ..color = fg
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // Cerchio di fondo.
    canvas.drawCircle(center, radius, base);

    /// Sweep angle: 2π * progress.
    /// clamp(0, 1) evita valori fuori range.
    final sweep = (2 * math.pi) * progress.clamp(0, 1);

    // Arco: parte da -π/2 (ore 12) e va in senso orario.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    /// Repaint solo se cambiano i dati usati nel paint:
    /// - progress
    /// - bg / fg
    ///
    /// Se ritorni false, Flutter può ottimizzare e saltare repaint inutili. 
    return oldDelegate.progress != progress ||
        oldDelegate.bg != bg ||
        oldDelegate.fg != fg;
  }
}
