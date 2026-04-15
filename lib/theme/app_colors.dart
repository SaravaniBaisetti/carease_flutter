import 'package:flutter/material.dart';

class AppColors {
  // ====== LIGHT THEME ======
  // Comforting Backgrounds
  static const Color lightBackground = Color(0xFFF4F7FB); // Soft pale blue-grey
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);

  // Primary / Friendly Tones
  static const Color lightPrimary = Color(0xFF0284C7); // Calming Ocean Blue
  static const Color lightPrimaryLight = Color(0xFF38BDF8);
  static const Color lightPrimaryDark = Color(0xFF0369A1);

  // Secondary / Reassuring Tones
  static const Color lightSecondary =
      Color(0xFF10B981); // Soft reassuring green
  static const Color lightSecondaryLight = Color(0xFF34D399);

  static const Color lightAccentColor = Color(0xFFF59E0B); // Warm amber/orange
  static const Color lightSuccess = Color(0xFF10B981);
  static const Color lightWarning = Color(0xFFF59E0B);
  static const Color lightError = Color(0xFFE11D48);
  static const Color lightErrorLight = Color(0xFFFDA4AF);

  // High Readability Text
  static const Color lightTextPrimary = Color(0xFF1E293B); // Deep charcoal
  static const Color lightTextSecondary = Color(0xFF475569); // Slate 600
  static const Color lightTextTertiary = Color(0xFF78716D); // Gray 500
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200

  // ====== DARK THEME ======
  // Comforting Backgrounds
  static const Color darkBackground = Color(0xFF0F172A); // Deep navy-black
  static const Color darkSurface = Color(0xFF1E293B); // Slate 900
  static const Color darkSurfaceElevated = Color(0xFF334155); // Slate 800

  // Primary / Friendly Tones (more vibrant in dark)
  static const Color darkPrimary =
      Color(0xFF38BDF8); // Brighter blue for contrast
  static const Color darkPrimaryLight = Color(0xFF7DD3FC);
  static const Color darkPrimaryDark = Color(0xFF0284C7);

  // Secondary / Reassuring Tones
  static const Color darkSecondary = Color(0xFF34D399); // Brighter green
  static const Color darkSecondaryLight = Color(0xFF6EE7B7);

  static const Color darkAccentColor = Color(0xFFFCD34D); // Brighter amber
  static const Color darkSuccess = Color(0xFF34D399);
  static const Color darkWarning = Color(0xFFFCD34D);
  static const Color darkError = Color(0xFFF87171); // Brighter red
  static const Color darkErrorLight = Color(0xFFFCA5A5);

  // High Readability Text
  static const Color darkTextPrimary = Color(0xFFF1F5F9); // Almost white
  static const Color darkTextSecondary = Color(0xFFCBD5E1); // Slate 300
  static const Color darkTextTertiary = Color(0xFF94A3B8); // Slate 400
  static const Color darkBorder = Color(0xFF475569); // Slate 700

  // ====== BACKWARD COMPATIBILITY - Default to Light ======
  static const Color background = lightBackground;
  static const Color surface = lightSurface;
  static const Color surfaceElevated = lightSurfaceElevated;
  static const Color primary = lightPrimary;
  static const Color primaryLight = lightPrimaryLight;
  static const Color primaryDark = lightPrimaryDark;
  static const Color secondary = lightSecondary;
  static const Color secondaryLight = lightSecondaryLight;
  static const Color accentColor = lightAccentColor;
  static const Color success = lightSuccess;
  static const Color warning = lightWarning;
  static const Color error = lightError;
  static const Color errorLight = lightErrorLight;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color textLight = Colors.white;

  // ====== GRADIENTS - LIGHT THEME ======
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [lightPrimary, Color(0xFF0EA5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sosGradient = LinearGradient(
    colors: [Color(0xFFE11D48), Color(0xFFF43F5E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [lightPrimary, lightSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ====== GRADIENTS - DARK THEME ======
  static const LinearGradient darkPrimaryGradient = LinearGradient(
    colors: [darkPrimary, Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkSosGradient = LinearGradient(
    colors: [Color(0xFFF87171), Color(0xFFE0444D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkPremiumGradient = LinearGradient(
    colors: [darkPrimary, darkSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
