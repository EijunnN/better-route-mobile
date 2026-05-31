import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/design/tokens.dart';

/// Bottom nav for the home shell — three tabs (Agenda / Mapa / Chat).
///
/// Spec: `Mobile - Specs.html` § 07 / 03 · Home. The active tab gets a
/// solid `bgSurfaceElevated` background and fg-primary text; inactive
/// tabs are transparent with fg-tertiary content.
enum HomeNavTab { agenda, map, chat }

class HomeBottomNav extends StatelessWidget {
  final HomeNavTab current;
  final ValueChanged<HomeNavTab> onChange;

  const HomeBottomNav({
    super.key,
    required this.current,
    required this.onChange,
  });

  static const _tabs = <_TabSpec>[
    _TabSpec(HomeNavTab.agenda, Icons.list_alt_rounded, 'Agenda'),
    _TabSpec(HomeNavTab.map, Icons.map_outlined, 'Mapa'),
    _TabSpec(HomeNavTab.chat, Icons.chat_bubble_outline_rounded, 'Chat'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        decoration: const BoxDecoration(
          color: AppColors.bgBase,
          border: Border(
            top: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
        ),
        child: Row(
          children: _tabs.map((tab) {
            final isActive = tab.value == current;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _NavTab(
                  spec: tab,
                  active: isActive,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChange(tab.value);
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TabSpec {
  final HomeNavTab value;
  final IconData icon;
  final String label;
  const _TabSpec(this.value, this.icon, this.label);
}

class _NavTab extends StatelessWidget {
  final _TabSpec spec;
  final bool active;
  final VoidCallback onTap;

  const _NavTab({
    required this.spec,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rMd,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: 46,
          decoration: BoxDecoration(
            color: active
                ? AppColors.bgSurfaceElevated
                : Colors.transparent,
            borderRadius: AppRadius.rMd,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                spec.icon,
                size: 17,
                color: active ? AppColors.fgPrimary : AppColors.fgTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                spec.label,
                style: AppTypography.label.copyWith(
                  color: active ? AppColors.fgPrimary : AppColors.fgTertiary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
