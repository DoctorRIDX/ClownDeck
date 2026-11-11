import 'package:flutter/material.dart';

import '../conn_monitor.dart';
import '../theme.dart';

/// Alert server mati: menutupi separuh layar, kaca cair, tidak bisa
/// ditutup manual — hilang sendiri begitu server terdeteksi menyala lagi.
class ServerDownOverlay extends StatelessWidget {
  const ServerDownOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnMonitor.instance.online,
      builder: (context, online, _) {
        return IgnorePointer(
          ignoring: online,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            opacity: online ? 0 : 1,
            child: Stack(
              children: [
                // Peredup latar belakang, menyerap semua sentuhan selagi server mati.
                ModalBarrier(
                  dismissible: false,
                  color: Colors.black.withValues(alpha: 0.6),
                ),
                AnimatedSlide(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  offset: online ? const Offset(0, 1) : Offset.zero,
                  child: const Align(
                    alignment: Alignment.bottomCenter,
                    child: _AlertPanel(),
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

class _AlertPanel extends StatelessWidget {
  const _AlertPanel();

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.5;
    return GlassSurface(
      blur: 24,
      tint: C.bg2,
      tintOpacity: 0.78,
      radius: const BorderRadius.only(
        topLeft: Radius.circular(kRadius),
        topRight: Radius.circular(kRadius),
      ),
      border: Border(top: BorderSide(color: C.red.withValues(alpha: 0.5), width: 1.4)),
      shadow: glow(opacity: 0.3, blur: 40, offset: const Offset(0, -6)),
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kRadius),
                    gradient: redGradient,
                    boxShadow: glow(opacity: 0.4, blur: 30),
                  ),
                  child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Server Tidak Aktif',
                  style: TextStyle(color: C.text, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Menunggu server menyala kembali. Halaman akan aktif otomatis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.muted, height: 1.5),
                ),
                const SizedBox(height: 26),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.6, color: C.red),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
