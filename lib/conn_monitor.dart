import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';

/// Memantau backend Termux. Satu server saja — tidak ada pengaturan alamat.
/// Kalau server putus, [online] jadi false dan tetap false sampai server
/// terdeteksi hidup lagi, dari layar mana pun.
class ConnMonitor {
  ConnMonitor._();
  static final ConnMonitor instance = ConnMonitor._();

  final ValueNotifier<bool> online = ValueNotifier<bool>(true);
  Timer? _timer;
  bool _checking = false;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _check();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      await Api.instance.ping();
      online.value = true;
    } catch (_) {
      online.value = false;
    }
    _checking = false;
  }

  /// Minta pengecekan segera (dipanggil setelah aksi gagal karena koneksi).
  void pokeNow() => _check();
}
