import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTextStyles {
  // Large Titles
  static TextStyle largeTitle = GoogleFonts.montserrat(
    fontSize: 34,
    fontWeight: FontWeight.w800, // ExtraBold
    letterSpacing: 0.37,
    color: AppColors.textPrimary,
  );
  
  // Titles
  static TextStyle title1 = GoogleFonts.montserrat(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.36,
    color: AppColors.textPrimary,
  );
  
  static TextStyle title2 = GoogleFonts.montserrat(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.35,
    color: AppColors.textPrimary,
  );
  
  static TextStyle title3 = GoogleFonts.montserrat(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.38,
    color: AppColors.textPrimary,
  );
  
  // Headline
  static TextStyle headline = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    color: AppColors.textPrimary,
  );
  
  // Body
  static TextStyle body = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
    color: AppColors.textPrimary,
  );
  
  static TextStyle bodySecondary = GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
    color: AppColors.textSecondary,
  );
  
  // Callout
  static TextStyle callout = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.32,
    color: AppColors.textPrimary,
  );
  
  // Subheadline
  static TextStyle subheadline = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
    color: AppColors.textSecondary,
  );
  
  // Footnote
  static TextStyle footnote = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    color: AppColors.textSecondary,
  );
  
  // Caption
  static TextStyle caption1 = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    color: AppColors.textSecondary,
  );
  
  static TextStyle caption2 = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.06,
    color: AppColors.textTertiary,
  );
}
