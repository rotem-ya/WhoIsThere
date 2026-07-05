import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../providers/providers.dart';
import '../../services/app_update_service.dart';
import '../../services/qa_logger_service.dart';
import '../../widgets/common/app_header.dart';

/// Lists "our other apps", fully driven by the admin-controlled remote config
/// (app_config/app → ourApps). No app is hard-coded, so the list can grow
/// without shipping a new build. Tapping a row opens its store page.
class OurAppsScreen extends ConsumerWidget {
  const OurAppsScreen({super.key});

  Future<void> _open(BuildContext context, OurApp app) async {
    HapticFeedback.lightImpact();
    final url = app.storeUrl;
    if (url.isEmpty) return;
    QaLoggerService.instance.log('OUR_APPS', 'OPEN_STORE ${app.name}');
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(appUpdateInfoProvider).valueOrNull?.ourApps ?? const [];

    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: AppHeader(
              title: 'האפליקציות שלנו',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.maybePop(context);
                },
              ),
            ),
          ),
          Expanded(
            child: apps.isEmpty
                ? const Center(
                    child: Text('בקרוב — עוד משחקים בדרך 🎮',
                        style: TextStyle(
                            color: Color(0xFF4A8BAA),
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.lg +
                            MediaQuery.of(context).viewPadding.bottom),
                    itemCount: apps.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) =>
                        _AppTile(app: apps[i], onTap: () => _open(context, apps[i])),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final OurApp app;
  final VoidCallback onTap;
  const _AppTile({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: app.hasLink ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1828),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: const Color(0xFF1E3A5A).withOpacity(0.7), width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                  child: Text(app.emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  if (app.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(app.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF4A8BAA),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (app.hasLink)
              const Icon(Icons.download_rounded,
                  color: Color(0xFF3DCCAA), size: 22),
          ],
        ),
      ),
    );
  }
}
