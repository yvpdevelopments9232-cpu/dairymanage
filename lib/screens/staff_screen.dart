import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/staff_provider.dart';
import '../providers/attendance_provider.dart';
import 'staff_ledger_screen.dart';
import '../widgets/desktop_wrapper.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  String _salaryType = 'Monthly';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _roleCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    
    try {
      await ref.read(staffProvider.notifier).addStaff(
        name: _nameCtrl.text,
        phone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
        role: _roleCtrl.text.isEmpty ? null : _roleCtrl.text,
        salaryAmount: double.parse(_salaryCtrl.text),
        salaryType: _salaryType,
      );
      
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _roleCtrl.clear();
      _salaryCtrl.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff member added successfully')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAttendanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 500,
            constraints: const BoxConstraints(maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final attAsync = ref.watch(attendanceProvider);
                      final staffAsync = ref.watch(staffProvider);
                      
                      final dateStr = attAsync.value?.date ?? DateTime.now().toString().split(' ')[0];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Daily Attendance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              TextButton.icon(
                                icon: const Icon(Icons.calendar_month),
                                label: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.tryParse(dateStr) ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    ref.read(attendanceProvider.notifier).setDate(picked.toString().split(' ')[0]);
                                  }
                                },
                              )
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: (attAsync.isLoading || staffAsync.isLoading)
                                ? const Center(child: CircularProgressIndicator())
                                : Builder(
                                    builder: (context) {
                                      final staffList = staffAsync.value ?? [];
                                      final attendances = attAsync.value?.attendances ?? [];
                                      return ListView.builder(
                        itemCount: staffList.length,
                        itemBuilder: (context, index) {
                          final staff = staffList[index];
                          if (!staff.isActive) return const SizedBox();

                          final currentAtt = attendances.where((a) => a.staffId == staff.id).firstOrNull;
                          final status = currentAtt?.status ?? 'Absent';

                          return ListTile(
                            title: Text(staff.name),
                            subtitle: Text(staff.role ?? 'Staff'),
                            trailing: DropdownButton<String>(
                              value: status,
                              items: ['Present', 'Absent', 'Half-Day'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (val) async {
                                if (val != null) {
                                  try {
                                    await ref.read(attendanceProvider.notifier).markAttendance(staffId: staff.id, status: val);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to update attendance: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          );
                        },
                      );
                                    }
                                  )
                          )
                        ]
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('DONE'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isMobile = false; // Forced desktop layout as per user request

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Flex(
        direction: isMobile ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: isMobile ? 0 : 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add New Staff', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                        const Divider(height: 32),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _roleCtrl,
                          decoration: InputDecoration(labelText: 'Role (e.g., Driver, Milker)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: isMobile ? double.infinity : (MediaQuery.of(context).size.width / 4 - 40),
                              child: TextFormField(
                                controller: _salaryCtrl,
                                decoration: InputDecoration(labelText: 'Base Salary / Wage *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                keyboardType: TextInputType.number,
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                            SizedBox(
                              width: isMobile ? double.infinity : (MediaQuery.of(context).size.width / 4 - 60),
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(labelText: 'Type *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                value: _salaryType,
                                items: ['Monthly', 'Daily'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                onChanged: (v) => setState(() => _salaryType = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _submit,
                            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check_circle),
                            label: Text(_isSaving ? 'SAVING...' : 'REGISTER STAFF', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          Expanded(
            flex: isMobile ? 1 : 2,
            child: Container(
              color: Colors.grey.shade50,
              height: isMobile ? 500 : double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0), 
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Staff Directory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          onPressed: () => _showAttendanceDialog(context),
                          icon: const Icon(Icons.checklist),
                          label: const Text('Mark Attendance'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: staffAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Center(child: Text('Error: $e')),
                      data: (staffList) {
                        if (staffList.isEmpty) return const Center(child: Text('No staff members registered.'));
                        return ListView.builder(
                          itemCount: staffList.length,
                          itemBuilder: (context, index) {
                            final staff = staffList[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: CircleAvatar(backgroundColor: primaryColor.withOpacity(0.1), child: Icon(Icons.person, color: primaryColor)),
                                title: Text(staff.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${staff.role ?? 'No Role'} | ₹${staff.salaryAmount} ${staff.salaryType}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Balance', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    Text('₹${staff.balance.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: staff.balance < 0 ? Colors.red : Colors.green)),
                                  ],
                                ),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DesktopWrapper(child: StaffLedgerScreen(staff: staff)))),
                              ),
                            );
                          },
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
