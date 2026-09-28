import '../main.dart';
import '../services/app_config.dart';

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "auth_provider.dart";

class RolePermission {
  final String moduleName;
  final bool canView;
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;
  final bool canPrint;

  RolePermission({
    required this.moduleName,
    required this.canView,
    required this.canAdd,
    required this.canEdit,
    required this.canDelete,
    required this.canPrint,
  });

  factory RolePermission.fromJson(Map<String, dynamic> json) {
    bool toBool(dynamic val) => val is bool ? val : (val == 1 || val == 'true');
    return RolePermission(
      moduleName: json["module_name"] ?? "",
      canView: toBool(json["can_view"]),
      canAdd: toBool(json["can_add"]),
      canEdit: toBool(json["can_edit"]),
      canDelete: toBool(json["can_delete"]),
      canPrint: toBool(json["can_print"]),
    );
  }
}

class Employee {
  final String id;
  final String name;
  final String? mobile;
  final String username;
  final String pin;
  final String? roleId;
  final bool isActive;
  final String? roleName;

  Employee({
    required this.id,
    required this.name,
    this.mobile,
    required this.username,
    required this.pin,
    this.roleId,
    required this.isActive,
    this.roleName,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    dynamic act = json["is_active"];
    bool active = act is bool ? act : (act == 1 || act == null || act == 'true');
    return Employee(
      id: json["id"],
      name: json["name"],
      mobile: json["mobile"],
      username: json["username"],
      pin: json["pin"],
      roleId: json["role_id"],
      isActive: active,
      roleName: json["roles"] != null ? json["roles"]["name"] : (json["role_name"] ?? null),
    );
  }
}

class AppSession {
  final bool isAdmin;
  final Employee? activeEmployee;
  final Map<String, RolePermission> permissions;

  AppSession({
    required this.isAdmin,
    this.activeEmployee,
    required this.permissions,
  });

  bool canView(String module) => isAdmin || (permissions[module]?.canView ?? false);
  bool canAdd(String module) => isAdmin || (permissions[module]?.canAdd ?? false);
  bool canEdit(String module) => isAdmin || (permissions[module]?.canEdit ?? false);
  bool canDelete(String module) => isAdmin || (permissions[module]?.canDelete ?? false);
  bool canPrint(String module) => isAdmin || (permissions[module]?.canPrint ?? false);
}

class SessionNotifier extends Notifier<AppSession?> {
  @override
  AppSession? build() {
    return null; // Null means no one has selected an account on the sub-login screen
  }

  Future<void> loginAsAdmin({bool saveSession = true}) async {
    final supabase = ref.read(supabaseClientProvider);
    state = AppSession(isAdmin: true, permissions: {});
    if (saveSession) prefs.setString(AppConfig.prefKey('active_sub_account_type'), 'admin');
    
    // Log audit
    try {
      supabase.from("audit_logs").insert({
        "user_type": "Admin",
        "user_name": "Admin",
        "action": "Account Switch",
        "details": "Logged into Admin Dashboard"
      });
    } catch (e) {
      // ignore
    }
  }

  Future<bool> loginAsEmployee(Employee emp, String pin, {bool saveSession = true}) async {
    if (emp.pin != pin || !emp.isActive) return false;
    
    final supabase = ref.read(supabaseClientProvider);
    
    // Fetch permissions for this role
    Map<String, RolePermission> perms = {};
    if (emp.roleId != null) {
      try {
        final res = await supabase
            .from("role_permissions")
            .select()
            .eq("role_id", emp.roleId!);
            
        for (var row in res as List) {
          final p = RolePermission.fromJson(row);
          perms[p.moduleName] = p;
        }
      } catch (e) {
        print("Error fetching permissions: $e");
      }
    }
    
    state = AppSession(
      isAdmin: false,
      activeEmployee: emp,
      permissions: perms,
    );
    if (saveSession) {
      prefs.setString(AppConfig.prefKey('active_sub_account_type'), 'employee');
      prefs.setString(AppConfig.prefKey('active_employee_id'), emp.id);
      prefs.setString(AppConfig.prefKey('active_employee_pin'), pin);
    }
    
    // Log audit
    try {
      supabase.from("audit_logs").insert({
        "user_type": "Employee",
        "user_name": emp.name,
        "action": "Account Switch",
        "details": "Logged into Employee Dashboard"
      });
    } catch (e) {
      // ignore
    }
    
    return true;
  }

  void logoutSubAccount() {
    prefs.remove(AppConfig.prefKey('active_sub_account_type'));
    prefs.remove(AppConfig.prefKey('active_employee_id'));
    prefs.remove(AppConfig.prefKey('active_employee_pin'));
    state = null;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, AppSession?>(() {
  return SessionNotifier();
});

final employeesListProvider = FutureProvider<List<Employee>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  final res = await supabase.from("employees").select("*, roles(name)").order("name");
  return (res as List).map((e) => Employee.fromJson(e)).toList();
});

