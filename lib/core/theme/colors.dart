import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - From PT Body Change Logo
  static const Color primaryYellow = Color(0xFFFFD700); // Gold
  static const Color primaryYellowDark = Color(0xFFEAB308);
  
  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF0A0A0A);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color cardDark = Color(0xFF2C2C2E);
  
  // Aliases for new UI
  static const Color background = backgroundDark;
  static const Color surface = surfaceDark;
  static const Color surfaceLight = cardDark;
  static const Color secondaryBlue = neonCyan;

  // Accent Colors
  static const Color accentBlue = Color(0xFF007AFF);
  static const Color neonCyan = Color(0xFF06B6D4); // Neon Cyan for Members
  static const Color accentGreen = Color(0xFF34C759);
  static const Color accentRed = Color(0xFFFF3B30);
  static const Color accentOrange = Color(0xFFFF9500);
  static const Color success = Color(0xFF34C759); // Green alias
  static const Color error = accentRed; // Red alias
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textTertiary = Color(0xFF666666);
  
  // Gradient Colors
  static const List<Color> yellowGradient = [
    Color(0xFFFDD835),
    Color(0xFFF9A825),
  ];
  
  static const List<Color> darkGradient = [
    Color(0xFF1C1C1E),
    Color(0xFF2C2C2E),
  ];
  
  static const List<Color> muscleGradient = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
  ];
  
  // Glass Morphism
  static const Color glassBackground = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  
  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFFFDD835), // Yellow
    Color(0xFF007AFF), // Blue
    Color(0xFF34C759), // Green
    Color(0xFFFF9500), // Orange
    Color(0xFFFF3B30), // Red
    Color(0xFFAF52DE), // Purple
  ];
}
