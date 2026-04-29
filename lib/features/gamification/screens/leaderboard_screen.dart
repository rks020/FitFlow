import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../models/badge_model.dart';
import '../repositories/gamification_repository.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _repo = GamificationRepository();
  List<LeaderboardEntry> _entries = [];
  LeaderboardEntry? _myEntry;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final entries = await _repo.getLeaderboard();
    final myEntry = await _repo.getCurrentUserRank();
    if (mounted)
      setState(() {
        _entries = entries;
        _myEntry = myEntry;
        _isLoading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Text('🏆 ', style: TextStyle(fontSize: 22)),
            Text('Salon Liderlik Tablosu',
                style: AppTextStyles.title3.copyWith(color: Colors.white)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryYellow))
          : _entries.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primaryYellow,
                  backgroundColor: AppColors.surfaceDark,
                  child: CustomScrollView(
                    slivers: [
                      // Podium (ilk 3)
                      if (_entries.length >= 3)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: _buildPodium(),
                          ),
                        ),
                      // Liste (4. ve sonrası)
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                              final start = _entries.length >= 3 ? 3 : 0;
                              final entry = _entries[start + i];
                              return _buildRow(entry);
                            },
                            childCount: _entries.length >= 3
                                ? _entries.length - 3
                                : _entries.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: _myEntry != null && !_entries.any((e) => e.isCurrentUser)
        ? Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppColors.primaryYellow.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sıralamanız',
                  style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                _buildRow(_myEntry!),
              ],
            ),
          )
        : null,
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('Henüz puan yok!',
              style: AppTextStyles.title2.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Text('Derse katıl, su iç ve puan kazan.',
              style: AppTextStyles.body.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPodium() {
    final first = _entries[0];
    final second = _entries[1];
    final third = _entries[2];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPodiumItem(second, 2, 90),
          _buildPodiumItem(first, 1, 120),
          _buildPodiumItem(third, 3, 70),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(LeaderboardEntry e, int rank, double height) {
    final colors = {
      1: const Color(0xFFFFD700),
      2: const Color(0xFFC0C0C0),
      3: const Color(0xFFCD7F32),
    };
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    final color = colors[rank]!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (e.isCurrentUser)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryYellow.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Sen',
                style: TextStyle(
                    color: AppColors.primaryYellow,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        Text(medals[rank]!, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Container(
          width: 72,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                e.displayName.split(' ').first,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${e.totalPoints} pt',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(LeaderboardEntry entry) {
    final isMe = entry.isCurrentUser;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primaryYellow.withOpacity(0.12)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? AppColors.primaryYellow.withOpacity(0.4)
              : AppColors.glassBorder,
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                color: isMe ? AppColors.primaryYellow : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.displayName + (isMe ? ' (Sen)' : ''),
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '${entry.totalPoints} pt',
            style: TextStyle(
              color: isMe ? AppColors.primaryYellow : AppColors.neonCyan,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
