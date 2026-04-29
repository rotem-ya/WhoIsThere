import 'package:flutter/material.dart';
import '../../core/ui/app_text_styles.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;

  const AppHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: leading ?? const SizedBox.shrink(),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleLight,
            ),
          ),
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerLeft,
              child: trailing ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
