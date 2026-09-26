import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fading_app_bar_backdrop.dart';

/// Shared navigation bar. Use with Scaffold.extendBodyBehindAppBar and put
/// [contentPadding] inside the scroll view so content can pass under the blur.
class FadingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FadingAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
    this.leadingWidth,
    this.foregroundColor,
    this.tintColor,
    this.titleTextStyle,
    this.systemOverlayStyle,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool? centerTitle;
  final bool automaticallyImplyLeading;
  final double? leadingWidth;
  final Color? foregroundColor;
  final Color? tintColor;
  final TextStyle? titleTextStyle;
  final SystemUiOverlayStyle? systemOverlayStyle;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  /// Call with the screen's context, above its Scaffold.
  static EdgeInsets contentPadding(
    BuildContext context,
    EdgeInsets padding, {
    double bottomHeight = 0,
  }) => padding.copyWith(
    top:
        padding.top +
        MediaQuery.paddingOf(context).top +
        kToolbarHeight +
        bottomHeight,
  );

  @override
  Widget build(BuildContext context) => AppBar(
    title: title,
    leading: leading,
    actions: actions,
    bottom: bottom,
    centerTitle: centerTitle,
    automaticallyImplyLeading: automaticallyImplyLeading,
    leadingWidth: leadingWidth,
    foregroundColor: foregroundColor,
    iconTheme: foregroundColor == null
        ? null
        : IconThemeData(color: foregroundColor),
    actionsIconTheme: foregroundColor == null
        ? null
        : IconThemeData(color: foregroundColor),
    titleTextStyle: titleTextStyle,
    systemOverlayStyle: systemOverlayStyle,
    flexibleSpace: FadingAppBarBackdrop(tintColor: tintColor),
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
  );
}
