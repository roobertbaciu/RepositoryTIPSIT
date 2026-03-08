import 'package:flutter/material.dart';

class ParallaxBackground extends StatelessWidget {
  const ParallaxBackground({
    super.key,
    required this.accentColor,
  });

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final topTone = _shiftLightness(accentColor, 0.12);
    final midTone = _shiftLightness(accentColor, 0.03);
    final deepTone = _shiftLightness(accentColor, -0.08);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                c.surface,
                topTone.withValues(alpha: 0.10),
                midTone.withValues(alpha: 0.18),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Stack(
          children: [
            Positioned(
              top: -80,
              left: -40,
              child: _blob(
                size: 260,
                color: topTone.withValues(alpha: 0.22),
              ),
            ),
            Positioned(
              bottom: -90,
              right: -20,
              child: _blob(
                size: 300,
                color: deepTone.withValues(alpha: 0.20),
              ),
            ),
          ],
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _StarsPainter(
              color: c.onSurface.withValues(alpha: 0.18),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: double.infinity,
                height: 260,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accentColor.withValues(alpha: 0.20),
                      midTone.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _shiftLightness(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    final l = (hsl.lightness + delta).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }

  Widget _blob({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 60,
            spreadRadius: 12,
          ),
        ],
      ),
    );
  }
}

/// Painter che disegna un piccolo campo di “stelle” (puntini) in posizioni
/// pseudo-casuali ma deterministiche.
///
/// Nota: le posizioni non sono realmente random; derivano da una formula
/// basata su `i`, così ottieni sempre lo stesso pattern a parità di size.
class _StarsPainter extends CustomPainter {
  _StarsPainter({required this.color});

  /// Colore con cui vengono disegnate le stelle.
  /// Se cambi questo valore, il painter deve ridisegnare.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    /// Paint configurato una sola volta (più efficiente che ricrearlo per stella).
    final p = Paint()..color = color;

    /// Disegna 28 “stelle”.
    /// L’uso di mod (%) e moltiplicatori (73, 47, +19) genera una distribuzione
    /// sparsa sul canvas, normalizzata in [0,1] e poi scalata su width/height.
    for (var i = 0; i < 28; i++) {
      // x e y in coordinate canvas: [0..size.width], [0..size.height]
      final x = ((i * 73) % 100) / 100 * size.width;
      final y = ((i * 47 + 19) % 100) / 100 * size.height;

      /// Raggio alternato per varietà: ogni 3 stelle una è un po’ più grande.
      final r = i % 3 == 0 ? 1.8 : 1.1;

      /// drawCircle disegna un cerchio centrato in Offset(x, y) con raggio `r`. 
      canvas.drawCircle(Offset(x, y), r, p); 
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) {
    /// Repaint solo se cambia un input che altera l’output visivo.
    /// Qui l’unico input è `color`, quindi se cambia colore ridisegni;
    /// se è uguale, Flutter può ottimizzare e saltare repaint. 
    return oldDelegate.color != color; 
  }
}
