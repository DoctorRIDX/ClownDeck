import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'conn_monitor.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';
import 'widgets/server_down_banner.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: C.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  ConnMonitor.instance.start();
  runApp(const ClownDeckApp());
}

class ClownDeckApp extends StatelessWidget {
  const ClownDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClownDeck',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _AppRoot(),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const ServerDownOverlay(),
          ],
        );
      },
    );
  }
}

/// Memutuskan: tampilkan Welcome (hanya sekali, saat aplikasi benar-benar
/// baru dibuka) atau langsung ke Dashboard.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _onboarded = p.getBool(kOnboardedKey) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboarded == null) {
      return const Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: bgGradient),
          child: Center(child: CircularProgressIndicator(color: C.red)),
        ),
      );
    }
    if (_onboarded == false) {
      return OnboardingScreen(onDone: () => setState(() => _onboarded = true));
    }
    return const HomeScreen();
  }
}
