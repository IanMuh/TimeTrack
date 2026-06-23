import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../l10n/app_localizations.dart';
import 'ui_components.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({required this.state, super.key});

  final AppState state;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _controller = TextEditingController();
  final _tokenController = TextEditingController();
  bool _sent = false;
  bool _sending = false;
  bool _verifying = false;

  @override
  void dispose() {
    _controller.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuietPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: AppLocalizations.of(context)!.multiDeviceSync,
            subtitle: AppLocalizations.of(context)!.multiDeviceSyncHint,
            icon: Icons.cloud_sync_outlined,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final emailField = TextField(
                controller: _controller,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.emailLabel,
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
              );
              final sendButton = FilledButton.icon(
                onPressed: _sending
                    ? null
                    : () async {
                        setState(() => _sending = true);
                        final messenger = ScaffoldMessenger.of(context);
                        final l10n = AppLocalizations.of(context)!;
                        try {
                          await widget.state.sendMagicLink(_controller.text);
                          if (mounted) {
                            setState(() {
                              _sent = true;
                              _sending = false;
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _sending = false);
                            messenger.showSnackBar(
                              SnackBar(content: Text(l10n.sendFailed(e.toString()))),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.mark_email_read_outlined),
                label: Text(_sending ? AppLocalizations.of(context)!.sending : AppLocalizations.of(context)!.sendCode),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    emailField,
                    const SizedBox(height: 10),
                    sendButton,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: emailField),
                  const SizedBox(width: 10),
                  sendButton,
                ],
              );
            },
          ),
          if (_sent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.emailCode,
                prefixIcon: const Icon(Icons.pin_outlined),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _verifying
                  ? null
                  : () async {
                      setState(() => _verifying = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final l10n = AppLocalizations.of(context)!;
                      try {
                        await widget.state.verifyEmailOtp(
                          email: _controller.text,
                          token: _tokenController.text,
                        );
                        if (mounted) {
                          setState(() => _verifying = false);
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _verifying = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text(l10n.verifyFailed(e.toString()))),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.verified_outlined),
              label: Text(_verifying ? AppLocalizations.of(context)!.verifying : AppLocalizations.of(context)!.verifyLogin),
            ),
          ],
        ],
      ),
    );
  }
}
