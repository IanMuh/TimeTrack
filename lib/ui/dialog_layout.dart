import 'package:flutter/material.dart';

class DialogContentScrollView extends StatelessWidget {
  const DialogContentScrollView({
    required this.child,
    this.topPadding = 8,
    super.key,
  });

  final Widget child;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: constraints.maxHeight * 0.85,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(top: topPadding),
            child: child,
          ),
        );
      },
    );
  }
}

double dialogContentWidth(
  BuildContext context, {
  required double maxWidth,
}) {
  final availableWidth = MediaQuery.sizeOf(context).width - 128;
  return availableWidth.clamp(0, maxWidth).toDouble();
}
