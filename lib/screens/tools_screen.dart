import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Kumpulan tools kecil yang bisa langsung dipakai.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: clownAppBar(context, title: 'Tools'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            _ToolTile(
              icon: Icons.fact_check_rounded,
              title: 'Cek Nomor WhatsApp',
              subtitle: 'Periksa apakah nomor terdaftar di WhatsApp',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _CheckNumberTool()),
              ),
            ),
            const SizedBox(height: 10),
            _ToolTile(
              icon: Icons.phone_iphone_rounded,
              title: 'Format Nomor',
              subtitle: 'Ubah nomor ke format 62xx secara instan',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _FormatNumberTool()),
              ),
            ),
            const SizedBox(height: 10),
            _ToolTile(
              icon: Icons.straighten_rounded,
              title: 'Konversi Ukuran File',
              subtitle: 'KB, MB, dan GB dalam satu tempat',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _SizeConverterTool()),
              ),
            ),
            const SizedBox(height: 10),
            _ToolTile(
              icon: Icons.dns_rounded,
              title: 'Info Server',
              subtitle: 'Status, versi, dan jumlah Sender aktif',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _ServerInfoTool()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          IconBadge(icon: icon, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: C.text, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: C.muted, fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.muted),
        ],
      ),
    );
  }
}

// ===================== Cek Nomor WhatsApp =====================

class _CheckNumberTool extends StatefulWidget {
  const _CheckNumberTool();

  @override
  State<_CheckNumberTool> createState() => _CheckNumberToolState();
}

class _CheckNumberToolState extends State<_CheckNumberTool> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool? _exists;
  String? _error;

  Future<void> _check() async {
    final n = normalizeNumber(_ctrl.text);
    if (n == null) {
      setState(() {
        _error = 'Nomor tidak valid.';
        _exists = null;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _exists = null;
    });
    try {
      final ok = await Api.instance.checkNumber(n);
      if (mounted) setState(() => _exists = ok);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: clownAppBar(context, title: 'Cek Nomor WhatsApp'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
              style: const TextStyle(color: C.text, fontSize: 16),
              decoration: const InputDecoration(
                labelText: 'Nomor WhatsApp',
                hintText: '08xxxxxxxxxx atau 62xxxxxxxxxx',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Cek Nomor', icon: Icons.fact_check_rounded, loading: _loading, onPressed: _check),
            const SizedBox(height: 16),
            if (_error != null)
              AppCard(
                borderColor: C.warn.withValues(alpha: 0.5),
                child: Text(_error!, style: const TextStyle(color: C.text, height: 1.35)),
              ),
            if (_exists != null)
              AppCard(
                borderColor: (_exists! ? C.ok : C.danger).withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Icon(_exists! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: _exists! ? C.ok : C.danger),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _exists! ? 'Nomor terdaftar di WhatsApp.' : 'Nomor tidak terdaftar di WhatsApp.',
                        style: const TextStyle(color: C.text, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===================== Format Nomor =====================

class _FormatNumberTool extends StatefulWidget {
  const _FormatNumberTool();

  @override
  State<_FormatNumberTool> createState() => _FormatNumberToolState();
}

class _FormatNumberToolState extends State<_FormatNumberTool> {
  final _ctrl = TextEditingController();
  String _result = '-';

  void _update(String v) {
    final n = normalizeNumber(v);
    setState(() => _result = n ?? '-');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: clownAppBar(context, title: 'Format Nomor'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            TextField(
              controller: _ctrl,
              onChanged: _update,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
              style: const TextStyle(color: C.text, fontSize: 16),
              decoration: const InputDecoration(
                labelText: 'Nomor apa saja',
                hintText: '08xx, 62xx, atau +62xx',
                prefixIcon: Icon(Icons.edit_rounded),
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              glowing: _result != '-',
              child: Row(
                children: [
                  const IconBadge(icon: Icons.phone_android_rounded),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Format 62xx', style: TextStyle(color: C.muted, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          _result,
                          style: const TextStyle(color: C.text, fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== Konversi Ukuran File =====================

class _SizeConverterTool extends StatefulWidget {
  const _SizeConverterTool();

  @override
  State<_SizeConverterTool> createState() => _SizeConverterToolState();
}

class _SizeConverterToolState extends State<_SizeConverterTool> {
  final _ctrl = TextEditingController();
  String _unit = 'MB';
  double _bytes = 0;

  void _update(String v) {
    final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
    final mult = {'KB': 1024.0, 'MB': 1024.0 * 1024, 'GB': 1024.0 * 1024 * 1024}[_unit]!;
    setState(() => _bytes = n * mult);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: clownAppBar(context, title: 'Konversi Ukuran'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    onChanged: _update,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    style: const TextStyle(color: C.text, fontSize: 16),
                    decoration: const InputDecoration(labelText: 'Jumlah', hintText: '0'),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: C.surface2,
                    borderRadius: kBorder,
                    border: Border.all(color: C.border, width: 1.2),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _unit,
                      dropdownColor: C.surface2,
                      borderRadius: kBorder,
                      style: const TextStyle(color: C.text, fontWeight: FontWeight.w700),
                      items: const [
                        DropdownMenuItem(value: 'KB', child: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('KB'))),
                        DropdownMenuItem(value: 'MB', child: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('MB'))),
                        DropdownMenuItem(value: 'GB', child: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('GB'))),
                      ],
                      onChanged: (v) {
                        setState(() => _unit = v ?? 'MB');
                        _update(_ctrl.text);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppCard(
              glowing: _bytes > 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hasil', style: TextStyle(color: C.muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('${_bytes.toStringAsFixed(0)} B', style: const TextStyle(color: C.text, fontSize: 15)),
                  Text(formatBytes(_bytes.round()),
                      style: const TextStyle(color: C.text, fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== Info Server =====================

class _ServerInfoTool extends StatefulWidget {
  const _ServerInfoTool();

  @override
  State<_ServerInfoTool> createState() => _ServerInfoToolState();
}

class _ServerInfoToolState extends State<_ServerInfoTool> {
  bool _loading = true;
  String? _error;
  int _senderCount = 0;
  int _connectedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await Api.instance.senders();
      if (!mounted) return;
      setState(() {
        _senderCount = list.length;
        _connectedCount = list.where((s) => s.connected).length;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: clownAppBar(context, title: 'Info Server', actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: C.red))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  if (_error != null)
                    AppCard(
                      borderColor: C.warn.withValues(alpha: 0.5),
                      child: Text(_error!, style: const TextStyle(color: C.text, height: 1.35)),
                    )
                  else ...[
                    AppCard(
                      glowing: true,
                      child: Row(
                        children: [
                          const IconBadge(icon: Icons.cloud_done_rounded, color: C.ok),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text('Server aktif', style: TextStyle(color: C.text, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppCard(
                      child: Row(
                        children: [
                          const IconBadge(icon: Icons.group_rounded),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              '$_connectedCount dari $_senderCount Sender terhubung',
                              style: const TextStyle(color: C.text, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
