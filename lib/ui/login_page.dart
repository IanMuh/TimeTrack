import 'package:flutter/material.dart';

import '../app/app_state.dart';
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
          const SectionTitle(
            title: '多设备同步',
            subtitle: '本地记录始终可用，登录后再同步到云端。',
            icon: Icons.cloud_sync_outlined,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final emailField = TextField(
                controller: _controller,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: '邮箱',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              );
              final sendButton = FilledButton.icon(
                onPressed: _sending
                    ? null
                    : () async {
                        setState(() => _sending = true);
                        await widget.state.sendMagicLink(_controller.text);
                        setState(() {
                          _sent = true;
                          _sending = false;
                        });
                      },
                icon: const Icon(Icons.mark_email_read_outlined),
                label: Text(_sending ? '发送中' : '发送验证码'),
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
              decoration: const InputDecoration(
                labelText: '邮箱验证码',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _verifying
                  ? null
                  : () async {
                      setState(() => _verifying = true);
                      await widget.state.verifyEmailOtp(
                        email: _controller.text,
                        token: _tokenController.text,
                      );
                      if (mounted) {
                        setState(() => _verifying = false);
                      }
                    },
              icon: const Icon(Icons.verified_outlined),
              label: Text(_verifying ? '验证中' : '验证登录'),
            ),
          ],
        ],
      ),
    );
  }
}
