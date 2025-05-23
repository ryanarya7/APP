import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'odoo_service.dart';

class FormHeaderQuotation extends StatefulWidget {
  final OdooService odooService;

  const FormHeaderQuotation({super.key, required this.odooService});

  @override
  _FormHeaderQuotationState createState() => _FormHeaderQuotationState();
}

class _FormHeaderQuotationState extends State<FormHeaderQuotation> {
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> salespersons = [];
  List<Map<String, dynamic>> paymentTerms = [];
  List<Map<String, dynamic>> warehouses = [];
  List<Map<String, dynamic>> globalAddresses = [];
  List<Map<String, dynamic>> filteredInvoiceAddresses = [];
  List<Map<String, dynamic>> filteredDeliveryAddresses = [];
  String notes = '';

  Map<String, dynamic>? selectedCustomer;
  Map<String, dynamic>? selectedSalesperson;
  Map<String, dynamic>? selectedPaymentTerm;
  Map<String, dynamic>? selectedWarehouse;
  Map<String, dynamic>? selectedInvoiceAddress;
  Map<String, dynamic>? selectedDeliveryAddress;

  String? customervat;
  bool showSalespersonField = false;
  // ignore: unused_field
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    _loadData().then((_) {
      setState(() {
        _isLoading = false;
      });
    });
  }

  Future<void> _loadData() async {
    try {
      final fetchedCustomers =
          await widget.odooService.fetchCustomerz(); // Sudah pakai cache
      final fetchedSalespersons = await widget.odooService.fetchSalespersons();
      final fetchedPaymentTerms = await widget.odooService.fetchPaymentTerms();
      final fetchedWarehouses = await widget.odooService.fetchWarehouses();
      final loggedInUser = await widget.odooService.fetchUser();

      setState(() {
        customers = fetchedCustomers;
        salespersons = fetchedSalespersons;
        paymentTerms = fetchedPaymentTerms;
        warehouses = fetchedWarehouses;
        // Auto-select salesperson & warehouse
        selectedSalesperson = salespersons.firstWhere(
          (s) => s['name'] == loggedInUser['name'],
          orElse: () => salespersons.isNotEmpty ? salespersons.first : {},
        );
        selectedWarehouse = warehouses.firstWhere(
          (w) => w['id'] == loggedInUser['warehouse_id'],
          orElse: () => warehouses.isNotEmpty ? warehouses.first : {},
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  Future<void> _loadChildAddresses(int customerId) async {
    try {
      final fetchedAddresses =
          await widget.odooService.fetchCustomerAddresses(customerId);

      if (!mounted) return;

      setState(() {
        // Filter hanya alamat dengan tipe invoice dan delivery
        filteredInvoiceAddresses = [
          {
            'id': selectedCustomer?['id'],
            'name': selectedCustomer?['name'],
          },
          ...fetchedAddresses.where((a) => a['type'] == 'invoice').toList(),
        ];

        filteredDeliveryAddresses = [
          {
            'id': selectedCustomer?['id'],
            'name': selectedCustomer?['name'],
          },
          ...fetchedAddresses.where((a) => a['type'] == 'delivery').toList(),
        ];

        // Pilih alamat default yang sesuai dengan tipe, jika tidak ada pilih yang pertama
        selectedInvoiceAddress = filteredInvoiceAddresses.firstWhere(
          (a) => a['type'] == 'invoice',
          orElse: () => filteredInvoiceAddresses.isNotEmpty
              ? filteredInvoiceAddresses.first
              : {},
        );

        selectedDeliveryAddress = filteredDeliveryAddresses.firstWhere(
          (a) => a['type'] == 'delivery',
          orElse: () => filteredDeliveryAddresses.isNotEmpty
              ? filteredDeliveryAddresses.first
              : {},
        );
      });

      // Perbarui Vat sesuai Invoice Address yang terpilih
      final vat = await _getvatFromInvoiceAddress(selectedInvoiceAddress);
      setState(() {
        selectedCustomer?['vat'] = vat;
        customervat = vat;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading addresses: $e')),
      );
    }
  }

  Future<void> _saveHeader() async {
    if (selectedCustomer == null ||
        selectedSalesperson == null ||
        selectedPaymentTerm == null ||
        selectedWarehouse == null ||
        selectedInvoiceAddress == null ||
        selectedDeliveryAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    try {
      final headerData = {
        'partner_id': selectedCustomer!['id'],
        'partner_invoice_id': selectedInvoiceAddress!['id'],
        'partner_shipping_id': selectedDeliveryAddress!['id'],
        'user_member_id': selectedSalesperson!['id'],
        'payment_term_id': selectedPaymentTerm!['id'],
        'warehouse_id': selectedWarehouse!['id'],
        'notes': notes,
      };
      if (customervat != '0000000000000000' && customervat!.isEmpty) {
        headerData['vat'] = customervat;
      } else {
        headerData['vat'] = '0000000000000000';
      }

      final quotationId =
          await widget.odooService.createQuotationHeader(headerData);

      Navigator.pushNamed(
        context,
        '/formDetail',
        arguments: {
          'quotationId': quotationId,
          'headerData': headerData,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving quotation header: $e')),
      );
    }
  }

  void _fillPaymentTermFromCustomer(Map<String, dynamic> customer) {
    // Periksa apakah `property_payment_term_id` ada dan merupakan List
    if (customer.containsKey('property_payment_term_id') &&
        customer['property_payment_term_id'] is List &&
        customer['property_payment_term_id'].isNotEmpty) {
      final paymentTermId = customer['property_payment_term_id'][0]; // Ambil ID

      final matchedPaymentTerm = paymentTerms.firstWhere(
        (term) => term['id'] == paymentTermId,
        orElse: () => {},
      );

      setState(() {
        selectedPaymentTerm = matchedPaymentTerm;
      });
    } else {
      // Reset jika `property_payment_term_id` kosong atau tidak valid
      setState(() {
        selectedPaymentTerm = null;
      });
    }
  }

  Future<String?> _getvatFromInvoiceAddress(
      Map<String, dynamic>? invoiceAddress) async {
    if (invoiceAddress == null) {
      _showVatWarning();
      return '0000000000000000';
    }

    // Jika Invoice Address sama dengan Customer, gunakan Vat Customer
    if (invoiceAddress['id'] == selectedCustomer?['id']) {
      final vat = selectedCustomer?['vat'];

      if (vat == null || vat == false || vat == '') {
        _showVatWarning();
        return '0000000000000000';
      }

      return vat.toString(); // Pastikan nilai selalu berupa string
    }

    final matchedAddress = globalAddresses.firstWhere(
      (address) => address['id'] == invoiceAddress['id'],
      orElse: () => {'vat': ''}, // Default jika tidak ditemukan
    );

    final vat = matchedAddress['vat'];

    if (vat == null || vat == false || vat == '') {
      _showVatWarning();
      return '0000000000000000';
    }

    return vat
        .toString(); // Konversi VAT menjadi string untuk menghindari error
  }

  void _showVatWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Warning: VAT is missing for the selected customer.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildStyledDropdown({
    required String label,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic>? selectedItem,
    required ValueChanged<Map<String, dynamic>?>? onChanged,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty && enabled)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (items.isNotEmpty || !enabled)
          DropdownSearch<Map<String, dynamic>>(
            items: items,
            selectedItem: selectedItem,
            itemAsString: (item) => item['name'] ?? '',
            onChanged:
                enabled ? onChanged : null, // Nonaktifkan jika tidak aktif
            popupProps: PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: const TextFieldProps(
                decoration: InputDecoration(
                  labelText: 'Search',
                  border: OutlineInputBorder(),
                ),
              ),
              disabledItemFn: (item) =>
                  !enabled, // Nonaktifkan item jika dropdown nonaktif
            ),
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                filled: true,
                fillColor:
                    enabled ? Colors.white : Colors.grey[200], // Warna latar
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: enabled ? Colors.blue : Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Form Header Quotation",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStyledDropdown(
                label: "Customer",
                items: customers,
                selectedItem: selectedCustomer,
                onChanged: (value) {
                  setState(() {
                    selectedCustomer = value;
                  });
                  if (value != null) {
                    _loadChildAddresses(value['id']);
                    _fillPaymentTermFromCustomer(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildStyledDropdown(
                label: "Invoice Address",
                items: filteredInvoiceAddresses,
                selectedItem: selectedInvoiceAddress,
                onChanged: selectedCustomer != null
                    ? (value) async {
                        setState(() {
                          selectedInvoiceAddress = value;
                        });

                        // Perbarui Vat berdasarkan Invoice Address
                        final vat = await _getvatFromInvoiceAddress(value);
                        setState(() {
                          selectedCustomer?['vat'] = vat;
                        });
                      }
                    : null, // Nonaktifkan jika Customer belum dipilih
                enabled: selectedCustomer != null, // Tentukan status aktif
              ),
              const SizedBox(height: 16),
              _buildStyledDropdown(
                label: "Delivery Address",
                items: filteredDeliveryAddresses,
                selectedItem: selectedDeliveryAddress,
                onChanged: selectedCustomer != null
                    ? (value) {
                        setState(() {
                          selectedDeliveryAddress = value;
                        });
                      }
                    : null, // Nonaktifkan jika Customer belum dipilih
                enabled: selectedCustomer != null, // Tentukan status aktif
              ),
              const SizedBox(height: 16),
              if (showSalespersonField) // Hanya tampilkan jika true
                _buildStyledDropdown(
                  label: "Salesperson",
                  items: salespersons,
                  selectedItem: selectedSalesperson,
                  onChanged: (value) {
                    setState(() {
                      selectedSalesperson = value;
                    });
                  },
                ),
              // const SizedBox(height: 16),
              _buildStyledDropdown(
                label: "Payment Term",
                items: paymentTerms,
                selectedItem: selectedPaymentTerm,
                onChanged: (value) {
                  setState(() {
                    selectedPaymentTerm = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildStyledDropdown(
                label: "Warehouse",
                items: warehouses,
                selectedItem: selectedWarehouse,
                onChanged: (value) {
                  setState(() {
                    selectedWarehouse = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Notes",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 3, // Allow multiple lines for notes
                    onChanged: (value) {
                      setState(() {
                        notes = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _saveHeader,
                  child: const Text(
                    "Save and Continue",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
