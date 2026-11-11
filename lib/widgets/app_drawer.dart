import 'package:flutter/material.dart';

import '../theme.dart';
import '../screens/add_file_screen.dart';
import '../screens/history_screen.dart';
import '../screens/send_screen.dart';
import '../screens/sender_screen.dart';
import '../screens/tools_screen.dart';
import 'common.dart';

/// Menu navigasi utama (hamburger di atas):
/// Add Sender, Send File, Add File, Tools, Riwayat.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: GlassSurface(
        radius: BorderRadius.zero,
        tint: C.surface,
        tintOpacity: 0.92,
        border: const Border(right: BorderSide(color: C.border, width: 1.2)),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 16),
                child: Row(
                  children: [
                    const AppLogo(size: 38),
                    const SizedBox(width: 12),
                    const Text(
                      'ClownDeck',
                      style: TextStyle(color: C.text, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const Divider(color: C.border, height: 1, indent: 22, endIndent: 22),
              const SizedBox(height: 10),
              _DrawerItem(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add Sender',
                onTap: () => _go(context, const SenderScreen()),
              ),
              _DrawerItem(
                icon: Icons.send_rounded,
                label: 'Send File',
                onTap: () => _go(context, const SendScreen()),
              ),
              _DrawerItem(
                icon: Icons.create_new_folder_rounded,
                label: 'Add File',
                badge: 'Baru',
                onTap: () => _go(context, const AddFileScreen()),
              ),
              _DrawerItem(
                icon: Icons.build_circle_rounded,
                label: 'Tools',
                onTap: () => _go(context, const ToolsScreen()),
              ),
              _DrawerItem(
                icon: Icons.history_rounded,
                label: 'Riwayat',
                onTap: () => _go(context, const HistoryScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                IconBadge(icon: icon, size: 42),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: C.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (badge != null) SoftChip(text: badge!, color: C.redBright),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
