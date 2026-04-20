import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';

class DailyTipWidget extends StatelessWidget {
  const DailyTipWidget({super.key});

  static const List<Map<String, String>> _tips = [
    {
      'emoji': '💪',
      'tip':
          'Antrenman sonrası 30 dakika içinde protein al. Kas onarımı bu pencerede zirveye çıkar!'
    },
    {
      'emoji': '💧',
      'tip':
          'Günde 3 litre su içmek metabolizmanı %30 hızlandırır. Şimdi bir bardak iç!'
    },
    {
      'emoji': '😴',
      'tip': 'Kaliteli uyku, kilo vermeden daha önemli. 7-9 saat uyumaya çalış.'
    },
    {
      'emoji': '🥦',
      'tip': 'Tabağının yarısı sebze olsun. Lif tokluk hissini 2 kat artırır.'
    },
    {
      'emoji': '🏃',
      'tip':
          'Kardio yapmak için en iyi zaman sabah aç karnına. Yağ yakımı bu saatte en yüksek.'
    },
    {
      'emoji': '🧘',
      'tip':
          'Stres, kortizol artırır ve karın bölgesinde yağ biriktirir. Günde 10 dk nefes egzersizi yap.'
    },
    {
      'emoji': '🍳',
      'tip':
          'Kahvaltıyı atlamak metabolizmanı yavaşlatır. Günün en önemli öğünüdür!'
    },
    {
      'emoji': '🔥',
      'tip':
          'Isınma egzersizi yaralanmaları %50 azaltır. Antrenmana her zaman 10 dk ısınmayla başla.'
    },
    {
      'emoji': '🥗',
      'tip': 'Salata yemeden önce yemek toplam kalori alımını %20 azaltır.'
    },
    {
      'emoji': '⏰',
      'tip':
          'Yemek aralarını 3-4 saate düşür. Bu, kan şekerini dengeler ve yağ yakmayı kolaylaştırır.'
    },
    {
      'emoji': '🚶',
      'tip':
          'Günde 10.000 adım atmak haftada 500 kalori yakar. Asansör yerine merdiveni seç!'
    },
    {
      'emoji': '🫀',
      'tip':
          'Kalp atış hızını hedef bölgede tutmak, yağ yakımını maksimize eder.'
    },
    {
      'emoji': '🍌',
      'tip': 'Antrenman öncesi muz ye! Hızlı enerji ve potasyum kasları korur.'
    },
    {
      'emoji': '🧊',
      'tip': 'Soğuk duş, kas ağrısını %20 azaltır ve metabolizmayı hızlandırır.'
    },
    {
      'emoji': '📏',
      'tip': 'Kilo yerine beden ölçümlerini takip et. Kas kilo yapar, iyi kilo!'
    },
    {
      'emoji': '🎯',
      'tip':
          'Küçük hedefler koy, büyük hayaller yap. Her 1 kg ciddi bir başarıdır.'
    },
    {
      'emoji': '☕',
      'tip':
          'Antrenman öncesi kahve performansını %12 artırır. Siyah kahve en iyisi!'
    },
    {
      'emoji': '🥩',
      'tip':
          'Vücut ağırlığının kg başına 1.6-2.2g protein al. Kas gelişimi için şart!'
    },
    {
      'emoji': '🌅',
      'tip': 'Sabah egzersizi kortizolü dengeler, güne enerjik başlatır.'
    },
    {
      'emoji': '🍇',
      'tip':
          'Antrenmandan 2 saat sonra karbonhidrat almak toparlanmayı hızlandırır.'
    },
    {
      'emoji': '💡',
      'tip':
          'Egzersiz günlüğü tutmak, ilerlemeyi 2 kat hızlandırır. Her antrenmanı kaydet!'
    },
    {
      'emoji': '🫁',
      'tip': 'Derin nefes almayı öğren. Oksijen, yağ yakımının temel yakıtıdır.'
    },
    {
      'emoji': '🌿',
      'tip': 'Yeşil çay metabolizmayı %4 hızlandırır ve antioksidan zengindir.'
    },
    {
      'emoji': '🏋️',
      'tip':
          'Ağırlık antrenmanı, kardioya göre antrenman sonrası 48 saat daha kalori yakar!'
    },
    {
      'emoji': '🎵',
      'tip':
          'Müzikle antrenman yapanlar %15 daha uzun egzersiz yapıyor. Kulaklığını tak!'
    },
    {
      'emoji': '⚡',
      'tip':
          'Egzersiz molalarını 60-90 saniye tut. Bu, maksimum güç gelişimi için idealdir.'
    },
    {
      'emoji': '🌙',
      'tip':
          'Gece 20:00 sonra karbonhidrat azalt. Uyku sırasında vücut depolamaya geçer.'
    },
    {
      'emoji': '🤸',
      'tip':
          'Her antrenman sonrası 5-10 dk esnetme yap. Esneklik, sakatlık riskini yarı yarıya düşürür.'
    },
    {
      'emoji': '🍵',
      'tip':
          'Antrenman sonrası sarımsak tüketmek, kas ağrısını doğal yollarla azaltır.'
    },
    {
      'emoji': '💎',
      'tip':
          'Tutarlılık, her zaman mükemmellikten üstündür. Haftada 3 gün spor, arada bir yapılan 7 günden iyidir.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    final tip = _tips[dayOfYear % _tips.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E),
            AppColors.surfaceLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryYellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(tip['emoji']!, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Günün Tüyosu 💡',
                  style: AppTextStyles.caption1.copyWith(
                    color: AppColors.primaryYellow,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tip['tip']!,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
