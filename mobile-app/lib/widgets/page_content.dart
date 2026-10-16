import 'package:flutter/material.dart';

/// Keeps reading lines short on wide web windows and gives sections room to breathe.
class PageContent extends StatelessWidget {
  const PageContent({
    super.key,
    required this.children,
    this.maxWidth = 800,
    this.controller,
  });

  final List<Widget> children;
  final double maxWidth;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        children: children,
      ),
    ),
  );
}
