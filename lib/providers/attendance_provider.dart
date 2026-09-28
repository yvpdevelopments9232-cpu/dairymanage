import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import '../services/app_db.dart';
import 'package:intl/intl.dart';

class AttendanceState {
  final String date;
  final List<StaffAttendance> attendances;

  AttendanceState({required this.date, required this.attendances});
}

class AttendanceNotifier extends AsyncNotifier<AttendanceState> {
  dynamic get _supabase => AppDb.client;
  String _currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  String get currentDate => _currentDate;

  @override
  Future<AttendanceState> build() async {
    return _fetchAttendance();
  }

  void setDate(String date) {
    _currentDate = date;
    ref.invalidateSelf();
  }

  Future<AttendanceState> _fetchAttendance() async {
    final response = await _supabase
        .from('staff_attendance')
        .select('*')
        .eq('attendance_date', _currentDate);
        
    final records = (response as List).map((e) => StaffAttendance.fromJson(e)).toList();
    return AttendanceState(date: _currentDate, attendances: records);
  }

  Future<void> markAttendance({required String staffId, required String status}) async {
    try {
      await _supabase.from('staff_attendance').upsert({
        'staff_id': staffId,
        'attendance_date': _currentDate,
        'status': status,
      }, onConflict: 'staff_id, attendance_date');
      
      ref.invalidateSelf();
      await future;
    } catch (e, st) {
      debugPrint('Error marking attendance: $e\n$st');
      rethrow;
    }
  }
}

final attendanceProvider = AsyncNotifierProvider<AttendanceNotifier, AttendanceState>(() => AttendanceNotifier());
