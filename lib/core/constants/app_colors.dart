import 'package:flutter/material.dart';

class AppColors {
  // Brand gradient colors — matches the web violet-fuchsia theme
  static const Color primary       = Color(0xFF7C3AED); // violet-600
  static const Color primaryDark   = Color(0xFF6D28D9); // violet-700
  static const Color secondary     = Color(0xFFD946EF); // fuchsia-500
  static const Color primaryLight  = Color(0xFFEDE9FE); // violet-100

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFD946EF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF6D28D9), Color(0xFF9333EA), Color(0xFFD946EF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Semantic
  static const Color success  = Color(0xFF059669);
  static const Color error    = Color(0xFFDC2626);
  static const Color warning  = Color(0xFFF97316);
  static const Color info     = Color(0xFF3B82F6);
  static const Color orange   = Color(0xFFF97316);

  // Text
  static const Color textPrimary   = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight     = Color(0xFF9CA3AF);

  // Background
  static const Color background    = Color(0xFFF9FAFB);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color border        = Color(0xFFE5E7EB);
  static const Color borderLight   = Color(0xFFF3F4F6);

  // Star rating
  static const Color star = Color(0xFFFBBF24);
}
