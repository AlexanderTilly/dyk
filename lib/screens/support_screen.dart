import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../theme/dyk_theme.dart';
import '../i18n/i18n.dart';

/// Help & Support — sends a message straight to the admin panel's
/// Support page. Works for guests too (they type their email).
class SupportScreen extends StatefulWidget {
  final AuthService authService;
  const SupportScreen({super.key, required this.authService});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final TextEditingController _email;
  final _message = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(
        text: widget.authService.currentUser?.email ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    final message = _message.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = tr('support_err_email'));
      return;
    }
    if (message.isEmpty) {
      setState(() => _error = tr('support_err_msg'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.from('support_tickets').insert({
        'email': email,
        'message': message,
        'user_id': widget.authService.currentUser?.id,
      });
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = tr('support_err_send'));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('help_support'),
            style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/landing_background.png'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Container(
          color: dark
              ? Colors.black.withValues(alpha: 0.72)
              : PassimColors.sand.withValues(alpha: 0.85),
          child: _sent
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: DykColors.yellow.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mark_email_read_outlined,
                              size: 44, color: DykColors.yellow),
                        ),
                        const SizedBox(height: 16),
                        Text(tr('message_sent'),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text(
                          tr('message_sent_sub'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(tr('done')),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      tr('support_intro'),
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: tr('your_email'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _message,
                      maxLines: 7,
                      decoration: InputDecoration(
                        labelText: tr('whats_going_on'),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13)),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.send),
                        label: Text(_sending ? tr('sending') : tr('send_message')),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
