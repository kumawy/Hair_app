import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hair_app/shared/widgets/fading_app_bar.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: FadingAppBar(title: const Text('Help')),
    body: ListView(
      padding: FadingAppBar.contentPadding(context, const EdgeInsets.all(20)),
      children: [
        for (final entry in const {
          'How do I scan my face?':
              'Open Face Scanner and take a photo. Keep one face inside the white oval, look straight ahead and use even lighting. A green oval means the framing is ready. You can turn auto capture off.',
          'Why does analysis fail?':
              'This prototype uses a face analysis server. During local testing, start the server on your computer and connect both devices to the same Wi-Fi. You can also choose your face shape manually.',
          'Can I change the suggested face shape?':
              'Yes. Review the estimate and choose another shape before continuing. The result is not a guaranteed measurement.',
          'What does Preview hairstyle do?':
              'Preview hairstyle shows a reference photo of the selected style. It does not edit your selfie.',
          'Where are favorites and history saved?':
              'Favorites and recent results are stored on this device separately for each account and for guests. They do not sync between devices. History contains parameters, not photographs. Your hair profile is saved to your account only when you tap Save to profile.',
          'Why are there few recommendations?':
              'The catalog is small. Personal recommendations require matching face shape and hair texture. Some styles may require growing your hair or cutting it shorter.',
          'How do I reset my password?':
              'On the sign-in screen, tap Forgot password and enter your email. Check your inbox and spam folder.',
        }.entries)
          ExpansionTile(
            title: Text(entry.key),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(entry.value),
              ),
            ],
          ),
        const SizedBox(height: 20),
        const Text(
          'Found a problem? Copy the report template and share it with the person who gave you this demo.',
        ),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              const ClipboardData(
                text:
                    'Hair App issue\nDevice:\nScreen:\nSteps to reproduce:\nExpected result:\nActual result:',
              ),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report template copied')),
              );
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy report template'),
        ),
      ],
    ),
  );
}
