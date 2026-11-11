import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../widgets/common.dart';

const kOnboardedKey = 'app_onboarded';

/// Welcome + Privacy Policy + izin akses file — tampil sekali saja,
/// persis saat aplikasi pertama kali dibuka.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  bool _requesting = false;
  bool? _granted;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    _pageCtrl.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(kOnboardedKey, true);
    widget.onDone();
  }

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);
    try {
      final status = await Permission.storage.request();
      if (mounted) setState(() => _granted = status.isGranted);
    } catch (_) {
      if (mounted) setState(() => _granted = false);
    }
    if (mounted) setState(() => _requesting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _OnboardPage(
                      icon: Icons.waving_hand_rounded,
                      title: 'Selamat Datang',
                      message: 'ClownDeck — kirim file WhatsApp dan buat file dummy, langsung dari HP.',
                      buttonLabel: 'Lanjut',
                      onPressed: _next,
                    ),
                    _OnboardPage(
                      icon: Icons.privacy_tip_rounded,
                      title: 'Privasi',
                      message: 'Semua data diproses oleh server di HP ini saja. Tidak ada yang dikirim ke pihak lain.',
                      buttonLabel: 'Lanjut',
                      onPressed: _next,
                    ),
                    _OnboardPage(
                      icon: Icons.folder_special_rounded,
                      title: 'Izin Akses File',
                      message: 'Diperlukan untuk fitur Add File agar file yang dibuat bisa dilihat di penyimpanan HP.',
                      buttonLabel: _granted == true ? 'Mulai' : 'Izinkan Akses',
                      loading: _requesting,
                      onPressed: _granted == true
                          ? _finish
                          : () async {
                              await _requestPermission();
                              if (_granted == true) _finish();
                            },
                      secondaryLabel: 'Lewati',
                      onSecondary: _finish,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? C.red : C.border,
                        borderRadius: BorderRadius.circular(kRadius),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool loading;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
    this.loading = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadius),
              gradient: redGradient,
              boxShadow: glow(opacity: 0.4, blur: 40),
            ),
            child: Icon(icon, size: 54, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: C.text, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: C.muted, height: 1.5, fontSize: 14),
          ),
          const SizedBox(height: 36),
          PrimaryButton(label: buttonLabel, icon: Icons.arrow_forward_rounded, loading: loading, onPressed: onPressed),
          if (secondaryLabel != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onSecondary,
              child: Text(secondaryLabel!, style: const TextStyle(color: C.muted)),
            ),
          ],
        ],
      ),
    );
  }
}
