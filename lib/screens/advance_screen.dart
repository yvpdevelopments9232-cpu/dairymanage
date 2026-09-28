import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/staff_provider.dart';
import '../providers/farmer_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_db.dart';

class AdvanceScreen extends ConsumerStatefulWidget {
  const AdvanceScreen({super.key});

  @override
  ConsumerState<AdvanceScreen> createState() => _AdvanceScreenState();
}

class _AdvanceScreenState extends ConsumerState<AdvanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _searchHistoryCtrl = TextEditingController();
  
  String _personType = 'Farmer'; // Farmer or Staff
  String? _selectedPersonId;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  String _searchQuery = '';
  
  // To handle editing
  String? _editingId;
  bool _isLoadingHistory = false;
  List<Map<String, dynamic>> _recentAdvances = [];
  DateTime? _historyDateFilter;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _remarksCtrl.dispose();
    _searchHistoryCtrl.dispose();
    super.dispose();
  }
  
  Future<void> _fetchHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final supabase = AppDb.client;
      List<Map<String, dynamic>> combined = [];
      
      // Fetch Staff Advances
      final staffAdv = await supabase.from('staff_transactions')
        .select('*, staff(name)')
        .eq('type', 'Advance')
        .order('created_at', ascending: false)
        .limit(20);
        
      for (var s in staffAdv) {
        combined.add({
          'id': s['id'],
          'person_id': s['staff_id'],
          'type': 'Staff',
          'date': s['transaction_date'],
          'name': s['staff']['name'],
          'amount': s['amount'],
          'remarks': s['remarks'] ?? '',
        });
      }
      
      // Fetch Farmer Advances (payments with 'ADVANCE:' in remarks)
      final farmerAdv = await supabase.from('payments')
        .select('*, farmers(name)')
        .like('remarks', '%ADVANCE:%')
        .order('created_at', ascending: false)
        .limit(20);
        
      for (var f in farmerAdv) {
        combined.add({
          'id': f['id'],
          'person_id': f['farmer_id'],
          'type': 'Farmer',
          'date': f['payment_date'],
          'name': f['farmers']?['name'] ?? 'Unknown',
          'amount': f['amount'],
          'remarks': f['remarks'] ?? '',
        });
      }
      
      combined.sort((a, b) => b['date'].compareTo(a['date']));
      
      setState(() {
        _recentAdvances = combined;
      });
    } catch (e) {
      debugPrint("Error fetching advance history: $e");
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitAdvance() async {
    if (!_formKey.currentState!.validate() || _selectedPersonId == null) return;
    setState(() => _isSaving = true);
    
    try {
      final supabase = AppDb.client;
      final amount = double.parse(_amountCtrl.text);
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      final remarksText = _personType == 'Farmer' ? 'ADVANCE: ${_remarksCtrl.text}' : _remarksCtrl.text;

      if (_editingId != null) {
        // UPDATE MODE
        if (_personType == 'Farmer') {
          await supabase.from('payments').update({
            'amount': amount,
            'remarks': remarksText,
            'payment_date': date,
          }).eq('id', _editingId!);
        } else {
          await supabase.from('staff_transactions').update({
            'amount': amount,
            'remarks': remarksText,
            'transaction_date': date,
          }).eq('id', _editingId!);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Advance updated successfully!')));
      } else {
        // INSERT MODE
        if (_personType == 'Farmer') {
          await supabase.from('payments').insert({
            'farmer_id': _selectedPersonId,
            'party_type': 'Farmer',
            'payment_type': 'Out',
            'payment_date': date,
            'amount': amount,
            'payment_mode': 'Cash', // default
            'remarks': remarksText,
          });
        } else {
          await supabase.from('staff_transactions').insert({
            'staff_id': _selectedPersonId,
            'transaction_date': date,
            'type': 'Advance',
            'amount': amount,
            'remarks': remarksText,
          });
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Advance recorded successfully!')));
      }

      // Refresh data
      if (_personType == 'Farmer') ref.invalidate(farmersProvider);
      else ref.invalidate(staffProvider);

      _amountCtrl.clear();
      _remarksCtrl.clear();
      setState(() {
        _selectedPersonId = null;
        _editingId = null;
      });
      _fetchHistory();
      
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  void _editAdvance(Map<String, dynamic> record) {
    setState(() {
      _editingId = record['id'];
      _personType = record['type'];
      _selectedPersonId = record['person_id']; // Fix 1: Properly select the person
      _amountCtrl.text = record['amount'].toString();
      try {
        _selectedDate = DateTime.parse(record['date']); // Fix 2: Load the date
      } catch (e) {
        _selectedDate = DateTime.now();
      }
      
      // Remove 'ADVANCE: ' prefix for Farmer records when editing
      String r = record['remarks'] ?? '';
      if (r.startsWith('ADVANCE: ')) r = r.substring(9);
      _remarksCtrl.text = r;
    });
  }
  
  Future<void> _deleteAdvance(Map<String, dynamic> record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Advance'),
        content: const Text('Are you sure you want to delete this advance?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        final supabase = AppDb.client;
        if (record['type'] == 'Farmer') {
          await supabase.from('payments').delete().eq('id', record['id']);
          ref.invalidate(farmersProvider);
        } else {
          await supabase.from('staff_transactions').delete().eq('id', record['id']);
          ref.invalidate(staffProvider);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Advance deleted')));
        _fetchHistory();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    final farmersAsync = ref.watch(farmersProvider);
    final staffAsync = ref.watch(staffProvider);
    
    final isMobile = false; // Forced desktop layout as per user request

    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Advances', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Flex(
        direction: isMobile ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDE: Form
          Expanded(
            flex: isMobile ? 0 : 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_editingId == null ? 'Record New Advance' : 'Edit Advance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                            if (_editingId != null)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _editingId = null;
                                    _amountCtrl.clear();
                                    _remarksCtrl.clear();
                                  });
                                },
                                child: const Text('Cancel Edit'),
                              )
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('Easily issue advances to farmers or staff.', style: TextStyle(color: Colors.grey)),
                        const Divider(height: 32),
                        
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('To Farmer'),
                                value: 'Farmer',
                                groupValue: _personType,
                                onChanged: _editingId == null ? (v) {
                                  setState(() {
                                    _personType = v!;
                                    _selectedPersonId = null;
                                  });
                                } : null,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('To Staff'),
                                value: 'Staff',
                                groupValue: _personType,
                                onChanged: _editingId == null ? (v) {
                                  setState(() {
                                    _personType = v!;
                                    _selectedPersonId = null;
                                  });
                                } : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        if (_personType == 'Farmer')
                          farmersAsync.when(
                            loading: () => const CircularProgressIndicator(),
                            error: (e, s) => Text('Error: $e'),
                            data: (farmers) {
                              return DropdownButtonFormField<String>(
                                isExpanded: true,
                                decoration: InputDecoration(labelText: 'Select Farmer *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                value: _selectedPersonId,
                                items: farmers.map((f) => DropdownMenuItem(value: f.id, child: Text('${f.name} (Bal: ₹${f.currentBalance.toStringAsFixed(2)})'))).toList(),
                                onChanged: _editingId == null ? (v) => setState(() => _selectedPersonId = v) : null,
                                validator: (v) => v == null ? 'Please select a farmer' : null,
                              );
                            }
                          )
                        else
                          staffAsync.when(
                            loading: () => const CircularProgressIndicator(),
                            error: (e, s) => Text('Error: $e'),
                            data: (staffs) {
                              return DropdownButtonFormField<String>(
                                isExpanded: true,
                                decoration: InputDecoration(labelText: 'Select Staff *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                value: _selectedPersonId,
                                items: staffs.where((s) => s.isActive).map((s) => DropdownMenuItem(value: s.id, child: Text('${s.name} (Bal: ₹${s.balance.toStringAsFixed(2)})'))).toList(),
                                onChanged: _editingId == null ? (v) => setState(() => _selectedPersonId = v) : null,
                                validator: (v) => v == null ? 'Please select staff' : null,
                              );
                            }
                          ),
                          
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _pickDate,
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Date',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    prefixIcon: const Icon(Icons.calendar_today),
                                  ),
                                  child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _amountCtrl,
                          decoration: InputDecoration(
                            labelText: 'Advance Amount (₹) *', 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.currency_rupee),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _remarksCtrl,
                          decoration: InputDecoration(
                            labelText: 'Remarks / Notes', 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.note),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _submitAdvance,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _editingId != null ? Colors.orange : primaryColor, 
                              foregroundColor: Colors.white, 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                            ),
                            icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.payment),
                            label: Text(_isSaving ? 'PROCESSING...' : (_editingId != null ? 'UPDATE ADVANCE' : 'ISSUE ADVANCE'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // RIGHT SIDE: History
          Expanded(
            flex: isMobile ? 1 : 1,
            child: Container(
              color: Colors.grey.shade50,
              height: isMobile ? 500 : double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.all(16.0), child: Text('Advance History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchHistoryCtrl,
                            decoration: InputDecoration(
                              labelText: 'Search History by Name',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _historyDateFilter ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _historyDateFilter = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: _historyDateFilter != null ? Colors.blue : Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                              color: _historyDateFilter != null ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                            ),
                            child: Icon(Icons.calendar_today, color: _historyDateFilter != null ? Colors.blue : Colors.grey.shade700),
                          ),
                        ),
                        if (_historyDateFilter != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red),
                            onPressed: () => setState(() => _historyDateFilter = null),
                          )
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _isLoadingHistory
                        ? const Center(child: CircularProgressIndicator())
                        : Builder(
                            builder: (context) {
                              final filtered = _recentAdvances.where((r) {
                                final name = (r['name'] as String).toLowerCase();
                                final matchesName = name.contains(_searchQuery.toLowerCase());
                                
                                bool matchesDate = true;
                                if (_historyDateFilter != null) {
                                  final filterStr = DateFormat('yyyy-MM-dd').format(_historyDateFilter!);
                                  matchesDate = r['date'] == filterStr;
                                }
                                
                                return matchesName && matchesDate;
                              }).toList();

                              if (filtered.isEmpty) return const Center(child: Text('No advance history found.'));
                              
                              return ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final record = filtered[index];
                                  final isFarmer = record['type'] == 'Farmer';
                                  final color = isFarmer ? Colors.blue : Colors.purple;
                                  
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: color.withOpacity(0.1),
                                      child: Icon(isFarmer ? Icons.agriculture : Icons.badge, color: color),
                                    ),
                                    title: Text('${record['name']} (${record['type']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('${record['date']} | ${record['remarks']}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('₹${double.parse(record['amount'].toString()).toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(width: 8),
                                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editAdvance(record)),
                                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteAdvance(record)),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }
                          )
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
