import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/support_ticket.dart';
import '../services/auth_service.dart';
import '../services/device_profile_service.dart';
import '../services/support_api.dart';
import '../services/support_seen_store.dart';
import '../theme/dyk_theme.dart';
import '../utils/time_ago.dart';
import '../widgets/passim_background.dart';
import 'support_thread_screen.dart';

/// Help & Support: the device's conversations (tap to open a thread) and the
/// form to start a new one. Works for guests — everything is keyed by the
/// device's install id, and the reply shows up here, not by email.
class SupportScreen extends StatefulWidget {
  final AuthService authService;
  final SupportApi? api;
  final Future<String> Function()? installId;
  final Future<SupportSeenStore> Function()? seenStore;

  const SupportScreen({
    super.key,
    required this.authService,
    this.api,
    this.installId,
    this.seenStore,
  });

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final SupportApi _api = widget.api ?? SupabaseSupportApi();
  late final Future<String> Function() _installId =
      widget.installId ?? DeviceProfileService().installId;
  late final Future<SupportSeenStore> Function() _seenStore =
      widget.seenStore ?? SupportSeenStore.load;

  late final TextEditingController _email;
  final _message = TextEditingController();
  List<SupportTicketSummary> _tickets = [];
  SupportSeenStore? _store;
  bool _loadingList = true;
  String? _listError;
  bool _sending = false;
  bool _justSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.authService.currentUser?.email ?? '');
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadingList = true;
      _listError = null;
    });
    try {
      _store ??= await _seenStore();
      final list = await _api.listTickets(await _installId());
      if (!mounted) return;
      setState(() {
        _tickets = list;
        _loadingList = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _listError = tr('couldnt_load_conversations');
      });
    }
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
      await _api.createTicket(
        email: email,
        message: message,
        userId: widget.authService.currentUser?.id,
        installId: await _installId(),
      );
      if (!mounted) return;
      _message.clear();
      setState(() => _justSent = true);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = tr('support_err_send'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _open(SupportTicketSummary t) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SupportThreadScreen(
        ticketId: t.id,
        api: _api,
        installId: _installId,
        seenStore: _store!,
      ),
    ));
    if (mounted) _load();
  }

  String _statusLabel(String s) => s == 'answered'
      ? tr('status_answered')
      : s == 'closed'
          ? tr('status_closed')
          : tr('status_open');

  Widget _ticketCard(SupportTicketSummary t) {
    final unread = _store?.isUnseen(t) ?? false;
    final prefix = t.lastFromCustomer ? tr('you') : tr('passim_support');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _open(t),
        title: Row(
          children: [
            Chip(label: Text(_statusLabel(t.status)), visualDensity: VisualDensity.compact),
            const Spacer(),
            Text(timeAgo(t.lastAt), style: const TextStyle(fontSize: 11)),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(
                key: Key('unread_${t.id}'),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: DykColors.yellow, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('$prefix: ${t.lastBody}', maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('help_support'), style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(passimArtwork(context)),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Container(
          decoration: passimScrim(context),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_loadingList)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_listError != null) ...[
                Text(_listError!),
                TextButton(onPressed: _load, child: Text(tr('retry'))),
                const SizedBox(height: 12),
              ] else if (_tickets.isNotEmpty) ...[
                Text(tr('your_conversations'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 10),
                ..._tickets.map(_ticketCard),
                const SizedBox(height: 18),
                Text(tr('new_message'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 10),
              ],
              if (_justSent) ...[
                Text(tr('message_sent_sub'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
              ] else
                Text(tr('support_intro'), style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 18),
              TextField(
                key: const Key('support_email_field'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(labelText: tr('your_email'), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('support_message_field'),
                controller: _message,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: tr('whats_going_on'),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  key: const Key('support_send_message'),
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
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
