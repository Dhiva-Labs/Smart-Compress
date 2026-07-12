import 'package:flutter/material.dart';

/// Lays children out side by side with equal widths when there is room,
/// stacked vertically on narrow (phone) layouts.
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double breakpoint;

  const ResponsiveRow(
      {super.key, required this.children, this.breakpoint = 560});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= breakpoint) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: children[i]),
            ],
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            children[i],
          ],
        ],
      );
    });
  }
}
