import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SimpleStopwatch(),
    );
  }
}

class SimpleStopwatch extends StatefulWidget {
  @override
  State<SimpleStopwatch> createState() => _SimpleStopwatchState();
}

class _SimpleStopwatchState extends State<SimpleStopwatch> {
  int seconds = 0;
  int ticks = 0;

  bool running = false;
  bool paused = false;

  late StreamSubscription tickStream;
  late StreamSubscription secondStream;

  @override
  void initState() {
    super.initState();

    // Stream dei tick (ogni 200ms)
    tickStream =
        Stream.periodic(const Duration(milliseconds: 200)).listen((_) {
      if (running && !paused) {
        setState(() {
          ticks++;
        });
      }
    });

    // Stream dei secondi (ogni 1s)
    secondStream =
        Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (running && !paused) {
        setState(() {
          seconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    tickStream.cancel();
    secondStream.cancel();
    super.dispose();
  }

  void startStopReset() {
    if (!running) {
      // START
      setState(() {
        running = true;
        paused = false;
      });
    } else if (!paused) {
      // STOP
      setState(() {
        running = false;
        seconds = 0;
        ticks = 0;
      });
    } else {
      // RESET quando è in pausa
      setState(() {
        running = false;
        paused = false;
        seconds = 0;
        ticks = 0;
      });
    }
  }

  void pauseResume() {
    if (!running) return;

    setState(() {
      paused = !paused;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cronometro semplice")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}",
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text("Tick: $ticks", style: const TextStyle(fontSize: 24)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: startStopReset,
                  child: Text(!running
                      ? "START"
                      : (!paused ? "STOP" : "RESET")),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: running ? pauseResume : null,
                  child: Text(paused ? "RESUME" : "PAUSE"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
