import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../models/badge_model.dart';

class BadgeCollectionWidget extends StatelessWidget {
  final List<BadgeModel> badges;
  const BadgeCollectionWidget({super.key, required this.badges});

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Rozetlerim',
              style: AppTextStyles.title3.copyWith(color: Colors.white),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryYellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${badges.length}',
                style: TextStyle(
                  color: AppColors.primaryYellow,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final badge = badges[index];
              final info = badge.info;
              return GestureDetector(
                onTap: () => _showBadgeDetail(context, info),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 76,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badge.isSeen
                        ? AppColors.surfaceLight
                        : AppColors.primaryYellow.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: badge.isSeen
                          ? AppColors.glassBorder
                          : AppColors.primaryYellow.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(info.emoji, style: const TextStyle(fontSize: 30)),
                      const SizedBox(height: 4),
                      Text(
                        info.title,
                        style: AppTextStyles.caption2.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showBadgeDetail(BuildContext context, BadgeInfo info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              info.title,
              style: AppTextStyles.title2.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              info.description,
              style: AppTextStyles.body.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Kapat', style: TextStyle(color: AppColors.primaryYellow)),
          ),
        ],
      ),
    );
  }
}
