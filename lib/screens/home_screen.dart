import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../conn_monitor.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/common.dart';
import 'add_file_screen.dart';
import 'history_screen.dart';
import 'send_screen.dart';
import 'sender_screen.dart';
import 'tools_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _batSub;
  Timer? _pollTimer;
  Timer? _clockTimer;

  int? _level;
  BatteryState? _batState;
  DateTime _now = DateTime.now();
  int _senderCount = 0;
  int _connectedCount = 0;
  int _fileCount = 0;

  @override
  void initState() {
    super.initState();
    _initBattery();
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    _batSub?.cancel();
    super.dispose();
  }

  Future<void> _initBattery() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      if (mounted) {
        setState(() {
          _level = level;
          _batState = state;
        });
      }
      _batSub = _battery.onBatteryStateChanged.listen((st) async {
        try {
          final lv = await _battery.batteryLevel;
          if (mounted) {
            setState(() {
              _level = lv;
              _batState = st;
            });
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  Future<void> _poll() async {
    try {
      final list = await Api.instance.senders();
      if (!mounted) return;
      setState(() {
        _senderCount = list.length;
        _connectedCount = list.where((s) => s.connected).length;
      });
    } catch (_) {
      // status server ditangani oleh overlay global
    }
    try {
      final f = await Api.instance.files();
      if (!mounted) return;
      setState(() => _fileCount = f.count);
    } catch (_) {}
  }

  IconData get _batteryIcon {
    if (_batState == BatteryState.charging) return Icons.battery_charging_full_rounded;
    final l = _level ?? 100;
    if (l <= 15) return Icons.battery_alert_rounded;
    return Icons.battery_full_rounded;
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _poll();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final batteryText = _level == null ? '-%' : '$_level%';
    final time = '${_two(_now.hour)}:${_two(_now.minute)}';

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      extendBodyBehindAppBar: true,
      appBar: clownAppBar(context),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              SizedBox(height: kToolbarHeight),
              // Banner: tidak nempel atas, rasio asli, sudut 15px, bercahaya.
              Container(
                decoration: BoxDecoration(
                  borderRadius: kBorder,
                  border: Border.all(color: C.border, width: 1.2),
                  boxShadow: glow(opacity: 0.22, blur: 34),
                ),
                child: ClipRRect(
                  borderRadius: kBorder,
                  child: Image.asset('assets/banner.jpg', width: double.infinity, fit: BoxFit.fitWidth),
                ),
              ),
              const SizedBox(height: 16),

              // Info perangkat: satu baris saja.
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(_batteryIcon, size: 18, color: (_level ?? 100) <= 15 ? C.warn : C.text),
                    const SizedBox(width: 6),
                    Text(batteryText, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 13)),
                    _dot(),
                    const Icon(Icons.schedule_rounded, size: 18, color: C.text),
                    const SizedBox(width: 6),
                    Text(time, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 13)),
                    _dot(),
                    ValueListenableBuilder<bool>(
                      valueListenable: ConnMonitor.instance.online,
                      builder: (context, online, _) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                              size: 18, color: online ? C.ok : C.warn),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              online ? 'Aktif' : 'Mati',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: online ? C.ok : C.warn, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _dot(),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.group_rounded, size: 18, color: C.text),
                          const SizedBox(width: 6),
                          Text('$_connectedCount/$_senderCount',
                              style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text('Menu Cepat', style: TextStyle(color: C.text, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.92,
                children: [
                  _QuickAction(icon: Icons.person_add_alt_1_rounded, label: 'Sender', onTap: () => _open(const SenderScreen())),
                  _QuickAction(icon: Icons.send_rounded, label: 'Kirim', onTap: () => _open(const SendScreen())),
                  _QuickAction(icon: Icons.create_new_folder_rounded, label: 'Add File', onTap: () => _open(const AddFileScreen())),
                  _QuickAction(icon: Icons.build_circle_rounded, label: 'Tools', onTap: () => _open(const ToolsScreen())),
                  _QuickAction(icon: Icons.history_rounded, label: 'Riwayat', onTap: () => _open(const HistoryScreen())),
                  _QuickAction(icon: Icons.menu_rounded, label: 'Menu', onTap: () => _scaffoldKey.currentState?.openDrawer()),
                ],
              ),
              const SizedBox(height: 20),

              const Text('Ringkasan', style: TextStyle(color: C.text, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(icon: Icons.group_rounded, label: 'Sender aktif', value: '$_connectedCount'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(icon: Icons.folder_rounded, label: 'File siap kirim', value: '$_fileCount'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 9),
        child: Text('•', style: TextStyle(color: C.border, fontSize: 14)),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconBadge(icon: icon, size: 44),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: C.text, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      glowing: true,
      child: Row(
        children: [
          IconBadge(icon: icon, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 11.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: C.text, fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
