import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/label.dart';
import '../models/session_record.dart';
import '../services/session_storage.dart';

/// Stati possibili del timer focus.
enum FocusTimerState {
  ready,    // Pronto: puoi scegliere minuti e avviare
  running,  // In esecuzione: countdown attivo
  paused,   // In pausa: countdown fermo
  finished, // Finito: countdown a 0 e sessione registrata come completed
}

/// Stato centrale dell’app (ChangeNotifier) per il timer + storico sessioni.
///
/// Responsabilità:
/// - gestire timer (start/pause/resume/stop/reset)
/// - calcolare progress e remainingRatio per UI (anche “smooth” con ticker UI)
/// - gestire label e colori associati
/// - leggere accelerometro per tilt (regola minuti) e shake (quick start)
/// - persistere su SharedPreferences tramite SessionStorage
class AppState extends ChangeNotifier {

  /// Minuti selezionati dall’utente (solo quando timer è ready/finished).
  int selectedMinutes = 25;

  /// Secondi rimanenti nel countdown.
  int remainingSeconds = 25 * 60;

  /// Label corrente associata alla sessione (es. Study, Deep Work).
  String currentLabel = 'Study';

  /// Stato corrente del timer.
  FocusTimerState timerState = FocusTimerState.ready;

  /// Storico sessioni (più recenti davanti: vedi recordSession()).
  List<SessionRecord> sessions = [];

  /// Mappa label -> colore (int ARGB). Viene unita a defaults in load().
  Map<String, int> labelColors = {};

  /// Valori filtrati dell’accelerometro (smoothing) usati per parallax/tilt.
  double filteredX = 0;
  double filteredY = 0;
  double filteredZ = 0;

  /// Ticker “logico” 1Hz: decrementa remainingSeconds.
  Timer? _ticker;

  /// Ticker UI “smooth”: forza rebuild frequenti mentre running (per animazioni).
  Timer? _uiTicker;

  /// Subscription allo stream accelerometro (sensors_plus).
  StreamSubscription<AccelerometerEvent>? _accelSub;

  /// Throttle per evitare di regolare i minuti troppo spesso col tilt.
  DateTime _lastMinuteAdjust = DateTime.fromMillisecondsSinceEpoch(0);

  /// Throttle per evitare di triggerare lo shake più volte di fila.
  DateTime _lastShakeAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Throttle per notifiche parallax (limitare notifyListeners da sensore).
  DateTime _lastParallaxNotify = DateTime.fromMillisecondsSinceEpoch(0);

  /// Istante di inizio della sessione attiva (serve per recordSession).
  DateTime? _activeStartedAt;

  /// Istante dell’ultimo tick “secondo” (serve per remainingRatio frazionale).
  DateTime? _lastSecondTickAt;

  /// Minuti “pianificati” per la sessione attiva (freezati allo start).
  int _activePlannedMinutes = 25;

  /// Contatore che cambia quando vuoi “invalidare” un messaggio transient.
  /// La UI può ascoltare `messageTick` per rinfrescare animazioni/toast.
  int _messageTick = 0;

  /// Messaggio breve (es. “Quick Start: 10 min”).
  String _transientMessage = '';

  /// Flag di sicurezza per evitare notify dopo dispose.
  bool _isDisposed = false;

  int get messageTick => _messageTick;
  String get transientMessage => _transientMessage;

  /// Colore della label corrente (calcolato dalla mappa + defaults).
  Color get currentLabelColor => colorForLabel(currentLabel);

  /// Progress (0..1) del timer: 0 all’inizio, 1 a fine.
  /// È complementare di remainingRatio.
  double get progress {
    return 1 - remainingRatio;
  }

  /// Quota rimanente (0..1): 1 all’inizio, 0 a fine.
  ///
  /// Nota importante: include una correzione “frazionale” mentre running, usando
  /// `_lastSecondTickAt` per rendere il progresso più fluido tra due tick da 1s.
  double get remainingRatio {
    final total = _activePlannedMinutes * 60;
    if (total <= 0) {
      return 1;
    }

    var remaining = remainingSeconds.toDouble();

    // Se stai running, sottrai la frazione di secondo dall’ultimo tick,
    // così la UI può animare in modo più continuo.
    if (timerState == FocusTimerState.running && _lastSecondTickAt != null) {
      final fractional =
          DateTime.now().difference(_lastSecondTickAt!).inMilliseconds / 1000;
      remaining -= fractional.clamp(0.0, 1.0);
    }

    remaining = remaining.clamp(0.0, total.toDouble());
    return remaining / total;
  }

  /// Carica storico sessioni e colori label da storage, unendoli ai default.
  /// Poi avvia i sensori e notifica la UI.
  Future<void> load() async {
    sessions = await SessionStorage.loadSessions();

    final storedColors = await SessionStorage.loadLabelColors();

    // Merge: defaults + override da storage (se l’utente ha personalizzato).
    labelColors = {
      ...FocusLabels.defaultColorValues,
      ...storedColors,
    };

    _startSensors();
    _notifySafely();
  }

  /// Imposta la label corrente (con validazione) e assicura un colore associato.
  ///
  /// Nota: salva subito `labelColors` su storage (fire-and-forget).
  void setLabel(String value) {
    if (value.trim().isEmpty) {
      return;
    }

    currentLabel = value.trim();

    // Se è una label nuova, assegna un colore di fallback dalla palette.
    labelColors.putIfAbsent(currentLabel, () => FocusLabels.palette.first);

    SessionStorage.saveLabelColors(labelColors);
    _notifySafely();
  }

  /// Ritorna un Color per una label:
  /// - prima prova nella mappa labelColors
  /// - poi nei default
  /// - altrimenti fallback a palette.first
  Color colorForLabel(String label) {
    final value = labelColors[label] ??
        FocusLabels.defaultColorValues[label] ??
        FocusLabels.palette.first;
    return Color(value);
  }

  /// Aggiorna il colore associato a una label e persiste su storage.
  void setLabelColor(String label, Color color) {
    final clean = label.trim();
    if (clean.isEmpty) {
      return;
    }

    // Converte Color -> int ARGB (0xAARRGGBB) per salvarlo in JSON/prefs.
    labelColors[clean] = color.toARGB32();
    SessionStorage.saveLabelColors(labelColors);
    _notifySafely();
  }

  /// Gestisce il tap principale: start / pause / resume / restart dopo finished.
  ///
  /// - ready: prepara sessione e avvia ticker
  /// - running: mette in pausa e ferma ticker
  /// - paused: riprende e riavvia ticker
  /// - finished: riparte come una nuova sessione
  void startPauseResume() {
    switch (timerState) {
      case FocusTimerState.ready:
        _activePlannedMinutes = selectedMinutes;
        remainingSeconds = selectedMinutes * 60;
        _activeStartedAt = DateTime.now();
        _lastSecondTickAt = DateTime.now();
        timerState = FocusTimerState.running;
        _startTicker();
        _startUiTicker();
        break;

      case FocusTimerState.running:
        timerState = FocusTimerState.paused;
        _ticker?.cancel();
        _uiTicker?.cancel();
        break;

      case FocusTimerState.paused:
        _lastSecondTickAt = DateTime.now();
        timerState = FocusTimerState.running;
        _startTicker();
        _startUiTicker();
        break;

      case FocusTimerState.finished:
        // “Restart” con i minuti selezionati correnti.
        _activePlannedMinutes = selectedMinutes;
        remainingSeconds = selectedMinutes * 60;
        _activeStartedAt = DateTime.now();
        _lastSecondTickAt = DateTime.now();
        timerState = FocusTimerState.running;
        _startTicker();
        _startUiTicker();
        break;
    }

    _notifySafely();
  }

  /// Stop “hard”: se stavi facendo una sessione e hai fatto progresso,
  /// registra come interrupted, poi torna allo stato ready.
  void stop() {
    if (timerState == FocusTimerState.running ||
        timerState == FocusTimerState.paused) {
      // Elapsed = planned - remaining, clamp per sicurezza.
      final elapsed = (_activePlannedMinutes * 60 - remainingSeconds)
          .clamp(0, _activePlannedMinutes * 60);

      // Registra solo se ha senso (elapsed > 0) e se conosciamo l’inizio.
      if (elapsed > 0 && _activeStartedAt != null) {
        recordSession(
          status: SessionStatus.interrupted,
          actualSeconds: elapsed,
        );
      }
    }

    _ticker?.cancel();
    _uiTicker?.cancel();
    timerState = FocusTimerState.ready;
    remainingSeconds = selectedMinutes * 60;
    _activeStartedAt = null;
    _lastSecondTickAt = null;
    _notifySafely();
  }

  /// Reset: come stop, ma senza registrare sessione.
  void reset() {
    _ticker?.cancel();
    _uiTicker?.cancel();
    timerState = FocusTimerState.ready;
    remainingSeconds = selectedMinutes * 60;
    _activeStartedAt = null;
    _lastSecondTickAt = null;
    _notifySafely();
  }

  /// Regola `selectedMinutes` in base all’inclinazione (asse X filtrato).
  ///
  /// Protezioni:
  /// - funziona solo quando timer è ready (per non “rompere” una sessione in corso)
  /// - throttle: massimo una volta ogni 250ms
  /// - deadzone: se abs(x) <= 1.2 ignora (movimento lieve)
  void adjustMinutesFromTilt(double x) {
    if (timerState != FocusTimerState.ready) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastMinuteAdjust).inMilliseconds < 250) {
      return;
    }
    if (x.abs() <= 1.2) {
      return;
    }

    // Direzione del tilt.
    final sign = x >= 0 ? 1 : -1;

    // Magnitude cresce oltre la soglia 1.2: più inclini, più “scatti” aggiungi.
    final magnitude = 1 + ((x.abs() - 1.2) * 1.2).floor();
    final delta = sign * magnitude;

    final before = selectedMinutes;
    selectedMinutes = (selectedMinutes + delta).clamp(1, 60);

    // Se clamp ha bloccato il valore, non fare nulla.
    if (selectedMinutes == before) {
      return;
    }

    // Mantieni coerenti seconds + planned minutes.
    remainingSeconds = selectedMinutes * 60;
    _activePlannedMinutes = selectedMinutes;
    _lastMinuteAdjust = now;

    // Feedback aptico ogni 5 minuti “passati” (es. 25 -> 30).
    if ((before ~/ 5) != (selectedMinutes ~/ 5)) {
      HapticFeedback.lightImpact();
    }

    _notifySafely();
  }

  /// Aggiunge un record nello storico e persiste.
  ///
  /// Nota: inserisci davanti (prepend) per avere “più recenti prima”.
  void recordSession({
    required SessionStatus status,
    required int actualSeconds,
  }) {
    final now = DateTime.now();
    final startedAt = _activeStartedAt ?? now;

    final record = SessionRecord(
      label: currentLabel,
      plannedMinutes: _activePlannedMinutes,
      actualSeconds: actualSeconds,
      status: status,
      startedAt: startedAt,
      endedAt: now,
    );

    sessions = [record, ...sessions];
    SessionStorage.saveSessions(sessions);
  }

  /// Avvia il ticker 1Hz che decrementa `remainingSeconds`.
  ///
  /// - ad ogni tick: se running, decrementa e notifica
  /// - quando arriva a 0: segna finished, registra completed, ferma ticker
  void _startTicker() {
    _ticker?.cancel();
    _lastSecondTickAt = DateTime.now();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (timerState != FocusTimerState.running) {
        return;
      }

      if (remainingSeconds > 0) {
        remainingSeconds -= 1;
        _lastSecondTickAt = DateTime.now();
      }

      if (remainingSeconds <= 0) {
        remainingSeconds = 0;
        _ticker?.cancel();
        _uiTicker?.cancel();
        _lastSecondTickAt = null;

        timerState = FocusTimerState.finished;

        // Sessione completata: actualSeconds = planned * 60.
        recordSession(
          status: SessionStatus.completed,
          actualSeconds: _activePlannedMinutes * 60,
        );
      }

      _notifySafely();
    });
  }

  /// Avvia un ticker UI frequente per aggiornare animazioni/indicatori
  /// (es. orb progress) senza aspettare il tick da 1 secondo.
  void _startUiTicker() {
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (timerState == FocusTimerState.running) {
        _notifySafely();
      }
    });
  }

  /// Avvia ascolto accelerometro:
  /// - `_handleShake` per quick start
  /// - filtro low-pass su X/Y/Z (0.9/0.1) per rendere i valori più stabili
  /// - tilt -> adjustMinutesFromTilt
  /// - throttle notify per parallax (circa 30fps: ogni >=33ms)
  ///
  /// `AccelerometerEvent` include gravità (raw sensor), quindi per shake sottrai ~9.8. 
  void _startSensors() {
    _accelSub?.cancel();

    // `accelerometerEventStream()` fornisce uno stream di eventi accelerometro. 
    _accelSub = accelerometerEventStream().listen((event) {
      _handleShake(event.x, event.y, event.z);

      // Low-pass filter: smorza rumore e micro-movimenti.
      filteredX = filteredX * 0.9 + event.x * 0.1;
      filteredY = filteredY * 0.9 + event.y * 0.1;
      filteredZ = filteredZ * 0.9 + event.z * 0.1;

      // Tilt per regolare i minuti (solo se ready).
      adjustMinutesFromTilt(filteredX);

      // Riduce il numero di notify: utile se il parallax usa questi valori.
      final now = DateTime.now();
      if (now.difference(_lastParallaxNotify).inMilliseconds >= 33) {
        _lastParallaxNotify = now;
        _notifySafely();
      }
    });
  }

  /// Rileva “shake” usando la magnitudine dell’accelerazione.
  ///
  /// - calcola magnitude = sqrt(x^2 + y^2 + z^2)
  /// - confronta con 9.8 (gravità) per stimare quanto “movimento” c’è
  /// - se supera la soglia e sei in ready, fa quick start 10 min
  void _handleShake(double x, double y, double z) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    final shakeStrength = (magnitude - 9.8).abs();
    final now = DateTime.now();

    if (shakeStrength > 7.5 &&
        now.difference(_lastShakeAt).inMilliseconds > 1800 &&
        timerState == FocusTimerState.ready) {
      _lastShakeAt = now;

      // Quick start: imposta 10 minuti e avvia subito.
      selectedMinutes = 10;
      remainingSeconds = 10 * 60;
      _activePlannedMinutes = 10;
      _activeStartedAt = DateTime.now();
      _lastSecondTickAt = DateTime.now();
      timerState = FocusTimerState.running;
      _startTicker();
      _startUiTicker();

      // Messaggio UI + tick per farlo “riapparire”.
      _transientMessage = 'Quick Start: 10 min';
      _messageTick += 1;

      HapticFeedback.mediumImpact();
      _notifySafely();
    }
  }

  /// Variante “safe” di notifyListeners:
  /// - se disposed, non notificare
  /// - se siamo in fasi delicate del frame, rimanda a fine frame con post-frame callback
  ///
  /// `addPostFrameCallback` programma una callback a fine frame. 
  void _notifySafely() {
    if (_isDisposed) {
      return;
    }

    final phase = SchedulerBinding.instance.schedulerPhase;

    // Evita notify in mezzo alla pipeline di rendering.
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_isDisposed) {
          return;
        }
        notifyListeners();
      });
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    /// In dispose è importante cancellare Timer e StreamSubscription
    /// per evitare eventi dopo la distruzione dell’oggetto. 
    _isDisposed = true;
    _ticker?.cancel();
    _uiTicker?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }
}
