import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Colors.white;
  static const Color accentColor = Color(0xFF000000);
  static const Color buttonColor = Color(0xFF000000);
  static const Color redColor = Color(0xFFFF0000);
  static const Color greenColor = Color(0xFF33FF00);
  static const Color greyColor = Color(0xFFD9D9D9);
  static const Color darkBlueColor = Color(0xFF15102D);
  static const Color darkGreyColor = Color(0xFF060606);
  static const Color lightGreyColor = Color(0xFFEBEBEB);

  static ThemeData lightTheme() {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: primaryColor,
      fontFamily: GoogleFonts.poppins().fontFamily,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: primaryColor,
        error: redColor,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(
          fontSize: 48.0,
          fontWeight: FontWeight.w600,
          color: accentColor,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 32.0,
          fontWeight: FontWeight.w600,
          color: accentColor,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 24.0,
          fontWeight: FontWeight.w500,
          color: accentColor,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 20.0,
          fontWeight: FontWeight.w500,
          color: accentColor,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 18.0,
          fontWeight: FontWeight.w400,
          color: accentColor,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 16.0,
          fontWeight: FontWeight.w400,
          color: accentColor,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
          color: accentColor,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15.0),
          textStyle: GoogleFonts.poppins(
            fontSize: 16.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: const BorderSide(color: accentColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: const BorderSide(color: accentColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15.0),
          borderSide: const BorderSide(color: accentColor, width: 2.0),
        ),
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 15.0,
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 16.0,
          color: accentColor.withValues(alpha: 0.7),
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 16.0,
          color: accentColor.withValues(alpha: 0.5),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBlueColor,
        elevation: 0,
        centerTitle: true,
        foregroundColor: primaryColor,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20.0,
          fontWeight: FontWeight.w500,
          color: primaryColor,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkBlueColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: lightGreyColor,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12.0,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12.0,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
