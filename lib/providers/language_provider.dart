import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/translations.dart';

class LanguageNotifier extends Notifier<String> {
  @override
  String build() {
    _loadSavedLanguage();
    return AppTranslations.currentLanguage;
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString(AppTranslations.keyLanguage);
      if (savedLang != null && (savedLang == 'en' || savedLang == 'mr')) {
        AppTranslations.currentLanguage = savedLang;
        state = savedLang;
      }
    } catch (_) {}
  }

  Future<void> setLanguage(String langCode) async {
    if (langCode != 'en' && langCode != 'mr') return;
    AppTranslations.currentLanguage = langCode;
    state = langCode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppTranslations.keyLanguage, langCode);
    } catch (_) {}
  }

  bool get isMarathi => state == 'mr';
  bool get isEnglish => state == 'en';
}

final languageProvider = NotifierProvider<LanguageNotifier, String>(() {
  return LanguageNotifier();
});
