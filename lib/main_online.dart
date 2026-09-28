import 'main.dart' as online_app;
import 'services/app_config.dart';

void main() async {
  AppConfig.isOfflineMode = false;
  online_app.main();
}
