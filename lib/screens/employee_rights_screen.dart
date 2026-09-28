import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';

class EmployeeRightsScreen extends ConsumerStatefulWidget {
  const EmployeeRightsScreen({super.key});

  @override
  ConsumerState<EmployeeRightsScreen> createState() => _EmployeeRightsScreenState();
}

class _EmployeeRightsScreenState extends ConsumerState<EmployeeRightsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  
  List<Map<String, dynamic>> _roles = [];
  String? _selectedRoleId;
  
  // module_name -> RolePermission
  Map<String, Map<String, bool>> _permissions = {};

  final List<String> _modules = [
    'Dashboard',
    'Farmers',
    'Animals',
    'Milk Collection',
    'Sales',
    'Customers',
    'Products',
    'Stock',
    'Suppliers',
    'Purchases',
    'Payments',
    'Expenses',
    'Staff',
    'Advances',
    'Reports',
    'Rate Management',
    'Settings',
    'Employee Management',
    'Employee Rights'
  ];

  @override
  void initState() {
    super.initState();
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final res = await supabase.from('roles').select().order('name');
      if (mounted) {
        setState(() {
          _roles = List<Map<String, dynamic>>.from(res);
          if (_roles.isNotEmpty) {
            _selectedRoleId = _roles.first['id'];
            _fetchPermissionsForRole(_selectedRoleId!);
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      print(e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPermissionsForRole(String roleId) async {
    setState(() => _isLoading = true);
    final supabase = ref.read(supabaseClientProvider);
    
    // Initialize default false
    final Map<String, Map<String, bool>> perms = {};
    for (var m in _modules) {
      perms[m] = {
        'can_view': false,
        'can_add': false,
        'can_edit': false,
        'can_delete': false,
        'can_print': false,
      };
    }

    try {
      final res = await supabase.from('role_permissions').select().eq('role_id', roleId);
      for (var row in res as List) {
        final module = row['module_name'] as String;
        if (perms.containsKey(module)) {
          perms[module]!['can_view'] = row['can_view'] ?? false;
          perms[module]!['can_add'] = row['can_add'] ?? false;
          perms[module]!['can_edit'] = row['can_edit'] ?? false;
          perms[module]!['can_delete'] = row['can_delete'] ?? false;
          perms[module]!['can_print'] = row['can_print'] ?? false;
        }
      }
      
      if (mounted) {
        setState(() {
          _permissions = perms;
          _isLoading = false;
        });
      }
    } catch (e) {
      print(e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePermissions() async {
    if (_selectedRoleId == null) return;
    setState(() => _isSaving = true);
    
    final supabase = ref.read(supabaseClientProvider);
    
    try {
      // Upsert all permissions
      for (var entry in _permissions.entries) {
        final module = entry.key;
        final p = entry.value;
        
        // We will just try to delete existing and insert new for simplicity, 
        // or use upsert if we had an ID. Since we have a UNIQUE(role_id, module_name) constraint, we can upsert.
        final uid = supabase.auth.currentUser?.id ?? 'offline-admin';
        await supabase.from('role_permissions').upsert({
          'owner_id': uid,
          'role_id': _selectedRoleId,
          'module_name': module,
          'can_view': p['can_view'],
          'can_add': p['can_add'],
          'can_edit': p['can_edit'],
          'can_delete': p['can_delete'],
          'can_print': p['can_print'],
        }, onConflict: 'owner_id, role_id, module_name');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissions saved successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Rights'),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                label: const Text('SAVE PERMISSIONS'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: _isSaving ? null : _savePermissions,
              ),
            )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Row(
                  children: [
                    const Text('Select Role: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedRoleId,
                        decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                        items: _roles.map((r) => DropdownMenuItem<String>(
                          value: r['id'].toString(), 
                          child: Text(r['name'].toString())
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedRoleId = val);
                            _fetchPermissionsForRole(val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                      columns: const [
                        DataColumn(label: Text('Module', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('View', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Add', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Edit', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Delete', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Print', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _modules.map((m) {
                        final p = _permissions[m]!;
                        return DataRow(
                          cells: [
                            DataCell(Text(m, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Checkbox(
                              value: p['can_view'],
                              onChanged: (v) => setState(() => p['can_view'] = v ?? false),
                            )),
                            DataCell(Checkbox(
                              value: p['can_add'],
                              onChanged: (v) => setState(() => p['can_add'] = v ?? false),
                            )),
                            DataCell(Checkbox(
                              value: p['can_edit'],
                              onChanged: (v) => setState(() => p['can_edit'] = v ?? false),
                            )),
                            DataCell(Checkbox(
                              value: p['can_delete'],
                              onChanged: (v) => setState(() => p['can_delete'] = v ?? false),
                            )),
                            DataCell(Checkbox(
                              value: p['can_print'],
                              onChanged: (v) => setState(() => p['can_print'] = v ?? false),
                            )),
                          ]
                        );
                      }).toList(),
                    ),
                  ),
                ),
              )
            ],
        ),
    );
  }
}
