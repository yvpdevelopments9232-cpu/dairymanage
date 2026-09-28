import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import '../services/app_db.dart';

class StaffReportState {
  final Staff? staff;
  final List<StaffAttendance> attendanceList;
  final List<StaffTransaction> advanceList;
  final double totalPresentDays;
  final double calculatedSalary;
  final double totalAdvances;
  final double netPayable;

  StaffReportState({
    required this.staff,
    required this.attendanceList,
    required this.advanceList,
    required this.totalPresentDays,
    required this.calculatedSalary,
    required this.totalAdvances,
    required this.netPayable,
  });
}

class StaffReportNotifier extends AsyncNotifier<StaffReportState> {
  dynamic get _supabase => AppDb.client;
  String? _staffId;
  String? _startDate;
  String? _endDate;

  @override
  Future<StaffReportState> build() async {
    return _fetchReport();
  }

  void setFilter(String staffId, String start, String end) {
    _staffId = staffId;
    _startDate = start;
    _endDate = end;
    ref.invalidateSelf();
  }

  Future<StaffReportState> _fetchReport() async {
    if (_staffId == null || _startDate == null || _endDate == null) {
      return StaffReportState(staff: null, attendanceList: [], advanceList: [], totalPresentDays: 0, calculatedSalary: 0, totalAdvances: 0, netPayable: 0);
    }

    // Fetch Staff Details
    final staffRes = await _supabase.from('staff').select('*').eq('id', _staffId!).single();
    final staff = Staff.fromJson(staffRes);

    // Fetch Attendance
    final attRes = await _supabase.from('staff_attendance')
        .select('*')
        .eq('staff_id', _staffId!)
        .gte('attendance_date', _startDate!)
        .lte('attendance_date', _endDate!)
        .order('attendance_date');
    final attendances = (attRes as List).map((e) => StaffAttendance.fromJson(e)).toList();

    // Fetch Advances
    final advRes = await _supabase.from('staff_transactions')
        .select('*')
        .eq('staff_id', _staffId!)
        .eq('type', 'Advance')
        .gte('transaction_date', _startDate!)
        .lte('transaction_date', _endDate!)
        .order('transaction_date');
    final advances = (advRes as List).map((e) => StaffTransaction.fromJson(e)).toList();

    // Calculations
    double presentDays = 0;
    for (var a in attendances) {
      if (a.status == 'Present') presentDays += 1;
      else if (a.status == 'Half-Day') presentDays += 0.5;
    }

    double calcSalary = 0;
    if (staff.salaryType == 'Daily') {
      calcSalary = staff.salaryAmount * presentDays;
    } else {
      // Monthly (assuming 30 days standard)
      calcSalary = (staff.salaryAmount / 30) * presentDays;
    }

    double totalAdv = advances.fold(0.0, (sum, item) => sum + item.amount);
    double net = calcSalary - totalAdv;

    return StaffReportState(
      staff: staff,
      attendanceList: attendances,
      advanceList: advances,
      totalPresentDays: presentDays,
      calculatedSalary: calcSalary,
      totalAdvances: totalAdv,
      netPayable: net,
    );
  }
}

final staffReportProvider = AsyncNotifierProvider<StaffReportNotifier, StaffReportState>(() => StaffReportNotifier());
