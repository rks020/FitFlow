extension TurkishStringExtension on String {
  /// Converts string to lowercase with Turkish character awareness (İ -> i, I -> ı).
  String turkishToLower() {
    return this
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase();
  }
}
