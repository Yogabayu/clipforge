import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'download_screen.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    for (final name in [
      'youtubedl-android',
      'yt-dlp',
      'QuickJS',
      'EJS',
      'FFmpeg-GPLv3',
      'FFmpeg-LGPLv2.1',
      'Python',
      'whisper.cpp',
      'Whisper-model',
    ]) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString('assets/licenses/$name.txt'));
    }
  });
  runApp(const ClipForgeApp());
}

class ClipForgeApp extends StatelessWidget {
  const ClipForgeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ClipForge',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB))
          .copyWith(primary: const Color(0xFF2563EB), onPrimary: Colors.white),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
    home: const DownloadScreen(),
  );
}
