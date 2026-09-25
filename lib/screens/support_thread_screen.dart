import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/support_ticket.dart';
import '../services/support_api.dart';
import '../services/support_seen_store.dart';
import '../theme/dyk_theme.dart';
import '../utils/time_ago.dart';

/// One support conversation. The customer's messages sit on the right as
/// "You"; everything else is "Passim Support" — the app never shows who on
/// the team (or which machine) wrote a reply.
class SupportThreadScreen extends StatefulWidget {
  final String ticketId;
  final SupportApi api;
  final Future<String> Function() installId;
  final SupportSeenStore seenStore;

  const SupportThreadScreen({
    super.key,
    required this.ticketId,
    required this.api,
    required this.installId,
    required this.seenStore,
  });

  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen> {
  static const maxChars = 4000;

  final _reply = TextEditingController();
  final _scroll = ScrollController();
  SupportThread? _thread;
  bool _loading = true;
  bool _sending = false;
  String? _loadError;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _reply.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final t = await widget.api.thread(widget.ticketId, await widget.installId());
      final newestStaff = t.messages.where((m) => !m.fromCustomer).fold<DateTime?>(
          null, (best, m) => best == null || m.createdAt.isAfter(best) ? m.createdAt : best);
      if (newestStaff != null) await widget.seenStore.markSeen(t.id, newestStaff);
      if (!mounted) return;
      setState(() {
        _thread = t;
        _loading = false;
      });
      _jumpToEnd();
    } on SupportNotFound {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('conversation_gone'))));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = tr('couldnt_load_conversations');
      });
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  String get _trimmed => _reply.text.trim();
  bool get _canSend => !_sending && _thread != null && _trimmed.isNotEmpty && _trimmed.length <= maxChars;

  Future<void> _send() async {
    final body = _trimmed;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final id = await widget.api.reply(widget.ticketId, await widget.installId(), body);
      if (!mounted) return;
      setState(() {
        _thread = SupportThread(
          id: _thread!.id,
          status: 'new',
          createdAt: _thread!.createdAt,
          messages: [
            ..._thread!.messages,
            SupportMessage(id: id, fromCustomer: true, body: body, createdAt: DateTime.now().toUtc()),
          ],
        );
        _reply.clear();
      });
      _jumpToEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sendError = tr('support_err_send'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _statusLabel(String s) => s == 'answered'
      ? tr('status_answered')
      : s == 'closed'
          ? tr('status_closed')
          : tr('status_open');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('passim_support'), style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_thread != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(label: Text(_statusLabel(_thread!.status)), visualDensity: VisualDensity.compact),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_loadError!),
                            const SizedBox(height: 8),
                            TextButton(onPressed: _load, child: Text(tr('retry'))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _thread!.messages.length,
                        itemBuilder: (_, i) => _Bubble(message: _thread!.messages[i]),
                      ),
          ),
          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_sendError!, key: const Key('support_reply_error'),
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('support_reply_field'),
                      controller: _reply,
                      minLines: 1,
                      maxLines: 5,
                      enabled: !_sending && _thread != null,
                      decoration: InputDecoration(
                        hintText: tr('reply_placeholder'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('support_send'),
                    tooltip: tr('send_reply'),
                    color: DykColors.yellow,
                    onPressed: _canSend ? _send : null,
                    icon: _sending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }
}

class _Bubble extends StatelessWidget {
  final SupportMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final mine = message.fromCustomer;
    final theme = Theme.of(context);
    final bg = mine ? DykColors.yellow.withValues(alpha: 0.22) : theme.colorScheme.surface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 3),
              bottomRight: Radius.circular(mine ? 3 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mine ? tr('you') : tr('passim_support'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(message.body, style: const TextStyle(fontSize: 15, height: 1.35)),
              const SizedBox(height: 3),
              Text(timeAgo(message.createdAt),
                  style: TextStyle(fontSize: 10, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }
}
