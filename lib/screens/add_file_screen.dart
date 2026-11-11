import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Generator file dummy langsung ke Download/DokumenScript, lewat server.
/// Onboarding (welcome, privasi, izin akses) sudah ditangani saat aplikasi
/// pertama kali dibuka — layar ini langsung menampilkan daftar file.
class AddFileScreen extends StatelessWidget {
  const AddFileScreen({super.key});

  @override
  Widget build(BuildContext context) => const _FileManagerView();
}

// ===================== Daftar file =====================

class _FileManagerView extends StatefulWidget {
  const _FileManagerView();

  @override
  State<_FileManagerView> createState() => _FileManagerViewState();
}

class _FileManagerViewState extends State<_FileManagerView> {
  List<FileEntry> _files = [];
  String? _folder;
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final d = await Api.instance.filesList();
      if (!mounted) return;
      setState(() {
        _files = d.files;
        _folder = d.folder;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = e.message;
      });
    }
  }

  Future<void> _openAddSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddFileSheet(),
    );
    if (result == true) _load();
  }

  Future<void> _delete(FileEntry f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus file?', style: TextStyle(color: C.text)),
        content: Text(f.name, style: const TextStyle(color: C.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: C.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus', style: TextStyle(color: C.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.instance.deleteFile(f.name);
      _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: clownAppBar(context, title: 'Add File'),
      floatingActionButton: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(kRadius), boxShadow: glow(opacity: 0.4, blur: 26)),
        child: FloatingActionButton(
          onPressed: _openAddSheet,
          backgroundColor: C.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: C.red,
          backgroundColor: C.surface,
          onRefresh: _load,
          child: _body(),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: C.red));
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            borderColor: C.warn.withValues(alpha: 0.5),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: C.warn),
                const SizedBox(width: 12),
                Expanded(child: Text(_error!, style: const TextStyle(color: C.text, height: 1.35))),
              ],
            ),
          ),
        ],
      );
    }
    if (_files.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
        children: const [
          Center(
            child: Icon(Icons.folder_off_rounded, color: C.muted, size: 48),
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              'Belum ada file. Ketuk + untuk membuat.',
              style: TextStyle(color: C.muted),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _files.length + (_folder != null ? 1 : 0),
      itemBuilder: (context, i) {
        if (_folder != null && i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _folder!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: C.muted, fontSize: 12),
            ),
          );
        }
        final f = _files[i - (_folder != null ? 1 : 0)];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                const IconBadge(icon: Icons.insert_drive_file_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: C.text, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(formatBytes(f.size), style: const TextStyle(color: C.muted, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _delete(f),
                  icon: const Icon(Icons.delete_outline_rounded, color: C.muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===================== Sheet tambah file =====================

class _AddFileSheet extends StatefulWidget {
  const _AddFileSheet();

  @override
  State<_AddFileSheet> createState() => _AddFileSheetState();
}

class _AddFileSheetState extends State<_AddFileSheet> {
  final _name = TextEditingController();
  final _size = TextEditingController();
  String _unit = 'MB';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _size.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final value = double.tryParse(_size.text.trim().replaceAll(',', '.'));
    if (name.isEmpty) {
      setState(() => _error = 'Nama file wajib diisi.');
      return;
    }
    if (value == null || value <= 0) {
      setState(() => _error = 'Ukuran file tidak valid.');
      return;
    }
    final multiplier = _unit == 'GB' ? 1024 * 1024 * 1024 : 1024 * 1024;
    final bytes = (value * multiplier).round();

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Api.instance.addFile(name: name, bytes: bytes);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: C.border, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'File Baru',
              style: TextStyle(color: C.text, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              enabled: !_saving,
              style: const TextStyle(color: C.text),
              decoration: const InputDecoration(
                labelText: 'Nama file',
                hintText: 'contoh: laporan.pdf',
                prefixIcon: Icon(Icons.edit_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _size,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    style: const TextStyle(color: C.text),
                    decoration: const InputDecoration(
                      labelText: 'Ukuran',
                      hintText: '0',
                      prefixIcon: Icon(Icons.straighten_rounded),
                    ),
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
                        DropdownMenuItem(value: 'MB', child: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('MB'))),
                        DropdownMenuItem(value: 'GB', child: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('GB'))),
                      ],
                      onChanged: _saving ? null : (v) => setState(() => _unit = v ?? 'MB'),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: C.danger, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'ADD NEW FILE',
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
