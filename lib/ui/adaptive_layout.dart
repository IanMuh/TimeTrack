import 'package:flutter/material.dart';

enum AdaptiveSizeClass { compact, medium, expanded }

const double compactBreakpoint = 600;
const double expandedBreakpoint = 840;

AdaptiveSizeClass adaptiveSizeClassFor(double width) {
  if (width < compactBreakpoint) {
    return AdaptiveSizeClass.compact;
  }
  if (width < expandedBreakpoint) {
    return AdaptiveSizeClass.medium;
  }
  return AdaptiveSizeClass.expanded;
}

class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    required this.children,
    this.maxWidth = 1120,
    this.pageKey,
    super.key,
  });

  final List<Widget> children;
  final double maxWidth;
  final PageStorageKey<String>? pageKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = adaptiveSizeClassFor(constraints.maxWidth);
        final horizontalPadding = switch (sizeClass) {
          AdaptiveSizeClass.compact => 16.0,
          AdaptiveSizeClass.medium => 24.0,
          AdaptiveSizeClass.expanded => 32.0,
        };
        final verticalPadding =
            sizeClass == AdaptiveSizeClass.compact ? 16.0 : 24.0;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: Scrollbar(
            child: ListView(
              key: pageKey,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SectionGap extends StatelessWidget {
  const SectionGap({super.key, this.height = 16});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}
