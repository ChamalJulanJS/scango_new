import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Read from environment variable
  static String get geminiApiKey =>
      dotenv.env['AIzaSyA2spRfNLtuV5CeVaaJ-Vligmn_j6C7Cok'] ?? '';
  static bool fromDropDown = false;
}
