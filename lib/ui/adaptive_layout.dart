import 'package:flutter/material.dart';

enum AdaptiveSizeClass { compact, medium, expanded }

const double compactBreakpoint = 600;
const double expandedBreakpoint = 840;
const double adaptiveCompactScrollEndGap = 88;
const double adaptiveWideScrollEndGap = 72;

AdaptiveSizeClass adaptiveSizeClassFor(double width) {
  if (width < compactBreakpoint) {
    return AdaptiveSizeClass.compact;
  }
  if (width < expandedBreakpoint) {
    return AdaptiveSizeClass.medium;
  }
  return AdaptiveSizeClass.expanded;
}

class AdaptivePage extends StatefulWidget {
  const AdaptivePage({
    required this.children,
    this.maxWidth = 1120,
    this.pageKey,
    this.onRefresh,
    super.key,
  });

  final List<Widget> children;
  final double maxWidth;
  final PageStorageKey<String>? pageKey;
  final Future<void> Function()? onRefresh;

  @override
  State<AdaptivePage> createState() => _AdaptivePageState();
}

class _AdaptivePageState extends State<AdaptivePage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
        final scrollEndGap = sizeClass == AdaptiveSizeClass.compact
            ? adaptiveCompactScrollEndGap
            : adaptiveWideScrollEndGap;

        Widget scrollable = ListView(
          key: widget.pageKey,
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            verticalPadding + scrollEndGap,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.children,
                ),
              ),
            ),
          ],
        );

        final onRefresh = widget.onRefresh;
        if (onRefresh != null) {
          scrollable = RefreshIndicator(
            onRefresh: onRefresh,
            child: scrollable,
          );
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: Scrollbar(
            controller: _scrollController,
            child: scrollable,
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
