// lib/src/core/config/theme/app_colors.dart
import 'package:flutter/material.dart';

/// Semantic Color Palette based on Bali Tourist ID Mockup
class AppColors {
  // --- Core Theme Colors ---
  /// Deep obsidian / dark navy background
  static const Color background = Color(0xFF0B111E);

  /// Elevated card surface
  static const Color surface = Color(0xFF131D2E);

  /// Slightly lighter card / container surface
  static const Color surfaceLight = Color(0xFF1E293B);

  /// Main brand primary color (Teal / Toska)
  static const Color primary = Color(0xFF0F8E82);

  /// Accent color for interactive elements and buttons
  static const Color accent = Color(0xFF0F8E82);

  /// Primary typography color (Slate 50 / White)
  static const Color font = Color(0xFFF8FAFC);

  /// Secondary typography color (Slate 400)
  static const Color fontSecondary = Color(0xFF94A3B8);

  /// Muted typography / hint color (Slate 500)
  static const Color fontMuted = Color(0xFF64748B);

  /// Divider and border color
  static const Color divider = Color(0xFF1E293B);

  // --- Verified / Approved (Teal / Toska) ---
  static const Color teal = Color(0xFF0F8E82);
  static const Color tealLight = Color(0xFF2FBFAF);
  static const Color tealSoft = Color(0xFFE7F7F5);
  static const Color tealDark = Color(0xFF0A6F66);
  static const Color verified = Color(0xFF0F8E82);

  // --- Identity & NFC (Purple / Indigo Bali Royal) ---
  static const Color purple = Color(0xFF4B2E83);
  static const Color purpleLight = Color(0xFF7C3AED);
  static const Color purpleSoft = Color(0xFFF3EFFA);
  static const Color purpleDark = Color(0xFF221240);
  static const Color identity = Color(0xFF4B2E83);

  // --- Conditional / Pending (Amber) ---
  static const Color amber = Color(0xFFE29A17);
  static const Color amberDark = Color(0xFFB87A08);
  static const Color amberSoft = Color(0xFFFFF6E5);
  static const Color warning = Color(0xFFE29A17);

  // --- Prohibited / Rejected / Error (Rose / Crimson) ---
  static const Color rose = Color(0xFFD64545);
  static const Color roseDark = Color(0xFFB93232);
  static const Color roseSoft = Color(0xFFFDECEC);
  static const Color error = Color(0xFFD64545);
}
