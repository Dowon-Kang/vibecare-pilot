import 'package:flutter/material.dart';

/// Keeps reading lines short on wide web windows and gives sections room to breathe.
class PageContent extends StatelessWidget {
  const PageContent({super.key, required this.children, this.maxWidth = 800});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        children: children,
      ),
    ),
  );
}
