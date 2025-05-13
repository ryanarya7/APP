import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'odoo_service.dart';

class EditHeaderDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final OdooService odooService;

  const EditHeaderDialog({
    super.key,
    required this.initialData,
    required this.odooService,
  });

  @override
  _EditHeaderDialogState createState() => _EditHeaderDialogState();
}

class _EditHeaderDialogState extends State<EditHeaderDialog> {
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> invoiceAddresses = [];
  List<Map<String, dynamic>> deliveryAddresses = [];
  List<Map<String, dynamic>> salespersons = [];
  List<Map<String, dynamic>> paymentTerms = [];
  List<Map<String, dynamic>> warehouses = [];

  Map<String, dynamic>? selectedCustomer;
  Map<String, dynamic>? selectedInvoiceAddress;
  Map<String, dynamic>? selectedDeliveryAddress;
  Map<String, dynamic>? selectedSalesperson;
  Map<String, dynamic>? selectedPaymentTerm;
  Map<String, dynamic>? selectedWarehouse;
  TextEditingController vatController = TextEditingController();
  TextEditingController notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final fetchedCustomers = await widget.odooService.fetchCustomers();
      final fetchedSalespersons = await widget.odooService.fetchSalespersons();
      final fetchedPaymentTerms = await widget.odooService.fetchPaymentTerms();
      final fetchedWarehouses = await widget.odooService.fetchWarehouses();

      setState(() {
        customers = fetchedCustomers.cast<Map<String, dynamic>>();
        print('Jumlah customer: ${customers.length}');
        salespersons = fetchedSalespersons.cast<Map<String, dynamic>>();
        paymentTerms = fetchedPaymentTerms.cast<Map<String, dynamic>>();
        warehouses = fetchedWarehouses.cast<Map<String, dynamic>>();

        // Cari item berdasarkan ID yang valid
        final partnerId = safeExtractFirst(widget.initialData['partner_id']);
        selectedCustomer = customers.firstWhere(
          (c) => c['id'] == partnerId,
          orElse: () => {}, // ✅ Kembalikan Map kosong
        );

        final userMemberId =
            safeExtractFirst(widget.initialData['user_member_id']);
        selectedSalesperson = salespersons.firstWhere(
          (s) => s['id'] == userMemberId,
          orElse: () => {},
        );

        final paymentTermId =
            safeExtractFirst(widget.initialData['payment_term_id']);
        selectedPaymentTerm = paymentTerms.firstWhere(
          (p) => p['id'] == paymentTermId,
          orElse: () => {},
        );

        final warehouseId =
            safeExtractFirst(widget.initialData['warehouse_id']);
        selectedWarehouse = warehouses.firstWhere(
          (w) => w['id'] == warehouseId,
          orElse: () => {},
        );

        // Pastikan notesController aman
        notesController.text = widget.initialData['notes']?.toString() ?? '';
        vatController.text = _getValidVat(selectedCustomer?['vat']);
      });

      await _fetchInitialAddresses();
      if (selectedCustomer != null) {
        await _loadAddresses(selectedCustomer!['id'], isInitialLoad: true);
      }
    } catch (e, stackTrace) {
      // Log error untuk debugging
      print('Error loading data: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  dynamic safeExtractFirst(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return value.first;
    }
    return null; // Jika bukan List atau kosong, kembalikan null
  }

  Future<void> _fetchInitialAddresses() async {
    try {
      final customerId = safeExtractFirst(widget.initialData['partner_id']);
      if (customerId is! int) {
        throw Exception('Customer ID is missing or invalid');
      }

      final fetchedAddresses =
          await widget.odooService.fetchCustomerAddresses(customerId);
      if (!mounted) return;

      setState(() {
        invoiceAddresses = [
          {'id': null, 'name': widget.initialData['partner_id']?[1] ?? ''},
          ...fetchedAddresses.where((a) => a['type'] == 'invoice').toList(),
        ];
        deliveryAddresses = [
          {'id': null, 'name': widget.initialData['partner_id']?[1] ?? ''},
          ...fetchedAddresses.where((a) => a['type'] == 'delivery').toList(),
        ];

        final partnerInvoiceId =
            safeExtractFirst(widget.initialData['partner_invoice_id']);
        final partnerShippingId =
            safeExtractFirst(widget.initialData['partner_shipping_id']);

        selectedInvoiceAddress = partnerInvoiceId != null
            ? invoiceAddresses.firstWhere((a) => a['id'] == partnerInvoiceId,
                orElse: () => invoiceAddresses.first)
            : invoiceAddresses.first;

        selectedDeliveryAddress = partnerShippingId != null
            ? deliveryAddresses.firstWhere((a) => a['id'] == partnerShippingId,
                orElse: () => deliveryAddresses.first)
            : deliveryAddresses.first;

        _updatevat(selectedInvoiceAddress);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching initial addresses: $e')),
      );
    }
  }

  void _updatevat(Map<String, dynamic>? invoiceAddress) {
    if (invoiceAddress == null) {
      setState(() {
        vatController.text = '0000000000000000';
      });
      _showVatWarning();
      return;
    }

    final invoiceAddressName = invoiceAddress['name'];

    // Jika alamat invoice sama dengan customer, gunakan VAT dari selectedCustomer
    if (invoiceAddress['id'] == selectedCustomer?['id']) {
      setState(() {
        vatController.text = _getValidVat(selectedCustomer?['vat']);
      });
    } else {
      // Jika alamat berbeda, cari data customer berdasarkan invoice address
      final matchedCustomer = customers.firstWhere(
        (customer) => customer['name'] == invoiceAddressName,
        orElse: () =>
            {'vat': '0000000000000000'}, // Default VAT jika tidak ditemukan
      );

      setState(() {
        vatController.text = _getValidVat(matchedCustomer['vat']);
      });
    }

    if (vatController.text == '0000000000000000') {
      _showVatWarning();
    }
  }

  String _getValidVat(dynamic vat) {
    if (vat == null || vat == false || (vat is String && vat.isEmpty)) {
      return '0000000000000000'; // Set default jika VAT kosong
    }
    return vat.toString();
  }

  void _showVatWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Warning: VAT is missing or invalid for the selected invoice address.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _loadAddresses(int customerId,
      {bool isInitialLoad = false}) async {
    try {
      final fetchedAddresses =
          await widget.odooService.fetchCustomerAddresses(customerId);

      if (!mounted) return;

      setState(() {
        invoiceAddresses = [
          {'id': null, 'name': selectedCustomer?['name'] ?? ''},
          ...fetchedAddresses
              .where((a) => a['type'] == 'invoice' || a['type'] == null)
              .toList(),
        ];

        deliveryAddresses = [
          {'id': null, 'name': selectedCustomer?['name'] ?? ''},
          ...fetchedAddresses
              .where((a) => a['type'] == 'delivery' || a['type'] == null)
              .toList(),
        ];

        if (!isInitialLoad) {
          selectedInvoiceAddress = invoiceAddresses.firstWhere(
            (a) => a['type'] == 'invoice',
            orElse: () => invoiceAddresses.first,
          );

          selectedDeliveryAddress = deliveryAddresses.firstWhere(
            (a) => a['type'] == 'delivery',
            orElse: () => deliveryAddresses.first,
          );
        }
        _updatevat(selectedInvoiceAddress);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading addresses: $e')),
      );
    }
  }

  Future<void> _saveHeader() async {
    final headerData = {
      'partner_id': selectedCustomer?['id'],
      'partner_invoice_id':
          selectedInvoiceAddress?['id'] ?? selectedCustomer?['id'],
      'partner_shipping_id':
          selectedDeliveryAddress?['id'] ?? selectedCustomer?['id'],
      'user_member_id': selectedSalesperson?['id'],
      'payment_term_id': selectedPaymentTerm?['id'],
      'warehouse_id': selectedWarehouse?['id'],
      'notes': notesController.text,
    };
    final vatValue = vatController.text.trim();
    if (vatValue.isEmpty ||
        vatValue.length != 16 ||
        vatValue == '0000000000000000') {
      headerData['vat'] = '0000000000000000';
    } else {
      headerData['vat'] = vatValue;
    }
    if (headerData['partner_id'] == null ||
        headerData['user_member_id'] == null ||
        headerData['payment_term_id'] == null ||
        headerData['warehouse_id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }
    try {
      await widget.odooService
          .updateQuotationHeader(widget.initialData['id'], headerData);
      Navigator.of(context).pop(headerData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating header: $e')),
      );
    }
  }

  Widget _buildDropdown({
    required String label,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic>? selectedItem,
    required ValueChanged<Map<String, dynamic>?> onChanged,
    bool isReadOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownSearch<Map<String, dynamic>>(
          items: items,
          selectedItem: selectedItem,
          itemAsString: (item) => item['name'] ?? '',
          dropdownBuilder: (context, selectedItem) {
            return Text(
              selectedItem?['name'] ?? '',
              style: const TextStyle(fontSize: 12),
            );
          },
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: const TextFieldProps(
              decoration: InputDecoration(
                labelText: 'Search',
                border: OutlineInputBorder(),
              ),
            ),
            itemBuilder: (context, item, isSelected) {
              return ListTile(
                title: Text(
                  item['name'] ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          ),
          onChanged: isReadOnly ? null : onChanged,
          enabled: !isReadOnly,
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Notes",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: notesController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter notes...',
          ),
          style: const TextStyle(fontSize: 12),
          maxLines: 3, // Allow multiple lines for notes
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Quotation Header',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdown(
              label: "Customer",
              items: customers,
              selectedItem: selectedCustomer,
              onChanged: (value) {
                setState(() {
                  selectedCustomer = value;
                });

                if (value != null) {
                  _loadAddresses(value['id']);
                }
              },
            ),
            const SizedBox(height: 5),
            _buildDropdown(
              label: "Invoice Address",
              items: invoiceAddresses,
              selectedItem: selectedInvoiceAddress,
              onChanged: (value) {
                setState(() {
                  selectedInvoiceAddress = value;
                });

                _updatevat(value);
              },
            ),
            const SizedBox(height: 5),
            _buildDropdown(
              label: "Delivery Address",
              items: deliveryAddresses,
              selectedItem: selectedDeliveryAddress,
              onChanged: (value) =>
                  setState(() => selectedDeliveryAddress = value),
            ),
            const SizedBox(height: 5),
            _buildDropdown(
              label: "Salesperson",
              items: salespersons,
              selectedItem: selectedSalesperson,
              onChanged: (_) {},
              isReadOnly: true,
            ),
            const SizedBox(height: 5),
            _buildDropdown(
              label: "Payment Term",
              items: paymentTerms,
              selectedItem: selectedPaymentTerm,
              onChanged: (value) => setState(() => selectedPaymentTerm = value),
            ),
            const SizedBox(height: 5),
            _buildDropdown(
              label: "Warehouse",
              items: warehouses,
              selectedItem: selectedWarehouse,
              onChanged: (value) => setState(() => selectedWarehouse = value),
            ),
            const SizedBox(height: 5),
            _buildNotesField(),
            const SizedBox(height: 5),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        ElevatedButton(onPressed: _saveHeader, child: const Text('Save')),
      ],
    );
  }
}
