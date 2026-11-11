import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'sender_screen.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final TextEditingController _target = TextEditingController();

  List<SenderInfo> _connected = [];
  String? _selected;
  FilesInfo? _files;
  String? _backendError;
  bool _loading = true;

  String? _targetError;
  bool _starting = false;
  JobInfo? _job;
  Timer? _jobTimer;

  @override
  void initState() {
    super.initState();
    _restoreTarget();
    _refresh();
  }

  @override
  void dispose() {
    _jobTimer?.cancel();
    _target.dispose();
    super.dispose();
  }

  Future<void> _restoreTarget() async {
    try {
      final p = await SharedPreferences.getInstance();
      final last = p.getString('last_target');
      if (last != null && _target.text.isEmpty && mounted) {
        _target.text = last;
      }
    } catch (_) {}
  }

  Future<void> _refresh() async {
    try {
      final all = await Api.instance.senders();
      final files = await Api.instance.files();
      if (!mounted) return;
      final connected = all.where((s) => s.connected).toList();
      setState(() {
        _connected = connected;
        if (_selected == null || !connected.any((s) => s.number == _selected)) {
          _selected = connected.isNotEmpty ? connected.first.number : null;
        }
        _files = files;
        _backendError = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _backendError = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _openAddSender() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SenderScreen()));
    _refresh();
  }

  Future<void> _askAddSender() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: kBorder,
          side: const BorderSide(color: C.border, width: 1.2),
        ),
        title: const Text('Belum ada Sender', style: TextStyle(color: C.text)),
        content: const Text(
          'Tambahkan Sender dulu supaya file bisa dikirim. Nomor target kamu tetap tersimpan.',
          style: TextStyle(color: C.muted, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Nanti', style: TextStyle(color: C.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Add Sender', style: TextStyle(color: C.red)),
          ),
        ],
      ),
    );
    if (go == true) _openAddSender();
  }

  Future<void> _send() async {
    final t = normalizeNumber(_target.text);
    if (t == null) {
      setState(() => _targetError = 'Nomor target tidak valid. Pakai format 08xx atau 62xx.');
      return;
    }
    setState(() => _targetError = null);
    FocusScope.of(context).unfocus();

    // Data sender terbaru dulu
    await _refresh();
    if (!mounted) return;
    if (_backendError != null) {
      showToast(context, _backendError!);
      return;
    }
    if (_connected.isEmpty || _selected == null) {
      _askAddSender();
      return;
    }

    setState(() {
      _starting = true;
      _job = null;
    });
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('last_target', _target.text.trim());
    } catch (_) {}

    try {
      final id = await Api.instance.send(sender: _selected!, target: t);
      if (!mounted) return;
      setState(() => _starting = false);
      await _pollJob(id);
      _jobTimer?.cancel();
      _jobTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollJob(id));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      if (e.code == 'no_sender') {
        _askAddSender();
      } else {
        showToast(context, e.message);
      }
    }
  }

  Future<void> _pollJob(String id) async {
    try {
      final j = await Api.instance.job(id);
      if (!mounted) return;
      setState(() => _job = j);
      if (!j.running) _jobTimer?.cancel();
    } on ApiException {
      // koneksi sesaat putus, coba lagi di tick berikutnya
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = _job?.running ?? false;

    return Scaffold(
      appBar: clownAppBar(context, title: 'Send File'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            const Text(
              'Sender',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.text),
            ),
            const SizedBox(height: 10),
            _senderPicker(),
            const SizedBox(height: 22),
            const Text(
              'Target',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.text),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _target,
              enabled: !running,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
              style: const TextStyle(color: C.text, fontSize: 16),
              onChanged: (_) {
                if (_targetError != null) setState(() => _targetError = null);
              },
              decoration: InputDecoration(
                labelText: 'Nomor target',
                hintText: '08xxxxxxxxxx atau 62xxxxxxxxxx',
                prefixIcon: const Icon(Icons.person_rounded),
                errorText: _targetError,
              ),
            ),
            const SizedBox(height: 14),
            _filesCard(),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Kirim File',
              icon: Icons.send_rounded,
              loading: _starting,
              onPressed: running ? null : _send,
            ),
            if (_job != null) ...[
              const SizedBox(height: 18),
              _jobCard(_job!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _senderPicker() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: C.red)),
      );
    }
    if (_backendError != null) {
      return AppCard(
        borderColor: C.warn.withValues(alpha: 0.5),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: C.warn),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_backendError!, style: const TextStyle(color: C.text, height: 1.35)),
            ),
            IconButton(
              tooltip: 'Coba lagi',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, color: C.muted),
            ),
          ],
        ),
      );
    }
    if (_connected.isEmpty) {
      return AppCard(
        borderColor: C.warn.withValues(alpha: 0.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: C.warn),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Belum ada Sender yang terhubung.',
                    style: TextStyle(color: C.text, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GhostButton(label: 'Add Sender', icon: Icons.person_add_alt_1_rounded, onPressed: _openAddSender),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final s in _connected) ...[
          _SenderChoice(
            number: s.number,
            selected: s.number == _selected,
            onTap: () => setState(() => _selected = s.number),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _filesCard() {
    final f = _files;
    if (f == null) return const SizedBox.shrink();
    final ok = f.exists && f.count > 0;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: Icons.folder_open_rounded, color: ok ? C.text : C.warn),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !f.exists
                      ? 'Folder DokumenScript tidak ditemukan'
                      : f.count == 0
                          ? 'Folder DokumenScript kosong'
                          : '${f.count} file siap dikirim',
                  style: const TextStyle(
                    color: C.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  f.folder ?? '-',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: C.muted, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobCard(JobInfo j) {
    final total = j.total <= 0 ? 1 : j.total;
    final progress = (j.processed / total).clamp(0.0, 1.0).toDouble();

    String title;
    IconData icon;
    Color color;
    if (j.running) {
      title = 'Mengirim file';
      icon = Icons.upload_rounded;
      color = C.text;
    } else if (j.status == 'done') {
      title = 'Selesai';
      icon = Icons.check_circle_rounded;
      color = C.ok;
    } else {
      title = 'Pengiriman berhenti';
      icon = Icons.error_outline_rounded;
      color = const Color(0xFFE5484D);
    }

    return AppCard(
      borderColor: j.running ? C.red.withValues(alpha: 0.7) : C.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: C.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: C.surface2,
              color: j.failed > 0 && !j.running ? C.warn : C.red,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Terkirim ${j.done} dari ${j.total}${j.failed > 0 ? ', gagal ${j.failed}' : ''}',
            style: const TextStyle(color: C.text, fontWeight: FontWeight.w600),
          ),
          if (j.running && j.current.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              j.current,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: C.muted, fontSize: 13),
            ),
          ],
          if (j.error != null) ...[
            const SizedBox(height: 8),
            Text(j.error!, style: const TextStyle(color: Color(0xFFE5484D), height: 1.35)),
          ],
          if (j.log.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final line in j.log)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: C.muted, fontSize: 12, height: 1.3),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SenderChoice extends StatelessWidget {
  final String number;
  final bool selected;
  final VoidCallback onTap;

  const _SenderChoice({
    required this.number,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      borderColor: selected ? C.red : C.border,
      tint: selected ? C.redDeep : null,
      glowing: selected,
      glowing: selected,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          IconBadge(icon: Icons.phone_android_rounded, size: 40, color: selected ? Colors.white : C.text),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              number,
              style: const TextStyle(color: C.text, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: selected ? C.red : C.muted,
          ),
        ],
      ),
    );
  }
}
