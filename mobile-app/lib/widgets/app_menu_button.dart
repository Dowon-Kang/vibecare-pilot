import 'package:flutter/material.dart';

class AppMenuAction {
  const AppMenuAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool enabled;
}

class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key, required this.actions});

  final List<AppMenuAction> actions;

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    key: const ValueKey('app-menu-button'),
    tooltip: '메뉴 열기',
    icon: const Icon(Icons.menu),
    onSelected: (index) => actions[index].onSelected(),
    itemBuilder: (context) => [
      for (var index = 0; index < actions.length; index++)
        PopupMenuItem<int>(
          value: index,
          enabled: actions[index].enabled,
          child: Row(
            children: [
              Icon(actions[index].icon, size: 20),
              const SizedBox(width: 12),
              Text(actions[index].label),
            ],
          ),
        ),
    ],
  );
}
