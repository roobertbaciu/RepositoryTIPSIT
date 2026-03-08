import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/label.dart';
import '../state/app_state.dart';
import '../widgets/gesture_help_sheet.dart';
import '../widgets/orb_timer.dart';
import '../widgets/parallax_background.dart';

/// Schermata del timer (Focus Timer).
///
/// È uno StatefulWidget perché:
/// - gestisce interazioni/gesture (drag, tap, ecc.)
/// - può mantenere stato UI locale (es. coordinate del drag, throttling messaggi)
/// - ricostruisce l'interfaccia in base allo stato che cambia (anche via Provider)
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  /// Crea l'oggetto State associato a questo widget.
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  /// Coordinata Y (logical pixels) dove e iniziato il drag.
  /// `null` = nessun drag attivo.
  double? _dragStartY;

  /// Coordinata Y corrente durante il drag.
  double? _dragCurrentY;

  /// Tick usato per evitare messaggi transient ripetuti.
  int _lastMessageTick = 0;

  /// Soglia minima distanza per considerare swipe valido.
  static const double _distanceThreshold = 80;

  /// Soglia minima velocita per considerare swipe deciso.
  static const double _velocityThreshold = 300;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final c = Theme.of(context).colorScheme;
    final accentColor = app.currentLabelColor;

    if (app.messageTick != _lastMessageTick && app.transientMessage.isNotEmpty) {
      _lastMessageTick = app.messageTick;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(app.transientMessage),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 1400),
          ),
        );
      });
    }

    return Stack(
      children: [
        Positioned.fill(
          child: ParallaxBackground(accentColor: accentColor),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    Text('FlowFocus', style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    ActionChip(
                      avatar: Icon(Icons.sell_outlined, size: 18, color: accentColor),
                      label: Text(app.currentLabel),
                      side: BorderSide(color: accentColor.withValues(alpha: 0.38)),
                      onPressed: _openLabelSheet,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Guida gesti',
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => const GestureHelpSheet(),
                      ),
                      icon: const Icon(Icons.help_outline_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (d) => _dragStartY = d.globalPosition.dy,
                  onVerticalDragUpdate: (d) => _dragCurrentY = d.globalPosition.dy,
                  onVerticalDragEnd: (d) {
                    final start = _dragStartY;
                    final current = _dragCurrentY;
                    if (start == null || current == null) return;

                    final distance = current - start;
                    final velocity = d.primaryVelocity ?? 0;
                    if (distance.abs() > _distanceThreshold &&
                        velocity.abs() > _velocityThreshold) {
                      if (distance < 0) {
                        app.startPauseResume();
                      } else {
                        app.stop();
                      }
                    }

                    _dragStartY = null;
                    _dragCurrentY = null;
                  },
                  onDoubleTap: app.reset,
                  onLongPress: _openLabelSheet,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OrbTimer(
                        progress: app.progress,
                        state: app.timerState,
                        accentColor: accentColor,
                      ),
                      const SizedBox(height: 26),
                      Text(
                        _formatMmSs(app.remainingSeconds),
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: c.onSurface,
                              letterSpacing: 1.6,
                            ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _statusColor(c, app.timerState).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: _statusColor(c, app.timerState).withValues(alpha: 0.40),
                          ),
                        ),
                        child: Text(
                          _stateLabel(app.timerState),
                          style: TextStyle(
                            color: _statusColor(c, app.timerState),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerHighest.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.outlineVariant.withValues(alpha: 0.48)),
                  ),
                  child: Row(
                    children: [
                      _gestureItem(context, Icons.swipe_up_alt, 'Swipe su', 'Avvia/Pausa'),
                      _gestureItem(context, Icons.swipe_down_alt, 'Swipe giu', 'Stop'),
                      _gestureItem(context, Icons.touch_app, 'Doppio tap', 'Reset'),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  'Inclina sx/dx per regolare i minuti • Agita per avvio rapido (10 min) • Tieni premuto per label',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: c.onSurfaceVariant.withValues(alpha: 0.88)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openLabelSheet() async {
    final app = context.read<AppState>();
    var selectedLabel = app.currentLabel;
    var customLabel = '';
    var selectedColor = app.currentLabelColor;

    final result = await showModalBottomSheet<_LabelSheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + insets),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Session Label', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: FocusLabels.defaults.map((label) {
                      return ChoiceChip(
                        selected: label == selectedLabel,
                        label: Text(label),
                        onSelected: (_) {
                          setStateSheet(() {
                            selectedLabel = label;
                            selectedColor = app.colorForLabel(label);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Custom label',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => customLabel = value,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('Color', style: Theme.of(ctx).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: FocusLabels.palette.map((colorValue) {
                      final color = Color(colorValue);
                      final isSelected = color.toARGB32() == selectedColor.toARGB32();
                      return GestureDetector(
                        onTap: () => setStateSheet(() => selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(ctx).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonal(
                    onPressed: () {
                      final resolvedLabel =
                          customLabel.trim().isNotEmpty ? customLabel.trim() : selectedLabel;
                      Navigator.pop(
                        ctx,
                        _LabelSheetResult(label: resolvedLabel, color: selectedColor),
                      );
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    // Pulisce eventuali spazi iniziali/finali della label.
    final clean = result.label.trim();
    if (clean.isEmpty) return;

    // Aggiorna stato dopo il frame corrente per evitare update
    // durante la fase di chiusura della bottom sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      app.setLabel(clean);
      app.setLabelColor(clean, result.color);
    });
  }

  /// Converte secondi totali in formato `mm:ss`.
  String _formatMmSs(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Mapping stato timer -> etichetta UI.
  String _stateLabel(FocusTimerState state) {
    switch (state) {
      case FocusTimerState.ready:
        return 'READY';
      case FocusTimerState.running:
        return 'RUNNING';
      case FocusTimerState.paused:
        return 'PAUSED';
      case FocusTimerState.finished:
        return 'FINISHED';
    }
  }

  /// Mapping stato timer -> colore pill stato.
  Color _statusColor(ColorScheme c, FocusTimerState state) {
    switch (state) {
      case FocusTimerState.ready:
        return c.primary;
      case FocusTimerState.running:
        return c.tertiary;
      case FocusTimerState.paused:
        return c.secondary;
      case FocusTimerState.finished:
        return c.error;
    }
  }

  /// Item singolo della barra gesture in basso.
  Widget _gestureItem(BuildContext context, IconData icon, String title, String subtitle) {
    final c = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: c.onSurfaceVariant),
          const SizedBox(height: 2),
          Text(title, style: Theme.of(context).textTheme.labelSmall),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: c.onSurfaceVariant.withValues(alpha: 0.86)),
          ),
        ],
      ),
    );
  }
}

/// Risultato della bottom sheet label (nome + colore).
class _LabelSheetResult {
  _LabelSheetResult({required this.label, required this.color});

  final String label;
  final Color color;
}
