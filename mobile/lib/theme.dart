import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const terracotta = Color(0xFFC45C26);
const cream = Color(0xFFFFF6EE);
const ink = Color(0xFF2B211C);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: terracotta,
      primary: terracotta,
      surface: cream,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: cream,
  );
  return base.copyWith(
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).apply(
      bodyColor: ink,
      displayColor: ink,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: cream,
      foregroundColor: ink,
      elevation: 0,
      titleTextStyle: GoogleFonts.nunito(
        fontWeight: FontWeight.w800,
        fontSize: 20,
        color: ink,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
