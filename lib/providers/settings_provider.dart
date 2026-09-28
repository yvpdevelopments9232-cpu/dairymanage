import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';

class AppSettingsModel {
  final String id;
  final String dairyName;
  final String? ownerName;
  final String? mobile;
  final String? address;
  final String? gstNo;
  final String? receiptHeader;
  final String? receiptFooter;
  final String? logoUrl;
  final Uint8List? logoBytes;

  AppSettingsModel({
    required this.id, required this.dairyName, this.ownerName,
    this.mobile, this.address, this.gstNo, this.receiptHeader, this.receiptFooter, this.logoUrl, this.logoBytes
  });

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) => AppSettingsModel(
    id: json['id'],
    dairyName: json['dairy_name'] ?? 'My Dairy',
    ownerName: json['owner_name'],
    mobile: json['mobile'],
    address: json['address'],
    gstNo: json['gst_no'],
    receiptHeader: json['receipt_header'],
    receiptFooter: json['receipt_footer'],
    logoUrl: json['logo_url'],
    logoBytes: json['logo_url'] != null && json['logo_url'].toString().isNotEmpty ? base64Decode(json['logo_url']) : null,
  );
}

class SettingsNotifier extends AsyncNotifier<AppSettingsModel?> {
  @override
  Future<AppSettingsModel?> build() async {
    return _fetchSettings();
  }

  Future<AppSettingsModel?> _fetchSettings() async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final response = await supabase.from('app_settings').select().maybeSingle();
      if (response != null) {
        return AppSettingsModel.fromJson(response);
      }
    } catch (e) {
      // Ignored for now
    }
    return null;
  }

  Future<void> saveSettings({
    required String dairyName, String? ownerName, String? mobile,
    String? address, String? gstNo, String? header, String? footer,
    String? logoBase64,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    final data = {
      'dairy_name': dairyName,
      'owner_name': ownerName,
      'mobile': mobile,
      'address': address,
      'gst_no': gstNo,
      'receipt_header': header,
      'receipt_footer': footer,
      if (logoBase64 != null) 'logo_url': logoBase64,
    };

    state = const AsyncValue.loading();
    try {
      final existing = await supabase.from('app_settings').select('id').maybeSingle();
      if (existing != null) {
        await supabase.from('app_settings').update(data).eq('id', existing['id']);
      } else {
        await supabase.from('app_settings').insert(data);
      }
      state = await AsyncValue.guard(() => _fetchSettings());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettingsModel?>(() {
  return SettingsNotifier();
});
