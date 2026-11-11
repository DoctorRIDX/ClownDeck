import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum _Phase { idle, loading, code, connecting, connected, expired, error }

class SenderScreen extends StatefulWidget {
  const SenderScreen({super.key});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen> {
  final TextEditingController _ctrl = TextEditingController();

  _Phase _phase = _Phase.idle;
  String? _error;
  String? _number; // nomor yang sedang dipairing (62xx)
  bool _wasKnown = false; // nomor sudah terdaftar sebelum pairing dimulai
  String? _code;
  int _expiresAt = 0;
  int _ttlMs = 60000;
  int _remaining = 0;

  Timer? _pollTimer;
  Timer? _tickTimer;

  List<SenderInfo> _senders = [];
  bool _listLoading = true;
  String? _listError;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  @override
  void dispose() {
    _stopTimers();
    _ctrl.dispose();
    super.dispose();
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    _pollTimer = null;
    _tickTimer = null;
  }

  Future<void> _loadList() async {
    try {
      final list = await Api.instance.senders();
      if (!mounted) return;
      setState(() {
        _senders = list;
        _listLoading = false;
        _listError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _listLoading = false;
        _listError = e.message;
      });
    }
  }

  int _remainingSeconds() {
    final ms = _expiresAt - DateTime.now().millisecondsSinceEpoch;
    if (ms <= 0) return 0;
    return (ms / 1000).ceil();
  }

  void _startTick() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final r = _remainingSeconds();
      setState(() {
        _remaining = r;
        if (r <= 0 && _phase == _Phase.code) {
          _phase = _Phase.expired;
        }
      });
    });
  }

  Future<void> _startPairing() async {
    final n = normalizeNumber(_ctrl.text);
    if (n == null) {
      setState(() => _error = 'Nomor tidak valid. Pakai format 08xx atau 62xx.');
      return;
    }
    FocusScope.of(context).unfocus();
    _stopTimers();
    final known = _senders.any((x) => x.number == n);
    setState(() {
      _phase = _Phase.loading;
      _error = null;
      _code = null;
      _number = n;
      _wasKnown = known;
    });
    try {
      final s = await Api.instance.addSender(n);
      if (!mounted) return;
      _applySender(s);
      if (_phase != _Phase.connected && _phase != _Phase.error) {
        _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollSender());
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.message;
      });
    }
  }

  Future<void> _pollSender() async {
    final n = _number;
    if (n == null) return;
    try {
      final s = await Api.instance.sender(n);
      if (!mounted) return;
      _applySender(s);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.offline) {
        _stopTimers();
        setState(() {
          _phase = _Phase.error;
          _error = e.message;
        });
      }
    }
  }

  void _applySender(SenderInfo s) {
    switch (s.status) {
      case 'connected':
        _stopTimers();
        setState(() {
          _phase = _Phase.connected;
          _code = null;
        });
        _loadList();
        break;
      case 'pairing':
        if (s.code == null) break;
        final exp = s.expiresAt ?? 0;
        setState(() {
          _code = s.code;
          _expiresAt = exp;
          _ttlMs = s.ttlMs;
          _remaining = _remainingSeconds();
          _phase = _remaining > 0 ? _Phase.code : _Phase.expired;
        });
        if (_tickTimer == null) _startTick();
        break;
      case 'error':
      case 'disconnected':
        _stopTimers();
        setState(() {
          _phase = _Phase.error;
          _error = s.error ?? 'Pairing gagal. Coba lagi.';
        });
        break;
      default: // starting, connecting
        setState(() {
          _phase = (_phase == _Phase.code || _phase == _Phase.connecting)
              ? _Phase.connecting
              : _Phase.loading;
        });
    }
  }

  Future<void> _cancelPairing() async {
    final n = _number;
    _stopTimers();
    setState(() {
      _phase = _Phase.idle;
      _code = null;
    });
    if (n != null && !_wasKnown) {
      try {
        await Api.instance.removeSender(n);
      } catch (_) {}
    }
    _loadList();
  }

  Future<void> _copyCode() async {
    final c = _code;
    if (c == null) return;
    await Clipboard.setData(ClipboardData(text: c));
    if (mounted) showToast(context, 'Kode pairing disalin');
  }

  Future<void> _confirmDelete(SenderInfo s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: kBorder,
          side: const BorderSide(color: C.border, width: 1.2),
        ),
        title: const Text('Hapus Sender?', style: TextStyle(color: C.text)),
        content: Text(
          '${s.number} akan dilepas dari WhatsApp dan harus dipairing ulang.',
          style: const TextStyle(color: C.muted, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: C.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus', style: TextStyle(color: C.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.instance.removeSender(s.number);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
    _loadList();
  }

  String _mmss(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _prettyCode(String c) {
    if (c.length == 8) return '${c.substring(0, 4)}-${c.substring(4)}';
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final busy = _phase == _Phase.loading ||
        _phase == _Phase.code ||
        _phase == _Phase.connecting;

    return Scaffold(
      appBar: clownAppBar(
        context,
        title: 'Add Sender',
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loadList,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            const SizedBox(height: 4),
            TextField(
              controller: _ctrl,
              enabled: !busy,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
              style: const TextStyle(color: C.text, fontSize: 16),
              onChanged: (_) {
                if (_error != null && _phase == _Phase.idle) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: 'Nomor Sender',
                hintText: '08xxxxxxxxxx atau 62xxxxxxxxxx',
                prefixIcon: const Icon(Icons.phone_android_rounded),
                errorText: _phase == _Phase.idle ? _error : null,
              ),
            ),
            const SizedBox(height: 12),
            if (!busy)
              PrimaryButton(
                label: _phase == _Phase.expired ? 'Minta kode baru' : 'Pairing',
                icon: Icons.link_rounded,
                onPressed: _startPairing,
              ),
            if (busy && _phase != _Phase.connecting)
              GhostButton(
                label: 'Batalkan',
                icon: Icons.close_rounded,
                onPressed: _cancelPairing,
              ),
            const SizedBox(height: 14),
            _pairPanel(),
            const SizedBox(height: 24),
            const Text(
              'Sender terdaftar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.text),
            ),
            const SizedBox(height: 10),
            _senderList(),
          ],
        ),
      ),
    );
  }

  Widget _pairPanel() {
    switch (_phase) {
      case _Phase.idle:
        return const SizedBox.shrink();

      case _Phase.loading:
        return _StatusCard(
          loading: true,
          title: 'Menyiapkan pairing',
          message: 'Meminta kode dari WhatsApp, tunggu sebentar.',
        );

      case _Phase.connecting:
        return _StatusCard(
          loading: true,
          title: 'Menyambungkan',
          message: 'Kode diterima. Biarkan WhatsApp dan aplikasi ini tetap terbuka.',
        );

      case _Phase.connected:
        return _StatusCard(
          icon: Icons.check_circle_rounded,
          iconColor: C.ok,
          title: 'Sender terhubung',
          message: '${_number ?? ''} siap dipakai untuk mengirim file.',
        );

      case _Phase.error:
        return _StatusCard(
          icon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFE5484D),
          title: 'Pairing gagal',
          message: _error ?? 'Terjadi kesalahan.',
        );

      case _Phase.expired:
        return _StatusCard(
          icon: Icons.timer_off_rounded,
          iconColor: C.warn,
          title: 'Kode kedaluwarsa',
          message: 'Minta kode baru, lalu masukkan segera di WhatsApp.',
        );

      case _Phase.code:
        final progress = _ttlMs <= 0 ? 0.0 : (_remaining * 1000 / _ttlMs).clamp(0.0, 1.0).toDouble();
        return AppCard(
          borderColor: C.red.withValues(alpha: 0.7),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kode pairing', style: TextStyle(color: C.muted, fontSize: 13)),
              const SizedBox(height: 8),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SelectableText(
                    _prettyCode(_code ?? ''),
                    style: const TextStyle(
                      color: C.text,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GhostButton(label: 'Salin kode', icon: Icons.copy_rounded, onPressed: _copyCode),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.timer_rounded, size: 18, color: _remaining <= 10 ? C.warn : C.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kedaluwarsa dalam ${_mmss(_remaining)}',
                      style: TextStyle(
                        color: _remaining <= 10 ? C.warn : C.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: C.surface2,
                  color: _remaining <= 10 ? C.warn : C.red,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'WhatsApp > Perangkat tertaut > Tautkan dengan nomor telepon',
                style: TextStyle(color: C.muted, height: 1.4, fontSize: 13),
              ),
            ],
          ),
        );
    }
  }

  Widget _senderList() {
    if (_listLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: C.red)),
      );
    }
    if (_listError != null) {
      return AppCard(
        borderColor: C.warn.withValues(alpha: 0.5),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: C.warn),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_listError!, style: const TextStyle(color: C.text, height: 1.35)),
            ),
          ],
        ),
      );
    }
    if (_senders.isEmpty) {
      return const AppCard(
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: C.muted),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Belum ada Sender. Tambahkan lewat form di atas.',
                style: TextStyle(color: C.muted, height: 1.35),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final s in _senders) ...[
          _SenderRow(sender: s, onDelete: () => _confirmDelete(s)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool loading;
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String message;

  const _StatusCard({
    this.loading = false,
    this.icon,
    this.iconColor,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: C.red),
            )
          else
            Icon(icon, color: iconColor ?? C.text, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: C.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: C.muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SenderRow extends StatelessWidget {
  final SenderInfo sender;
  final VoidCallback onDelete;

  const _SenderRow({required this.sender, required this.onDelete});

  String get _label {
    switch (sender.status) {
      case 'connected':
        return 'Terhubung';
      case 'pairing':
        return 'Menunggu kode dimasukkan';
      case 'starting':
      case 'connecting':
        return 'Menyambung';
      case 'disconnected':
        return 'Terputus';
      case 'error':
        return sender.error ?? 'Error';
      default:
        return sender.status;
    }
  }

  Color get _color {
    switch (sender.status) {
      case 'connected':
        return C.ok;
      case 'error':
      case 'disconnected':
        return const Color(0xFFE5484D);
      default:
        return C.warn;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          IconBadge(icon: Icons.phone_android_rounded, color: _color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender.number,
                  style: const TextStyle(
                    color: C.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _color, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: C.muted),
          ),
        ],
      ),
    );
  }
}
