import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';

/// Bottom-nav scaffold. On iOS it renders a floating Liquid Glass bar
/// (iOS 26 look); on Android it uses the Material NavigationBar.
class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  static const _tabs = [
    ('/discover', Icons.explore_outlined, Icons.explore, 'Discover'),
    ('/matches', Icons.favorite_border, Icons.favorite, 'Matches'),
    ('/pets', Icons.pets_outlined, Icons.pets, 'My Pets'),
    ('/profile', Icons.person_outline, Icons.person, 'Profile'),
  ];

  int _indexFor(String loc) {
    final i = _tabs.indexWhere((t) => loc.startsWith(t.$1));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final index = _indexFor(loc);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    if (isIOS) {
      // Content flows under the floating glass bar for the translucency to read.
      return Scaffold(
        extendBody: true,
        body: child,
        bottomNavigationBar: _GlassBar(tabs: _tabs, index: index),
      );
    }
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        backgroundColor: PawdColors.surface,
        indicatorColor: PawdColors.brandSoft,
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.$2),
              selectedIcon: Icon(t.$3, color: PawdColors.brand),
              label: t.$4,
            ),
        ],
      ),
    );
  }
}

class _GlassBar extends StatelessWidget {
  final List<(String, IconData, IconData, String)> tabs;
  final int index;
  const _GlassBar({required this.tabs, required this.index});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: LiquidGlass(
          borderRadius: const BorderRadius.all(Radius.circular(26)),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < tabs.length; i++)
                _GlassTab(
                  icon: i == index ? tabs[i].$3 : tabs[i].$2,
                  label: tabs[i].$4,
                  selected: i == index,
                  onTap: () => context.go(tabs[i].$1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GlassTab({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? PawdColors.brand : PawdColors.inkSoft;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
