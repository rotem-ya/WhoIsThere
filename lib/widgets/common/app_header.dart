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
            // Scale the title down to fit rather than truncating with "…".
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: AppTextStyles.titleLight,
              ),
            ),
          ),
          SizedBox(
            width: 72,
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
