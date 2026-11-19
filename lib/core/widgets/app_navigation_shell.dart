import 'package:flutter/material.dart';

import '../branding/app_branding.dart';
import '../theme/app_tokens.dart';
import 'app_motion.dart';

/// Same destinations and callbacks; only the presentation adapts to width.
class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });
  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavigationDestination> destinations;
  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  final _bodyKey = GlobalKey();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final body = KeyedSubtree(key: _bodyKey, child: widget.body);
      final selectedIndex = widget.selectedIndex;
      final onSelected = widget.onSelected;
      final destinations = widget.destinations;
      final desktop =
          size.maxWidth >= AppBreakpoints.desktop && size.maxHeight > 550;
      final nav = NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        animationDuration: AppMotion.reduced(context)
            ? Duration.zero
            : AppMotion.standard,
        destinations: destinations,
      );
      return Scaffold(
        body: desktop
            ? Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface
                          .withValues(alpha: .65),
                      border: BorderDirectional(
                        end: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: NavigationRail(
                      extended: true,
                      minExtendedWidth: AppBreakpoints.railWidth,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onSelected,
                      backgroundColor: Colors.transparent,
                      indicatorColor: AppPalette.accent,
                      selectedIconTheme: const IconThemeData(
                        color: AppPalette.primaryDark,
                      ),
                      leading: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 36),
                        child: SizedBox(
                          width: 208,
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.md,
                                ),
                                child: Image.asset(
                                  kAppLogoAsset,
                                  width: 42,
                                  height: 42,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  kAppDisplayName,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      destinations: [
                        for (final destination in destinations)
                          NavigationRailDestination(
                            icon: destination.icon,
                            selectedIcon:
                                destination.selectedIcon ?? destination.icon,
                            label: Text(destination.label),
                          ),
                      ],
                    ),
                  ),
                  Expanded(child: body),
                ],
              )
            : body,
        bottomNavigationBar: desktop
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      boxShadow: AppShadows.surface(
                        Theme.of(context).brightness,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      child: nav,
                    ),
                  ),
                ),
              ),
      );
    },
  );
}
