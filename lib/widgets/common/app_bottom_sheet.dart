import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/ui/app_spacing.dart';
import '../../services/sfx_service.dart';

class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppBottomSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.lg),
  }) {
    SfxService.instance.sheetOpen();
    final future = showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AppBottomSheet(
          padding: padding,
          child: child,
        );
      },
    );
    future.whenComplete(() => SfxService.instance.sheetClose());
    return future;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(32),
          ),
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
