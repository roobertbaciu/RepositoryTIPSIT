import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const ColorSequenceApp());

class ColorSequenceApp extends StatelessWidget {
  const ColorSequenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Color Sequence Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const ColorSequenceScreen(),
    );
  }
}

class ColorSequenceScreen extends StatefulWidget {
  const ColorSequenceScreen({super.key});

  @override
  State<ColorSequenceScreen> createState() => _ColorSequenceScreenState();
}

class _ColorSequenceScreenState extends State<ColorSequenceScreen> {
  static const int _greyIndex = -1;

  final List<Color> _colors = [
    Colors.pinkAccent,
    Colors.teal,
    Colors.amber,
    Colors.lightBlue,
    Colors.deepPurpleAccent,
  ];

  final List<String> _colorLabels = [
    'Rosa',
    'Verde Acqua',
    'Giallo',
    'Azzurro',
    'Viola',
  ];

  late List<int> _targetSequence;
  List<int> _userSequence = List.filled(4, _greyIndex);
  List<bool> _checked = List.filled(4, false);

  bool _canVerify = true;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _generateNewSequence();
  }

  /// Genera una nuova sequenza casuale da indovinare
  void _generateNewSequence() {
    final rnd = Random();

    setState(() {
      _targetSequence = List.generate(4, (_) => rnd.nextInt(_colors.length));
      _userSequence = List.filled(4, _greyIndex);
      _checked = List.filled(4, false);
      _canVerify = true;
      _won = false;
    });
  }

  /// Cambia il colore selezionato dall’utente in un determinato punto
  void _changeUserColor(int index) {
    setState(() {
      if (_userSequence[index] == _greyIndex) {
        _userSequence[index] = 0;
      } else {
        _userSequence[index] =
            (_userSequence[index] + 1) % _colors.length;
      }

      _checked = List.filled(4, false);
      _canVerify = true;
      _won = false;
    });
  }

  /// Verifica se la sequenza utente è corretta
  void _verifySequence() {
    setState(() {
      _checked = List.filled(4, true);
      _canVerify = false;

      _won = true;
      for (int i = 0; i < 4; i++) {
        if (_userSequence[i] != _targetSequence[i]) {
          _won = false;
          break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade200, Colors.deepPurple.shade200],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Titolo principale
                const Text(
                  '🌀 Color Sequence',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Indovina la sequenza corretta!',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const SizedBox(height: 80),

                // Pulsanti dei colori
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final currentColor = _userSequence[index] == _greyIndex
                        ? Colors.grey.shade400
                        : _colors[_userSequence[index]];

                    final Widget icon = _checked[index]
                        ? Icon(
                            _userSequence[index] == _targetSequence[index]
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: _userSequence[index] == _targetSequence[index]
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            size: 28,
                          )
                        : const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => _changeUserColor(index),
                            borderRadius: BorderRadius.circular(50),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 75,
                              height: 75,
                              decoration: BoxDecoration(
                                color: currentColor,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          icon,
                        ],
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 50),

                // Messaggio di vittoria
                AnimatedOpacity(
                  opacity: _won ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: const Text(
                    '🎉 Hai vinto! 🎉',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 6,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Pulsanti di controllo (verifica / nuova sequenza)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _canVerify ? _verifySequence : null,
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        'Verifica',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
                      ),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton.icon(
                      onPressed: _generateNewSequence,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: const Text(
                        'Nuova',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade400,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
