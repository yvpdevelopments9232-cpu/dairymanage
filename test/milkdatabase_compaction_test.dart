import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_management/services/app_config.dart';
import 'package:dairy_management/services/offline_db_helper.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:path/path.dart' as p;

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempDir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('milk_db_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
    AppConfig.isOfflineMode = true;
    AppConfig.isHybridMode = true;
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('getDatabasePath creates MilkDatabase folder and points to dairy_hybrid.db', () async {
    final dbPath = await OfflineDbHelper.instance.getDatabasePath();
    expect(dbPath, contains('MilkDatabase'));
    expect(dbPath, endsWith('dairy_hybrid.db'));

    final folder = Directory(p.dirname(dbPath));
    expect(await folder.exists(), isTrue);
  });

  test('getDatabasePath automatically migrates database from DairyManagement if absent in MilkDatabase', () async {
    final legacyDir = Directory(p.join(tempDir.path, 'DairyManagement'));
    await legacyDir.create(recursive: true);
    final legacyDb = File(p.join(legacyDir.path, 'dairy_hybrid.db'));
    await legacyDb.writeAsString('MOCK_PREVIOUS_DATABASE_DATA');

    // Ensure MilkDatabase file does not exist yet
    final targetDir = Directory(p.join(tempDir.path, 'MilkDatabase'));
    final targetDb = File(p.join(targetDir.path, 'dairy_hybrid.db'));
    expect(await targetDb.exists(), isFalse);

    // Call getDatabasePath
    final dbPath = await OfflineDbHelper.instance.getDatabasePath();
    expect(dbPath, equals(targetDb.path));
    expect(await targetDb.exists(), isTrue);
    expect(await targetDb.readAsString(), equals('MOCK_PREVIOUS_DATABASE_DATA'));
  });
}
