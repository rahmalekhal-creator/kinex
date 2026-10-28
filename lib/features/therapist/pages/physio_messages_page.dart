import 'package:flutter/material.dart';

import 'package:reeducation/DB_API.dart';
import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/l10n/server_messages.dart';
import 'package:reeducation/widgets/kinex_app_bar.dart';
import 'package:reeducation/widgets/kinex_screen_background.dart';

class PhysioMessagesPage extends StatefulWidget {
  final int accountId;
  final int patientAccountId;
  final String patientName;

  /// Text already typed in the box (a suggestion from a notification); sent only if the physiotherapist presses Send.
  final String initialDraft;

  const PhysioMessagesPage({
    super.key,
    required this.accountId,
    required this.patientAccountId,
    required this.patientName,
    this.initialDraft = '',
  });

  @override
  State<PhysioMessagesPage> createState() => _PhysioMessagesPageState();
}

class _PhysioMessagesPageState extends State<PhysioMessagesPage> {
  final SQLdata _db = SQLdata();
  final TextEditingController _messageController = TextEditingController();

  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _messageController.text = widget.initialDraft;
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _db.fetchPhysioMessages(
        accountId: widget.accountId,
        patientAccountId: widget.patientAccountId,
      );
      if (!mounted) return;
      setState(() {
        _messages = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = localizeError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await _db.sendPhysioMessage(
        accountId: widget.accountId,
        patientAccountId: widget.patientAccountId,
        content: text,
      );
      if (!mounted) return;
      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizeError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final composerBg = isDark ? const Color(0xFF111827) : Colors.white;
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB);
    final inputText = Theme.of(context).colorScheme.onSurface;
    final hint = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    return Scaffold(
      appBar: kinexAppBar(
        title: widget.patientName.isNotEmpty ? widget.patientName : context.l10n.patientChat,
      ),
      body: KinexScreenBackground(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMessages,
                child: _buildMessages(),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: composerBg,
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF374151) : const Color(0xFFE6E8EC))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: inputText),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: context.l10n.typeYourMessage,
                        hintStyle: TextStyle(color: hint),
                        prefixIcon: Icon(Icons.chat_bubble_outline_rounded, color: hint),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _isSending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF2E90FA),
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final peerBubble = isDark ? const Color(0xFF1F2937) : const Color(0xFFF0F2F5);
    final peerPrimary = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827);
    final peerSecondary = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF6B7280);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    if (_messages.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(context.l10n.noMessagesYet),
          ),
        ],
      );
    }

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final item = _messages[_messages.length - 1 - index];
        final isMine = item['is_mine'] == true;
        final senderName = _senderLabel((item['sender_name'] ?? '').toString());
        final content = (item['content'] ?? '').toString();
        final sentAt = (item['sent_at'] ?? '').toString();

        return Align(
          alignment: isMine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: isMine ? const Color(0xFF2E90FA) : peerBubble,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (senderName.isNotEmpty)
                  Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                       color: isMine ? Colors.white70 : peerSecondary,
                    ),
                  ),
                if (senderName.isNotEmpty) const SizedBox(height: 3),
                Text(
                  content,
                  style: TextStyle(color: isMine ? Colors.white : peerPrimary),
                ),
                if (sentAt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      sentAt,
                      style: TextStyle(
                        fontSize: 11,
                        color: isMine ? Colors.white70 : peerSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The server labels the user's own messages "Me" and unnamed peers by role.
  String _senderLabel(String raw) {
    switch (raw) {
      case 'Me':
        return context.l10n.me;
      case 'Patient':
        return context.l10n.patient;
      case 'Physiotherapist':
        return context.l10n.physiotherapist;
      default:
        return raw;
    }
  }
}




