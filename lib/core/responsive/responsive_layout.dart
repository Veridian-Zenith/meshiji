import 'package:flutter/material.dart';

enum ScreenSize { small, medium, large }

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget desktopBody;

  const ResponsiveLayout({
    super.key,
    required this.mobileBody,
    required this.desktopBody,
  });

  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 640) {
      return ScreenSize.small;
    } else if (width >= 640 && width <= 1024) {
      return ScreenSize.medium;
    } else {
      return ScreenSize.large;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 640) {
          return desktopBody;
        } else {
          return mobileBody;
        }
      },
    );
  }
}
