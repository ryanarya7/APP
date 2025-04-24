// ignore_for_file: unnecessary_cast, unused_field

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'odoo_service.dart';

class GiroFormHeaderScreen extends StatefulWidget {
  final OdooService odooService;
  final int? checkBookId;

  const GiroFormHeaderScreen({
    Key? key,
    required this.odooService,
    this.checkBookId,
  }) : super(key: key);

  @override
  _GiroFormHeaderScreenState createState() => _GiroFormHeaderScreenState();
}

class _GiroFormHeaderScreenState extends State<GiroFormHeaderScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditMode = false;
  Map<String, dynamic>? _loggedInUser;

  // Form controllers
  final TextEditingController _dateController = TextEditingController();
  final String _paymentType =
      'inbound'; // Default to 'Receive' and make it final
  int? _selectedPartnerId;
  int? _selectedUserId;
  String? _selectedPartnerName;
  String? _selectedUserName;
  List<Map<String, dynamic>> _partners = [];
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.checkBookId != null;
    _loadData();
    _setDefaultDate();
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  void _setDefaultDate() {
    final now = DateTime.now();
    _dateController.text = DateFormat('yyyy-MM-dd').format(now);
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load partners and users in parallel
      final futures = await Future.wait([
        widget.odooService.fetchCustomers(),
        widget.odooService.fetchUsers(),
      ]);
      _partners = futures[0] as List<Map<String, dynamic>>;
      _users = futures[1] as List<Map<String, dynamic>>;

      // Fetch logged-in user details
      _loggedInUser = await widget.odooService.fetchUser();

      // If in edit mode, load existing data
      if (_isEditMode) {
        await _loadExistingData();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Failed to load data: $e');
    }
  }

  Future<void> _loadExistingData() async {
    try {
      final checkBookData =
          await widget.odooService.fetchCheckBookById(widget.checkBookId!);

      // Populate form fields with existing data
      _dateController.text = checkBookData['date'] != null
          ? DateFormat('yyyy-MM-dd')
              .format(DateTime.parse(checkBookData['date']))
          : '';

      // Handle partner
      if (checkBookData['partner_id'] != null &&
          checkBookData['partner_id'] is List &&
          checkBookData['partner_id'].length > 1) {
        _selectedPartnerId = checkBookData['partner_id'][0];
        _selectedPartnerName = checkBookData['partner_id'][1];
      }

      // Handle user
      if (checkBookData['user_id'] != null &&
          checkBookData['user_id'] is List &&
          checkBookData['user_id'].length > 1) {
        _selectedUserId = checkBookData['user_id'][0];
        _selectedUserName = checkBookData['user_id'][1];
      }
    } catch (e) {
      _showErrorSnackbar('Failed to load check book data: $e');
      throw e; // Rethrow to be caught by the parent function
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateController.text.isNotEmpty
          ? DateFormat('yyyy-MM-dd').parse(_dateController.text)
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveGiroHeader() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final giroHeaderData = {
        'date': _dateController.text,
        'payment_type': _paymentType,
        'partner_id': _selectedPartnerId,
        'user_id': _loggedInUser?['id'],
      };

      int checkBookId;
      if (_isEditMode) {
        // Update existing record
        await widget.odooService
            .updateCheckBook(widget.checkBookId!, giroHeaderData);
        checkBookId = widget.checkBookId!;
        _showSuccessSnackbar('Giro header updated successfully');
      } else {
        // Create new record
        checkBookId = await widget.odooService.createCheckBook(giroHeaderData);
        print("Successfully created checkbook with ID: $checkBookId");
        _showSuccessSnackbar('Giro header created successfully');
      }

      setState(() {
        _isLoading = false;
      });

      // Navigate to form detail screen for adding/editing lines
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/checkGiroDetail',
          arguments: {'checkBookId': checkBookId},
        );
      }
    } catch (e) {
      print("Error in _saveGiroHeader: $e");
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Failed to save giro header: $e');
    }
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _showCustomerSearchDialog() async {
    final TextEditingController _searchController = TextEditingController();
    List<Map<String, dynamic>> _filteredPartners = List.from(_partners);

    void _filterPartners(String query) {
      _filteredPartners = _partners
          .where((partner) => partner['name']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    }

    final selectedPartner = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Customer'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filterPartners(value);
                        });
                      },
                      autofocus: true,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredPartners.length,
                        itemBuilder: (context, index) {
                          final partner = _filteredPartners[index];
                          return ListTile(
                            title: Text(partner['name']),
                            onTap: () {
                              Navigator.of(context).pop(partner);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedPartner != null) {
      setState(() {
        _selectedPartnerId = selectedPartner['id'];
        _selectedPartnerName = selectedPartner['name'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Giro Book' : 'New Giro Book',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[300],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Header Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Date Field
                            TextFormField(
                              controller: _dateController,
                              decoration: InputDecoration(
                                labelText: 'Created Date',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: _selectDate,
                                ),
                              ),
                              readOnly: true,
                              enabled: false,
                            ),
                            const SizedBox(height: 16),

                            // Payment Type - Read Only
                            TextFormField(
                              initialValue: _paymentType == 'inbound'
                                  ? 'Receive'
                                  : 'Send',
                              decoration: const InputDecoration(
                                labelText: 'Payment Type',
                                border: OutlineInputBorder(),
                              ),
                              readOnly: true,
                              enabled: false,
                            ),
                            const SizedBox(height: 16),

                            // Partner/Customer Selection
                            InkWell(
                              onTap: _showCustomerSearchDialog,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Customer',
                                  border: const OutlineInputBorder(),
                                  errorText:
                                      _formKey.currentState?.validate() ==
                                                  false &&
                                              _selectedPartnerId == null
                                          ? 'Please select a customer'
                                          : null,
                                  suffixIcon: const Icon(Icons.arrow_drop_down),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedPartnerName ??
                                            'Select Customer',
                                        style: TextStyle(
                                          color: _selectedPartnerName != null
                                              ? null
                                              : Theme.of(context).hintColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue:
                                  _loggedInUser?['name'] ?? 'Not Available',
                              decoration: const InputDecoration(
                                labelText: 'Received By',
                                border: OutlineInputBorder(),
                              ),
                              readOnly: true,
                              enabled: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveGiroHeader,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 15),
                          ),
                          child: Text(
                            _isEditMode
                                ? 'Update & Continue'
                                : 'Save & Continue',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
