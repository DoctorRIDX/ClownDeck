import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Riwayat pengiriman file — diambil dari server, 20 terakhir.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<JobSummary> _jobs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await Api.instance.jobHistory();
      if (!mounted) return;
      setState(() {
        _jobs = list;
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

  String _timeLabel(int ms) {
    if (ms == 0) return '-';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: clownAppBar(context, title: 'Riwayat', actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: C.red))
            : RefreshIndicator(
                color: C.red,
                backgroundColor: C.surface,
                onRefresh: _load,
                child: _body(),
              ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            borderColor: C.warn.withValues(alpha: 0.5),
            child: Text(_error!, style: const TextStyle(color: C.text, height: 1.35)),
          ),
        ],
      );
    }
    if (_jobs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
        children: const [
          Center(child: Icon(Icons.history_rounded, color: C.muted, size: 48)),
          SizedBox(height: 16),
          Center(child: Text('Belum ada riwayat pengiriman.', style: TextStyle(color: C.muted))),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: _jobs.length,
      itemBuilder: (context, i) {
        final j = _jobs[i];
        final ok = j.status == 'done' && j.failed == 0;
        final color = j.status == 'running' ? C.warn : (ok ? C.ok : C.danger);
        final icon = j.status == 'running'
            ? Icons.sync_rounded
            : (ok ? Icons.check_circle_rounded : Icons.error_rounded);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(
              children: [
                IconBadge(icon: icon, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ke ${j.target}', style: const TextStyle(color: C.text, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '${j.done}/${j.total} terkirim${j.failed > 0 ? ', ${j.failed} gagal' : ''} · ${_timeLabel(j.startedAt)}',
                        style: const TextStyle(color: C.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
