import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';

enum DisplayMode {
  previous, // Desktop layout with zooming logic & fixed desktop canvas
  mobile,   // Responsive touch-friendly layout optimized for mobile
}

class DisplayModeNotifier extends Notifier<DisplayMode> {
  static const String keyDisplayMode = 'display_mode';

  @override
  DisplayMode build() {
    try {
      final savedMode = prefs.getString(keyDisplayMode);
      if (savedMode == 'mobile') {
        return DisplayMode.mobile;
      } else if (savedMode == 'previous') {
        return DisplayMode.previous;
      }
    } catch (_) {}
    return DisplayMode.previous;
  }

  Future<void> setDisplayMode(DisplayMode mode) async {
    state = mode;
    try {
      await prefs.setString(keyDisplayMode, mode == DisplayMode.mobile ? 'mobile' : 'previous');
    } catch (_) {}
  }

  bool get isMobile => state == DisplayMode.mobile;
  bool get isPrevious => state == DisplayMode.previous;
}

final displayModeProvider = NotifierProvider<DisplayModeNotifier, DisplayMode>(() {
  return DisplayModeNotifier();
});
