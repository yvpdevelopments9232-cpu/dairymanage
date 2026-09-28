// ==============================================================================
// DAIRY MANAGEMENT SOFTWARE - FLUTTER (DART) MODELS
// ==============================================================================
// These models are designed to map directly to the Supabase database schema.
// You can use these alongside the `supabase_flutter` package.

class AppSettings {
  final String id;
  final String dairyName;
  final String? logoUrl;
  final String? address;
  final String? mobile;
  final String? email;
  final String? gstNumber;
  final String? licenseNumber;

  AppSettings({
    required this.id, required this.dairyName, this.logoUrl, this.address,
    this.mobile, this.email, this.gstNumber, this.licenseNumber,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    id: json['id'],
    dairyName: json['dairy_name'],
    logoUrl: json['logo_url'],
    address: json['address'],
    mobile: json['mobile'],
    email: json['email'],
    gstNumber: json['gst_number'],
    licenseNumber: json['license_number'],
  );
}

bool _parseBool(dynamic val, [bool def = true]) {
  if (val == null) return def;
  if (val is bool) return val;
  if (val is num) return val != 0;
  if (val is String) return val == '1' || val.toLowerCase() == 'true';
  return def;
}

class Farmer {
  final String id;
  final int? farmerNo;
  final String name;
  final String? mobile;
  final String? address;
  final String? village;
  final Map<String, dynamic>? bankDetails;
  final double openingBalance;
  final double currentBalance;
  final bool status;
  final String? notes;

  Farmer({
    required this.id, this.farmerNo, required this.name, this.mobile, this.address, this.village,
    this.bankDetails, this.openingBalance = 0, this.currentBalance = 0, this.status = true, this.notes,
  });

  factory Farmer.fromJson(Map<String, dynamic> json) => Farmer(
    id: json['id'],
    farmerNo: json['farmer_no'],
    name: json['name'],
    mobile: json['mobile'],
    address: json['address'],
    village: json['village'],
    bankDetails: json['bank_details'],
    openingBalance: (json['opening_balance'] ?? 0).toDouble(),
    currentBalance: (json['current_balance'] ?? 0).toDouble(),
    status: _parseBool(json['status']),
    notes: json['notes'],
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'mobile': mobile,
    'address': address,
    'village': village,
    'bank_details': bankDetails,
    'opening_balance': openingBalance,
    'status': status,
    'notes': notes,
  };
}

class Animal {
  final String id;
  final String farmerId;
  final String animalType;
  final String? breed;
  final String? name;
  final int? age;
  final double? milkCapacity;
  final bool status;

  Animal({
    required this.id, required this.farmerId, required this.animalType,
    this.breed, this.name, this.age, this.milkCapacity, this.status = true,
  });

  factory Animal.fromJson(Map<String, dynamic> json) => Animal(
    id: json['id'],
    farmerId: json['farmer_id'],
    animalType: json['animal_type'],
    breed: json['breed'],
    name: json['name'],
    age: json['age'],
    milkCapacity: json['milk_capacity'] != null ? (json['milk_capacity']).toDouble() : null,
    status: _parseBool(json['status']),
  );

  Map<String, dynamic> toJson() => {
    'farmer_id': farmerId,
    'animal_type': animalType,
    'breed': breed,
    'name': name,
    'age': age,
    'milk_capacity': milkCapacity,
    'status': status,
  };
}

class MilkCollection {
  final String id;
  final String collectionDate;
  final String collectionTime;
  final String? shift;
  final String farmerId;
  final String? animalId;
  final String milkType;
  final double quantity;
  final double fat;
  final double snf;
  final double rate;
  final double totalAmount;
  final String paymentStatus;
  final String? remarks;
  
  // Extra fields for UI display
  final String? farmerName;
  final int? farmerNo;

  MilkCollection({
    required this.id, required this.collectionDate, required this.collectionTime, this.shift,
    required this.farmerId, this.animalId, required this.milkType, required this.quantity,
    required this.fat, required this.snf, required this.rate, required this.totalAmount,
    this.paymentStatus = 'Pending', this.remarks, this.farmerName, this.farmerNo,
  });

  factory MilkCollection.fromJson(Map<String, dynamic> json) {
    final farmersData = json['farmers'] as Map<String, dynamic>?;
    return MilkCollection(
      id: json['id']?.toString() ?? '',
      collectionDate: (json['collection_date'] ?? json['collectionDate'] ?? '').toString(),
      collectionTime: (json['collection_time'] ?? json['collectionTime'] ?? '').toString(),
      shift: (json['shift'] ?? 'Morning').toString(),
      farmerId: (json['farmer_id'] ?? json['farmerId'] ?? '').toString(),
      animalId: (json['animal_id'] ?? json['animalId'])?.toString(),
      milkType: (json['milk_type'] ?? json['milkType'] ?? 'Cow Milk').toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      snf: (json['snf'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: (json['payment_status'] ?? 'Pending').toString(),
      remarks: json['remarks']?.toString(),
      farmerName: farmersData?['name']?.toString(),
      farmerNo: (farmersData?['farmer_no'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'collection_date': collectionDate,
    'collection_time': collectionTime,
    'shift': shift,
    'farmer_id': farmerId,
    'animal_id': animalId,
    'milk_type': milkType,
    'quantity': quantity,
    'fat': fat,
    'snf': snf,
    'rate': rate,
    'payment_status': paymentStatus,
    'remarks': remarks,
  };
}

class Customer {
  final String id;
  final String name;
  final String? mobile;
  final String? address;
  final String customerType;
  final double openingBalance;
  final double currentBalance;
  final double creditLimit;
  final bool status;

  Customer({
    required this.id, required this.name, this.mobile, this.address, required this.customerType,
    this.openingBalance = 0, this.currentBalance = 0, this.creditLimit = 0, this.status = true,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'],
    name: json['name'],
    mobile: json['mobile'],
    address: json['address'],
    customerType: json['customer_type'],
    openingBalance: (json['opening_balance'] ?? 0).toDouble(),
    currentBalance: (json['current_balance'] ?? 0).toDouble(),
    creditLimit: (json['credit_limit'] ?? 0).toDouble(),
    status: _parseBool(json['status']),
  );
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'mobile': mobile,
    'address': address,
    'customer_type': customerType,
    'opening_balance': openingBalance,
    'credit_limit': creditLimit,
    'status': status,
  };
}

class Product {
  final String id;
  final String name;
  final String? category;
  final String unit;
  final double purchaseRate;
  final double sellingRate;
  final double currentStock;
  final double minStock;
  final double taxPercent;
  final bool status;

  Product({
    required this.id, required this.name, this.category, required this.unit,
    this.purchaseRate = 0, this.sellingRate = 0, this.currentStock = 0, this.minStock = 0, this.taxPercent = 0,
    this.status = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'],
    name: json['name'] ?? 'Unknown',
    category: json['category'],
    unit: json['unit'] ?? 'Litres',
    purchaseRate: (json['purchase_rate'] ?? 0).toDouble(),
    sellingRate: (json['selling_rate'] ?? 0).toDouble(),
    currentStock: (json['current_stock'] ?? 0).toDouble(),
    minStock: (json['min_stock'] ?? 0).toDouble(),
    taxPercent: (json['tax_percent'] ?? 0).toDouble(),
    status: _parseBool(json['status']),
  );
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'unit': unit,
    'purchase_rate': purchaseRate,
    'selling_rate': sellingRate,
    'min_stock': minStock,
    'tax_percent': taxPercent,
    'status': status,
  };
}

class Sale {
  final String id;
  final String invoiceNo;
  final String saleDate;
  final String? customerId;
  final String? farmerId;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double grandTotal;
  final double paidAmount;
  final double balance;
  final String paymentMode;
  
  final String? customerName;
  final String? farmerName;

  Sale({
    required this.id, required this.invoiceNo, required this.saleDate, this.customerId, this.farmerId,
    this.subtotal = 0, this.discount = 0, this.taxAmount = 0, this.grandTotal = 0, this.paidAmount = 0,
    this.balance = 0, required this.paymentMode, this.customerName, this.farmerName,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    final customerData = json['customers'] as Map<String, dynamic>?;
    final farmerData = json['farmers'] as Map<String, dynamic>?;
    return Sale(
      id: json['id'],
      invoiceNo: json['invoice_no'],
      saleDate: json['sale_date'],
      customerId: json['customer_id'],
      farmerId: json['farmer_id'],
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      taxAmount: (json['tax_amount'] ?? 0).toDouble(),
      grandTotal: (json['grand_total'] ?? 0).toDouble(),
      paidAmount: (json['paid_amount'] ?? 0).toDouble(),
      balance: (json['balance'] ?? 0).toDouble(),
      paymentMode: json['payment_mode'],
      customerName: customerData?['name'],
      farmerName: farmerData?['name'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'invoice_no': invoiceNo,
    'sale_date': saleDate,
    'customer_id': customerId,
    'subtotal': subtotal,
    'discount': discount,
    'tax_amount': taxAmount,
    'paid_amount': paidAmount,
    'payment_mode': paymentMode,
  };
}

class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final double quantity;
  final String? unit;
  final double rate;
  final double totalAmount;

  SaleItem({
    required this.id, required this.saleId, required this.productId,
    required this.quantity, this.unit, required this.rate, this.totalAmount = 0,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
    id: json['id'],
    saleId: json['sale_id'],
    productId: json['product_id'],
    quantity: (json['quantity'] ?? 0).toDouble(),
    unit: json['unit'],
    rate: (json['rate'] ?? 0).toDouble(),
    totalAmount: (json['total_amount'] ?? 0).toDouble(),
  );
  
  Map<String, dynamic> toJson() => {
    'sale_id': saleId,
    'product_id': productId,
    'quantity': quantity,
    'unit': unit,
    'rate': rate,
  };
}


class Expense {
  final String id;
  final String expenseDate;
  final String category;
  final String? description;
  final double amount;
  final String paymentMode;
  final String? remarks;

  Expense({
    required this.id, required this.expenseDate, required this.category,
    this.description, required this.amount, required this.paymentMode, this.remarks,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'],
    expenseDate: json['expense_date'],
    category: json['category'],
    description: json['description'],
    amount: (json['amount'] ?? 0).toDouble(),
    paymentMode: json['payment_mode'],
    remarks: json['remarks'],
  );
  
  Map<String, dynamic> toJson() => {
    'expense_date': expenseDate,
    'category': category,
    'description': description,
    'amount': amount,
    'payment_mode': paymentMode,
    'remarks': remarks,
  };
}

class Payment {
  final String id;
  final String paymentDate;
  final String partyType;
  final String? farmerId;
  final String? customerId;
  final String? supplierId;
  final String paymentType; // 'In' or 'Out'
  final double amount;
  final String paymentMode;
  final String? referenceNo;
  final String? remarks;
  
  // Extra fields for UI mapping
  final String? partyName;

  Payment({
    required this.id, required this.paymentDate, required this.partyType,
    this.farmerId, this.customerId, this.supplierId,
    required this.paymentType, required this.amount, required this.paymentMode,
    this.referenceNo, this.remarks, this.partyName,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    String? pName;
    if (json['party_type'] == 'Farmer' && json['farmers'] != null) {
      pName = json['farmers']['name'];
    } else if (json['party_type'] == 'Customer' && json['customers'] != null) {
      pName = json['customers']['name'];
    } else if (json['party_type'] == 'Supplier' && json['suppliers'] != null) {
      pName = json['suppliers']['name'];
    }

    return Payment(
      id: json['id'],
      paymentDate: json['payment_date'],
      partyType: json['party_type'],
      farmerId: json['farmer_id'],
      customerId: json['customer_id'],
      supplierId: json['supplier_id'],
      paymentType: json['payment_type'],
      amount: (json['amount'] ?? 0).toDouble(),
      paymentMode: json['payment_mode'] ?? 'Cash',
      referenceNo: json['reference_no'],
      remarks: json['remarks'],
      partyName: pName,
    );
  }
}

class Supplier {
  final String id;
  final String name;
  final String? mobile;
  final String? address;
  final String? productType;
  final double openingBalance;
  final double currentBalance;
  final String? paymentTerms;
  final bool status;

  Supplier({
    required this.id, required this.name, this.mobile, this.address, this.productType,
    this.openingBalance = 0, this.currentBalance = 0, this.paymentTerms, this.status = true,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: json['id'],
    name: json['name'],
    mobile: json['mobile'],
    address: json['address'],
    productType: json['product_type'],
    openingBalance: (json['opening_balance'] ?? 0).toDouble(),
    currentBalance: (json['current_balance'] ?? 0).toDouble(),
    paymentTerms: json['payment_terms'],
    status: _parseBool(json['status']),
  );
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'mobile': mobile,
    'address': address,
    'product_type': productType,
    'opening_balance': openingBalance,
    'payment_terms': paymentTerms,
    'status': status,
  };
}

class Purchase {
  final String id;
  final String invoiceNo;
  final String purchaseDate;
  final String supplierId;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double grandTotal;
  final double paidAmount;
  final double balance;
  final String? vehicleNo;
  
  // Extra UI fields
  final String? supplierName;

  Purchase({
    required this.id, required this.invoiceNo, required this.purchaseDate, required this.supplierId,
    this.subtotal = 0, this.discount = 0, this.taxAmount = 0, this.grandTotal = 0, this.paidAmount = 0,
    this.balance = 0, this.vehicleNo, this.supplierName,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    final supplierData = json['suppliers'] as Map<String, dynamic>?;
    return Purchase(
      id: json['id'],
      invoiceNo: json['invoice_no'],
      purchaseDate: json['purchase_date'],
      supplierId: json['supplier_id'],
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      taxAmount: (json['tax_amount'] ?? 0).toDouble(),
      grandTotal: (json['grand_total'] ?? 0).toDouble(),
      paidAmount: (json['paid_amount'] ?? 0).toDouble(),
      balance: (json['balance'] ?? 0).toDouble(),
      vehicleNo: json['vehicle_no'],
      supplierName: supplierData?['name'],
    );
  }
}

class StockTransaction {
  final String id;
  final String transactionDate;
  final String productId;
  final String transType;
  final double quantity;
  final String? referenceId;
  final String? referenceType;
  
  final String? productName;
  final String? partyName;

  StockTransaction({
    required this.id, required this.transactionDate, required this.productId,
    required this.transType, required this.quantity, this.referenceId, this.referenceType,
    this.productName,
    this.partyName,
  });

  factory StockTransaction.fromJson(Map<String, dynamic> json) {
    return StockTransaction(
      id: json['id']?.toString() ?? '',
      transactionDate: json['transaction_date']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      transType: json['trans_type']?.toString() ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      referenceId: json['reference_id']?.toString(),
      referenceType: json['reference_type']?.toString(),
      productName: json['products']?['name'] ?? json['_p_name'] ?? json['product_name'],
      partyName: json['party_name'] ?? json['_party_name'],
    );
  }
}


class Staff {
  final String id;
  final String name;
  final String? phone;
  final String? role;
  final double salaryAmount;
  final String salaryType;
  final double balance;
  final bool isActive;

  Staff({required this.id, required this.name, this.phone, this.role, required this.salaryAmount, required this.salaryType, required this.balance, required this.isActive});

  factory Staff.fromJson(Map<String, dynamic> json) => Staff(
    id: json['id'],
    name: json['name'],
    phone: json['phone'],
    role: json['role'],
    salaryAmount: (json['salary_amount'] ?? 0).toDouble(),
    salaryType: json['salary_type'] ?? 'Monthly',
    balance: (json['balance'] ?? 0).toDouble(),
    isActive: _parseBool(json['is_active']),
  );
}

class StaffTransaction {
  final String id;
  final String staffId;
  final String transactionDate;
  final String type;
  final double amount;
  final String? remarks;

  StaffTransaction({required this.id, required this.staffId, required this.transactionDate, required this.type, required this.amount, this.remarks});

  factory StaffTransaction.fromJson(Map<String, dynamic> json) => StaffTransaction(
    id: json['id'],
    staffId: json['staff_id'],
    transactionDate: json['transaction_date'],
    type: json['type'],
    amount: (json['amount'] ?? 0).toDouble(),
    remarks: json['remarks'],
  );
}

class StaffAttendance {
  final String id;
  final String staffId;
  final String attendanceDate;
  final String status;

  StaffAttendance({required this.id, required this.staffId, required this.attendanceDate, required this.status});

  factory StaffAttendance.fromJson(Map<String, dynamic> json) => StaffAttendance(
    id: json['id'],
    staffId: json['staff_id'],
    attendanceDate: json['attendance_date'],
    status: json['status'],
  );
}

// ==============================================================================
// MAIN DAIRY MODULE MODELS
// ==============================================================================

class MainDairy {
  final String id;
  final int? dairyNo;
  final String name;
  final String? contactPerson;
  final String? mobile;
  final String? email;
  final String? address;
  final String? village;
  final String? animalType;
  final double openingBalance;
  final double currentBalance;
  final bool status;
  final String? notes;

  MainDairy({
    required this.id,
    this.dairyNo,
    required this.name,
    this.contactPerson,
    this.mobile,
    this.email,
    this.address,
    this.village,
    this.animalType,
    this.openingBalance = 0,
    this.currentBalance = 0,
    this.status = true,
    this.notes,
  });

  factory MainDairy.fromJson(Map<String, dynamic> json) {
    String? noteVillage;
    String? noteAnimal;
    if (json['notes'] != null && json['notes'].toString().contains(';')) {
      final parts = json['notes'].toString().split(';');
      for (final p in parts) {
        if (p.startsWith('village:')) noteVillage = p.substring('village:'.length);
        if (p.startsWith('animal:')) noteAnimal = p.substring('animal:'.length);
      }
    }

    return MainDairy(
      id: json['id'],
      dairyNo: json['dairy_no'],
      name: json['name'],
      contactPerson: json['contact_person'],
      mobile: json['mobile'],
      email: json['email'],
      address: json['address'],
      village: json['village'] ?? noteVillage,
      animalType: json['animal_type'] ?? noteAnimal ?? 'Cow',
      openingBalance: (json['opening_balance'] ?? 0).toDouble(),
      currentBalance: (json['current_balance'] ?? 0).toDouble(),
      status: _parseBool(json['status']),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() => {
    if (dairyNo != null) 'dairy_no': dairyNo,
    'name': name,
    'contact_person': contactPerson,
    'mobile': mobile,
    'email': email,
    'address': address,
    if (village != null) 'village': village,
    if (animalType != null) 'animal_type': animalType,
    'opening_balance': openingBalance,
    'status': status,
    'notes': notes,
  };
}

class MainDairyRateConfig {
  final String id;
  final String animalType;
  final String rateType; // 'Increase' or 'Decrease'
  final double baseFat;
  final double baseSnf;
  final double baseRate;
  final double fatRate;
  final double snfRate;
  final double fatPoint;
  final double snfPoint;
  final double fatRangeFrom;
  final double fatRangeTo;
  final double snfRangeFrom;
  final double snfRangeTo;
  final String effectiveDate;
  final bool isActive;

  MainDairyRateConfig({
    required this.id,
    required this.animalType,
    this.rateType = 'Increase',
    required this.baseFat,
    required this.baseSnf,
    required this.baseRate,
    this.fatRate = 0.0,
    this.snfRate = 0.0,
    this.fatPoint = 0.1,
    this.snfPoint = 0.1,
    this.fatRangeFrom = 0.0,
    this.fatRangeTo = 15.0,
    this.snfRangeFrom = 0.0,
    this.snfRangeTo = 15.0,
    required this.effectiveDate,
    this.isActive = true,
  });

  factory MainDairyRateConfig.fromJson(Map<String, dynamic> json) => MainDairyRateConfig(
    id: json['id'],
    animalType: json['animal_type'],
    rateType: json['rate_type'] ?? 'Increase',
    baseFat: (json['base_fat'] ?? 0).toDouble(),
    baseSnf: (json['base_snf'] ?? 0).toDouble(),
    baseRate: (json['base_rate'] ?? 0).toDouble(),
    fatRate: (json['fat_rate'] ?? 0).toDouble(),
    snfRate: (json['snf_rate'] ?? 0).toDouble(),
    fatPoint: (json['fat_point'] ?? 0.1).toDouble(),
    snfPoint: (json['snf_point'] ?? 0.1).toDouble(),
    fatRangeFrom: (json['fat_range_from'] ?? 0).toDouble(),
    fatRangeTo: (json['fat_range_to'] ?? 15.0).toDouble(),
    snfRangeFrom: (json['snf_range_from'] ?? 0).toDouble(),
    snfRangeTo: (json['snf_range_to'] ?? 15.0).toDouble(),
    effectiveDate: json['effective_date'] ?? '',
    isActive: _parseBool(json['is_active']),
  );
}

class MainDairyCollection {
  final String id;
  final String mainDairyId;
  final String collectionDate;
  final String shift;
  final String milkType;
  final double quantity;
  final double fat;
  final double snf;
  final double rate;
  final double totalAmount;
  final String paymentStatus;
  final String? remarks;
  final String? dairyName;
  final int? dairyNo;

  MainDairyCollection({
    required this.id,
    required this.mainDairyId,
    required this.collectionDate,
    required this.shift,
    required this.milkType,
    required this.quantity,
    required this.fat,
    required this.snf,
    required this.rate,
    required this.totalAmount,
    this.paymentStatus = 'Pending',
    this.remarks,
    this.dairyName,
    this.dairyNo,
  });

  factory MainDairyCollection.fromJson(Map<String, dynamic> json) => MainDairyCollection(
    id: json['id']?.toString() ?? '',
    mainDairyId: (json['main_dairy_id'] ?? json['mainDairyId'] ?? '').toString(),
    collectionDate: (json['collection_date'] ?? json['collectionDate'] ?? '').toString(),
    shift: (json['shift'] ?? 'Morning').toString(),
    milkType: (json['milk_type'] ?? json['milkType'] ?? 'Cow Milk').toString(),
    quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
    fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
    snf: (json['snf'] as num?)?.toDouble() ?? 0.0,
    rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
    totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    paymentStatus: (json['payment_status'] ?? 'Pending').toString(),
    remarks: json['remarks']?.toString(),
    dairyName: json['main_dairies']?['name']?.toString(),
    dairyNo: (json['main_dairies']?['dairy_no'] as num?)?.toInt(),
  );
}

class MainDairyPayment {
  final String id;
  final String mainDairyId;
  final String paymentDate;
  final double amount;
  final String paymentMode;
  final String? referenceNo;
  final String? remarks;
  final String? dairyName;

  MainDairyPayment({
    required this.id,
    required this.mainDairyId,
    required this.paymentDate,
    required this.amount,
    required this.paymentMode,
    this.referenceNo,
    this.remarks,
    this.dairyName,
  });

  factory MainDairyPayment.fromJson(Map<String, dynamic> json) => MainDairyPayment(
    id: json['id'],
    mainDairyId: json['main_dairy_id'],
    paymentDate: json['payment_date'],
    amount: (json['amount'] ?? 0).toDouble(),
    paymentMode: json['payment_mode'] ?? 'Bank Transfer',
    referenceNo: json['reference_no'],
    remarks: json['remarks'],
    dairyName: json['main_dairies']?['name'],
  );
}

class BonusSettings {
  final String id;
  final double cowRate;
  final double buffaloRate;
  final String? updatedAt;

  BonusSettings({
    required this.id,
    required this.cowRate,
    required this.buffaloRate,
    this.updatedAt,
  });

  factory BonusSettings.fromJson(Map<String, dynamic> json) => BonusSettings(
    id: (json['id'] ?? 'default_settings').toString(),
    cowRate: (json['cow_rate'] as num?)?.toDouble() ?? 0.40,
    buffaloRate: (json['buffalo_rate'] as num?)?.toDouble() ?? 0.50,
    updatedAt: json['updated_at']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'cow_rate': cowRate,
    'buffalo_rate': buffaloRate,
    'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
  };
}

class BonusFarmerSummary {
  final String farmerId;
  final String farmerName;
  final String? farmerNo;
  final String? mobile;
  final String? address;
  final String animalType;
  final double cowMilk;
  final double buffaloMilk;
  final double totalMilk;
  final double cowRate;
  final double buffaloRate;
  final double cowBonus;
  final double buffaloBonus;
  final double totalBonus;
  final double paidAmount;
  final double remainingBonus;
  final String status;

  BonusFarmerSummary({
    required this.farmerId,
    required this.farmerName,
    this.farmerNo,
    this.mobile,
    this.address,
    required this.animalType,
    required this.cowMilk,
    required this.buffaloMilk,
    required this.totalMilk,
    required this.cowRate,
    required this.buffaloRate,
    required this.cowBonus,
    required this.buffaloBonus,
    required this.totalBonus,
    required this.paidAmount,
    required this.remainingBonus,
    required this.status,
  });

  double get displayRate {
    if (animalType == 'Cow') return cowRate;
    if (animalType == 'Buffalo') return buffaloRate;
    if (totalMilk > 0) return totalBonus / totalMilk;
    return buffaloRate;
  }
}

class BonusTransaction {
  final String id;
  final String farmerId;
  final String farmerName;
  final String? farmerNo;
  final String animalType;
  final String fromDate;
  final String toDate;
  final double milkQuantity;
  final double bonusRate;
  final double totalBonus;
  final double previousPaid;
  final double paidAmount;
  final double totalPaid;
  final double remainingBonus;
  final String paymentDate;
  final String paymentMode;
  final String? transactionNumber;
  final String? remarks;
  final String? createdAt;

  BonusTransaction({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    this.farmerNo,
    required this.animalType,
    required this.fromDate,
    required this.toDate,
    required this.milkQuantity,
    required this.bonusRate,
    required this.totalBonus,
    required this.previousPaid,
    required this.paidAmount,
    required this.totalPaid,
    required this.remainingBonus,
    required this.paymentDate,
    required this.paymentMode,
    this.transactionNumber,
    this.remarks,
    this.createdAt,
  });

  factory BonusTransaction.fromJson(Map<String, dynamic> json) => BonusTransaction(
    id: json['id'].toString(),
    farmerId: (json['farmer_id'] ?? '').toString(),
    farmerName: (json['farmer_name'] ?? '').toString(),
    farmerNo: json['farmer_no']?.toString(),
    animalType: (json['animal_type'] ?? 'Buffalo').toString(),
    fromDate: (json['from_date'] ?? '').toString(),
    toDate: (json['to_date'] ?? '').toString(),
    milkQuantity: (json['milk_quantity'] as num?)?.toDouble() ?? 0.0,
    bonusRate: (json['bonus_rate'] as num?)?.toDouble() ?? 0.0,
    totalBonus: (json['total_bonus'] as num?)?.toDouble() ?? 0.0,
    previousPaid: (json['previous_paid'] as num?)?.toDouble() ?? 0.0,
    paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
    totalPaid: (json['total_paid'] as num?)?.toDouble() ?? 0.0,
    remainingBonus: (json['remaining_bonus'] as num?)?.toDouble() ?? 0.0,
    paymentDate: (json['payment_date'] ?? '').toString(),
    paymentMode: (json['payment_mode'] ?? 'Cash').toString(),
    transactionNumber: json['transaction_number']?.toString(),
    remarks: json['remarks']?.toString(),
    createdAt: json['created_at']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'farmer_id': farmerId,
    'farmer_name': farmerName,
    'farmer_no': farmerNo,
    'animal_type': animalType,
    'from_date': fromDate,
    'to_date': toDate,
    'milk_quantity': milkQuantity,
    'bonus_rate': bonusRate,
    'total_bonus': totalBonus,
    'previous_paid': previousPaid,
    'paid_amount': paidAmount,
    'total_paid': totalPaid,
    'remaining_bonus': remainingBonus,
    'payment_date': paymentDate,
    'payment_mode': paymentMode,
    'transaction_number': transactionNumber,
    'remarks': remarks,
    'created_at': createdAt ?? DateTime.now().toIso8601String(),
  };
}

