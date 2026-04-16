import 'package:flutter/material.dart';

class AppColors {
  // ====== LAVENDER BACKGROUND THEME ======
  // The solid lavender used across ALL pages
  static const Color lavenderBg = Color(0xFFB5A7D1);
  static const Color lavenderLight = Color(0xFFC8BBE0);
  static const Color lavenderDark = Color(0xFF9B8BBF);

  // ====== OLIVE GREEN (Buttons) ======
  static const Color oliveGreen = Color(0xFF6B8E23);
  static const Color oliveGreenLight = Color(0xFF8FBC3A);
  static const Color oliveGreenDark = Color(0xFF4F6B1A);
  static const Color oliveGreenGlass = Color(0xCC6B8E23); // 80% opacity

  // ====== DEEP RED (SOS Only) ======
  static const Color sosRed = Color(0xFFB71C1C);
  static const Color sosRedLight = Color(0xFFE53935);
  static const Color sosRedGlass = Color(0xCCB71C1C); // 80% opacity

  // ====== LIGHT THEME ======
  static const Color lightBackground = lavenderBg;
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);

  static const Color lightPrimary = oliveGreen;
  static const Color lightPrimaryLight = oliveGreenLight;
  static const Color lightPrimaryDark = oliveGreenDark;

  static const Color lightSecondary = Color(0xFF7EA04D);
  static const Color lightSecondaryLight = Color(0xFF9BC060);

  static const Color lightAccentColor = Color(0xFFF59E0B);
  static const Color lightSuccess = Color(0xFF4CAF50);
  static const Color lightWarning = Color(0xFFF59E0B);
  static const Color lightError = sosRed;
  static const Color lightErrorLight = Color(0xFFEF9A9A);

  static const Color lightTextPrimary = Color(0xFF1E293B);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF78716D);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // ====== DARK THEME ======
  static const Color darkBackground = Color(0xFF2D2640);
  static const Color darkSurface = Color(0xFF3D3555);
  static const Color darkSurfaceElevated = Color(0xFF4D456A);

  static const Color darkPrimary = oliveGreenLight;
  static const Color darkPrimaryLight = Color(0xFFA8D44F);
  static const Color darkPrimaryDark = oliveGreen;

  static const Color darkSecondary = Color(0xFF9BC060);
  static const Color darkSecondaryLight = Color(0xFFB5D87A);

  static const Color darkAccentColor = Color(0xFFFCD34D);
  static const Color darkSuccess = Color(0xFF66BB6A);
  static const Color darkWarning = Color(0xFFFCD34D);
  static const Color darkError = Color(0xFFEF5350);
  static const Color darkErrorLight = Color(0xFFEF9A9A);

  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF475569);

  // ====== BACKWARD COMPATIBILITY ======
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

  // ====== GRADIENTS ======
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [oliveGreen, oliveGreenLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sosGradient = LinearGradient(
    colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [oliveGreen, Color(0xFF7EA04D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark theme gradients
  static const LinearGradient darkPrimaryGradient = LinearGradient(
    colors: [oliveGreenLight, Color(0xFFA8D44F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkSosGradient = LinearGradient(
    colors: [Color(0xFFEF5350), Color(0xFFE53935)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkPremiumGradient = LinearGradient(
    colors: [oliveGreenLight, Color(0xFF9BC060)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
