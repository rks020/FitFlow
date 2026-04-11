import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class MemberStatCard extends StatelessWidget {
  final int totalCount;
  final int activeCount;
  final int passiveCount;
  final VoidCallback? onTap;
  final String? backgroundImage;

  const MemberStatCard({
    super.key,
    required this.totalCount,
    required this.activeCount,
    required this.passiveCount,
    this.onTap,
    this.backgroundImage,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          if (backgroundImage != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: backgroundImage!.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: backgroundImage!,
                        fit: BoxFit.cover,
                        color: Colors.black.withOpacity(0.6),
                        colorBlendMode: BlendMode.darken,
                      )
                    : Image.asset(
                        backgroundImage!,
                        fit: BoxFit.cover,
                        color: Colors.black.withOpacity(0.6),
                        colorBlendMode: BlendMode.darken,
                      ),
              ),
            ),
          
          // Gradient Overlay
          if (backgroundImage != null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),

          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon placeholder container
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.people_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    // Title at Top Right
                    Text(
                      'Üyeler',
                      style: AppTextStyles.caption1.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatItem('Toplam', totalCount),
                    _buildStatItem('Aktif', activeCount, color: AppColors.accentGreen),
                    _buildStatItem('Pasif', passiveCount, color: AppColors.accentRed),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.caption2.copyWith(
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: AppTextStyles.title2.copyWith(
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}
