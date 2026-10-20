import 'package:flutter/material.dart';

import 'ledger.dart';

class _DirectoryData {
  const _DirectoryData({
    required this.customers,
    required this.suppliers,
    required this.materials,
  });

  final List<LedgerCustomer> customers;
  final List<LedgerSupplier> suppliers;
  final List<LedgerMaterial> materials;
}

/// Read-only master-data browser for customers, suppliers and materials.
/// Create/edit screens are the next slice; this page proves the lists come
/// from the same Rust `AppState` as the ledger.
class DirectoryPage extends StatefulWidget {
  const DirectoryPage({super.key, required this.gateway});

  final LedgerGateway gateway;

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  final _searchController = TextEditingController();
  late Future<_DirectoryData> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_DirectoryData> _load() async {
    final customers = await widget.gateway.loadCustomers();
    final suppliers = await widget.gateway.loadSuppliers();
    final materials = await widget.gateway.loadMaterials();
    return _DirectoryData(
      customers: customers,
      suppliers: suppliers,
      materials: materials,
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  bool _matches(String value) {
    if (_query.isEmpty) {
      return true;
    }
    return value.toLowerCase().contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('البيانات الأساسية'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_DirectoryData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'تعذّر تحميل البيانات الأساسية.\n${describeError(snapshot.error!)}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final customers = data.customers
              .where((c) => _matches('${c.code} ${c.name} ${c.phone ?? ''}'))
              .toList();
          final suppliers = data.suppliers
              .where((s) => _matches('${s.code} ${s.name} ${s.phone ?? ''}'))
              .toList();
          final materials = data.materials
              .where(
                (m) =>
                    _matches('${m.code} ${m.name} ${m.nameEn} ${m.barcode}'),
              )
              .toList();

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'بحث بالاسم أو الرمز أو الباركود',
                      border: const OutlineInputBorder(),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'مسح البحث',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                    onChanged: (value) {
                      setState(() => _query = value.trim().toLowerCase());
                    },
                  ),
                ),
                TabBar(
                  tabs: [
                    Tab(text: 'العملاء (${customers.length})'),
                    Tab(text: 'الموردون (${suppliers.length})'),
                    Tab(text: 'المواد (${materials.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _CustomerList(customers: customers),
                      _SupplierList(suppliers: suppliers),
                      _MaterialList(materials: materials),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CustomerList extends StatelessWidget {
  const _CustomerList({required this.customers});

  final List<LedgerCustomer> customers;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const _EmptyList(message: 'لا يوجد عملاء مطابقون.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: customers.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final customer = customers[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(customer.code.isEmpty ? '?' : customer.code),
          ),
          title: Text(customer.name),
          subtitle: Text(
            [
              customer.code,
              if (customer.phone != null && customer.phone!.isNotEmpty)
                customer.phone!,
              if (!customer.isActive) 'غير نشط',
            ].join(' • '),
          ),
          trailing: Text(
            '${customer.balance} ${customer.currency}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        );
      },
    );
  }
}

class _SupplierList extends StatelessWidget {
  const _SupplierList({required this.suppliers});

  final List<LedgerSupplier> suppliers;

  @override
  Widget build(BuildContext context) {
    if (suppliers.isEmpty) {
      return const _EmptyList(message: 'لا يوجد موردون مطابقون.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: suppliers.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final supplier = suppliers[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(supplier.code.isEmpty ? '?' : supplier.code),
          ),
          title: Text(supplier.name),
          subtitle: Text(
            [
              supplier.code,
              if (supplier.phone != null && supplier.phone!.isNotEmpty)
                supplier.phone!,
              if (!supplier.isActive) 'غير نشط',
            ].join(' • '),
          ),
          trailing: Text(
            '${supplier.balance} ${supplier.currency}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        );
      },
    );
  }
}

class _MaterialList extends StatelessWidget {
  const _MaterialList({required this.materials});

  final List<LedgerMaterial> materials;

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return const _EmptyList(message: 'لا توجد مواد مطابقة.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: materials.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final material = materials[index];
        return ListTile(
          leading: Icon(
            material.hasExpiry
                ? Icons.event_available_outlined
                : Icons.inventory_2_outlined,
          ),
          title: Text(material.name),
          subtitle: Text(
            [
              material.code,
              if (material.barcode.isNotEmpty) 'باركود: ${material.barcode}',
              'متاح: ${material.totalAvailable}',
              'حد أدنى: ${material.minimumStock}',
            ].join(' • '),
          ),
          trailing: Text(
            material.averageCost,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        );
      },
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48),
          const SizedBox(height: 8),
          Text(message),
        ],
      ),
    );
  }
}
