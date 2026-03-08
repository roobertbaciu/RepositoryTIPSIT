import 'package:flutter/material.dart';

class GestureHelpSheet extends StatelessWidget {
  const GestureHelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            Text('Guida Gesti', style: textTheme.titleLarge),
            const SizedBox(height: 14),
            _row(
              context,
              Icons.swipe_up_alt,
              'Swipe su',
              'Avvia / Pausa / Riprendi',
            ),
            _row(context, Icons.swipe_down_alt, 'Swipe giu', 'Ferma sessione'),
            _row(context, Icons.touch_app, 'Doppio tap', 'Reset al tempo selezionato'),
            _row(
              context,
              Icons.pan_tool_alt_outlined,
              'Pressione lunga',
              'Scegli o crea label',
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String action, String desc) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(action),
      subtitle: Text(desc),
    );
  }
}
