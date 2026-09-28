import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';

class EmployeeManagementScreen extends ConsumerStatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  ConsumerState<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends ConsumerState<EmployeeManagementScreen> {
  bool _isLoading = false;

  Future<void> _deleteEmployee(Employee emp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to delete ${emp.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final supabase = ref.read(supabaseClientProvider);
        await supabase.from('employees').delete().eq('id', emp.id);
        ref.invalidate(employeesListProvider);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee deleted.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showEmployeeForm([Employee? emp]) {
    showDialog(
      context: context,
      builder: (ctx) => EmployeeFormDialog(employee: emp),
    ).then((value) {
      if (value == true) {
        ref.invalidate(employeesListProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesListProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEmployeeForm(),
          )
        ],
      ),
      body: Stack(
        children: [
          employeesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (employees) {
              if (employees.isEmpty) {
                return const Center(child: Text('No employees found. Click + to add.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: employees.length,
                itemBuilder: (context, index) {
                  final emp = employees[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: emp.isActive ? Colors.green.shade100 : Colors.red.shade100,
                        child: Text(emp.name[0].toUpperCase(), style: TextStyle(color: emp.isActive ? Colors.green.shade900 : Colors.red.shade900)),
                      ),
                      title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${emp.roleName ?? "No Role"} | PIN: ${emp.pin}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEmployeeForm(emp)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteEmployee(emp)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEmployeeForm(),
        icon: const Icon(Icons.person_add),
        label: const Text("Add Employee"),
      ),
    );
  }
}

class EmployeeFormDialog extends ConsumerStatefulWidget {
  final Employee? employee;
  const EmployeeFormDialog({super.key, this.employee});

  @override
  ConsumerState<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends ConsumerState<EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  
  String? _selectedRoleId;
  bool _isActive = true;
  bool _isLoading = false;
  List<Map<String, dynamic>> _roles = [];

  @override
  void initState() {
    super.initState();
    if (widget.employee != null) {
      _nameController.text = widget.employee!.name;
      _mobileController.text = widget.employee!.mobile ?? '';
      _usernameController.text = widget.employee!.username;
      _pinController.text = widget.employee!.pin;
      _selectedRoleId = widget.employee!.roleId;
      _isActive = widget.employee!.isActive;
    }
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final res = await supabase.from('roles').select();
      final list = List<Map<String, dynamic>>.from(res);
      setState(() {
        _roles = list;
        if ((_selectedRoleId == null || !_roles.any((r) => r['id'].toString() == _selectedRoleId)) && _roles.isNotEmpty) {
          _selectedRoleId = _roles.first['id'].toString();
        }
      });
    } catch (e) {
      print('Error fetching roles: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final supabase = ref.read(supabaseClientProvider);
    final data = {
      'name': _nameController.text,
      'mobile': _mobileController.text,
      'username': _usernameController.text,
      'pin': _pinController.text,
      'role_id': _selectedRoleId,
      'is_active': _isActive,
    };

    try {
      if (widget.employee != null) {
        await supabase.from('employees').update(data).eq('id', widget.employee!.id);
      } else {
        await supabase.from('employees').insert(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.employee == null ? 'Add Employee' : 'Edit Employee'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(labelText: 'Mobile Number'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(labelText: 'PIN / Password'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _roles.any((r) => r['id'].toString() == _selectedRoleId)
                    ? _selectedRoleId
                    : (_roles.isNotEmpty ? _roles.first['id'].toString() : null),
                decoration: const InputDecoration(labelText: 'Role'),
                items: _roles.map((r) => DropdownMenuItem<String>(value: r['id'].toString(), child: Text(r['name'].toString()))).toList(),
                onChanged: (val) => setState(() => _selectedRoleId = val),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active Account'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading ? const CircularProgressIndicator() : const Text('SAVE'),
        ),
      ],
    );
  }
}
