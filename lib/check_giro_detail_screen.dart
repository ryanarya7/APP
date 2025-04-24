import 'package:flutter/material.dart';
import 'odoo_service.dart';
import 'package:intl/intl.dart';

class CheckGiroDetailScreen extends StatefulWidget {
  final OdooService odooService;
  final int checkBookId; // ID of the selected giro book
  const CheckGiroDetailScreen(
      {super.key, required this.odooService, required this.checkBookId});

  @override
  _CheckGiroDetailScreenState createState() => _CheckGiroDetailScreenState();
}

class _CheckGiroDetailScreenState extends State<CheckGiroDetailScreen> {
  late Future<Map<String, dynamic>> checkBookDetails;
  late Future<List<Map<String, dynamic>>> checkBookLines;
  late Future<List<Map<String, dynamic>>> customers;
  late Future<List<Map<String, dynamic>>> users;
  late Future<List<Map<String, dynamic>>> banks;
  int? currentPartnerId;

  @override
  void initState() {
    super.initState();
    _loadCheckBookDetails();
    _loadCheckBookLines();
    _loadCustomers();
    _loadUsers();
  }

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID', // Format Indonesia
    symbol: 'Rp ', // Simbol Rupiah
    decimalDigits: 2,
  );

  void _loadCheckBookDetails() {
    checkBookDetails =
        widget.odooService.fetchCheckBookById(widget.checkBookId).then((value) {
      // Extract partner ID for loading banks
      if (value['partner_id'] != null && value['partner_id'] is List) {
        currentPartnerId = value['partner_id'][0] as int?;
        if (currentPartnerId != null) {
          _loadBanks(currentPartnerId!);
        }
      }
      return value;
    });
  }

  void _loadCheckBookLines() {
    checkBookLines =
        widget.odooService.fetchCheckBookLinesByCheckBookId(widget.checkBookId);
  }

  void _loadCustomers() {
    customers = widget.odooService.fetchCustomers();
  }

  void _loadUsers() {
    users = widget.odooService.fetchUsers();
  }

  void _loadBanks(int partnerId) {
    banks = widget.odooService.fetchBanks(partnerId);
  }

  void _showAddLineDialog() {
    // Controllers for form fields
    final TextEditingController giroNumberController = TextEditingController();
    int? selectedBankId;
    DateTime receiveDate = DateTime.now();
    DateTime giroDate = DateTime.now();
    DateTime giroExpiredDate = DateTime.now();
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Add New Giro Line",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Giro Number
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: const Text(
                        "Giro Number",
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: TextFormField(
                        controller: giroNumberController,
                        decoration: const InputDecoration(
                          hintText: 'Enter giro number',
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bank Selection
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: banks,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ListTile(
                              title: Text("Loading banks..."));
                        }

                        if (snapshot.hasError) {
                          return ListTile(
                              title: Text("Error: ${snapshot.error}"));
                        }

                        final bankList = snapshot.data ?? [];
                        return ListTile(
                          title: const Text(
                            "Bank Penerbit",
                            style: TextStyle(fontSize: 14),
                          ),
                          subtitle: DropdownButton<int>(
                            value: selectedBankId,
                            isExpanded: true,
                            hint: const Text("Select Bank"),
                            onChanged: (int? newValue) {
                              selectedBankId = newValue;
                              (context as Element).markNeedsBuild();
                            },
                            items: bankList.map<DropdownMenuItem<int>>((bank) {
                              return DropdownMenuItem<int>(
                                value: bank['id'] as int,
                                child: Text(
                                    "${bank['bank_name'] ?? 'Unknown'} - ${bank['acc_number'] ?? ''}"),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: const Text(
                        "Receive Date",
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        DateFormat('dd-MM-yyyy').format(receiveDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: receiveDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && picked != receiveDate) {
                          receiveDate = picked;
                          // Make sure expired date is not before giro date
                          if (giroExpiredDate.isBefore(receiveDate)) {
                            giroExpiredDate =
                                receiveDate.add(const Duration(days: 30));
                          }
                          (context as Element).markNeedsBuild();
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Giro Date
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: const Text(
                        "Giro Date",
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        DateFormat('dd-MM-yyyy').format(giroDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: giroDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && picked != giroDate) {
                          setState(() {
                            giroDate = picked;
                            // Make sure expired date is not before giro date
                            if (giroExpiredDate.isBefore(giroDate)) {
                              giroExpiredDate =
                                  giroDate.add(const Duration(days: 30));
                            }
                          });
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Giro Expired Date
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: const Text(
                        "Giro Expired Date",
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        DateFormat('dd-MM-yyyy').format(giroExpiredDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: giroExpiredDate,
                          firstDate: giroDate, // Cannot be before giro date
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && picked != giroExpiredDate) {
                          setState(() {
                            giroExpiredDate = picked;
                          });
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Amount
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: const Text(
                        "Amount",
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixText: 'Rp ',
                          hintText: 'Enter amount',
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                        },
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Validate inputs
                          if (giroNumberController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a giro number'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (selectedBankId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a bank'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (amountController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter an amount'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          // Create the line
                          _createLine(
                            giroNumberController.text,
                            selectedBankId!,
                            giroDate,
                            giroExpiredDate,
                            double.tryParse(amountController.text) ?? 0.0,
                          );

                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Save"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _createLine(String giroNumber, int bankId, DateTime giroDate,
      DateTime giroExpiredDate, double amount) {
    // Create the values map for the new line
    Map<String, dynamic> values = {
      'checkbook_id': widget.checkBookId,
      'name': giroNumber,
      'partner_bank_id': bankId,
      'receive_date': DateFormat('yyyy-MM-dd').format(giroDate),
      'date': DateFormat('yyyy-MM-dd').format(giroDate),
      'date_end': DateFormat('yyyy-MM-dd').format(giroExpiredDate),
      'check_amount': amount,
    };

    // Call the API to create the line
    widget.odooService.createCheckBookLine(values).then((_) {
      // Reload data after creation
      setState(() {
        _loadCheckBookDetails();
        _loadCheckBookLines();
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giro line created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      // Show error message
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Failed to create giro line: $error'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
      String errorMessage = 'Failed to create giro line: $error';
      if (error.toString().contains('Giro Number must be unique per Company')) {
        errorMessage =
            'Giro Number must be unique per Company. Please use a different number.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _showEditLineDialog(Map<String, dynamic> line) {
    // Controllers for form fields
    final TextEditingController giroNumberController =
        TextEditingController(text: line['name'] ?? '');
    int? selectedBankId;
    DateTime receiveDate = DateTime.now();
    DateTime giroDate = DateTime.now();
    DateTime giroExpiredDate = DateTime.now();
    final TextEditingController amountController =
        TextEditingController(text: (line['check_amount'] ?? 0).toString());

    // Initialize values from the line
    if (line['partner_bank_id'] != null && line['partner_bank_id'] is List) {
      selectedBankId = line['partner_bank_id'][0] as int?;
    }

    if (line['receive_date'] != null) {
      receiveDate = DateTime.parse(line['receive_date']);
    }

    if (line['date'] != null) {
      giroDate = DateTime.parse(line['date']);
    }

    if (line['date_end'] != null) {
      giroExpiredDate = DateTime.parse(line['date_end']);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Edit Giro Line",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Giro Number (Read-only)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: const Text(
                        "Giro Number",
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: TextFormField(
                        controller: giroNumberController,
                        decoration: const InputDecoration(
                          hintText: 'Enter giro number',
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bank Selection
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: banks,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ListTile(
                              title: Text("Loading banks..."));
                        }

                        if (snapshot.hasError) {
                          return ListTile(
                              title: Text("Error: ${snapshot.error}"));
                        }

                        final bankList = snapshot.data ?? [];
                        return ListTile(
                          title: const Text(
                            "Bank Penerbit",
                            style: TextStyle(fontSize: 14),
                          ),
                          subtitle: DropdownButton<int>(
                            value: selectedBankId,
                            isExpanded: true,
                            hint: const Text("Select Bank"),
                            onChanged: (int? newValue) {
                              selectedBankId = newValue;
                              (context as Element).markNeedsBuild();
                            },
                            items: bankList.map<DropdownMenuItem<int>>((bank) {
                              return DropdownMenuItem<int>(
                                value: bank['id'] as int,
                                child: Text(
                                    "${bank['bank_name'] ?? 'Unknown'} - ${bank['acc_number'] ?? ''}"),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: const Text(
                        "Receive Date",
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        DateFormat('dd-MM-yyyy').format(receiveDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: receiveDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && picked != receiveDate) {
                          receiveDate = picked;
                          (context as Element).markNeedsBuild();
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Giro Date
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: const Text(
                        "Giro Date",
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        DateFormat('dd-MM-yyyy').format(giroDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: giroDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && picked != giroDate) {
                          giroDate = picked;
                          // Make sure expired date is not before giro date
                          if (giroExpiredDate.isBefore(giroDate)) {
                            giroExpiredDate =
                                giroDate.add(const Duration(days: 30));
                          }
                          (context as Element).markNeedsBuild();
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Giro Expired Date
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: const Text(
                        "Giro Expired Date",
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        DateFormat('dd-MM-yyyy').format(giroExpiredDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: giroExpiredDate,
                          firstDate: giroDate, // Cannot be before giro date
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && picked != giroExpiredDate) {
                          giroExpiredDate = picked;
                          (context as Element).markNeedsBuild();
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Amount
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: const Text(
                        "Amount",
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixText: 'Rp ',
                          hintText: 'Enter amount',
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                        },
                        child: const Text("Cancel"),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Save the changes
                          Map<String, dynamic> updatedValues = {
                            'name': giroNumberController.text,
                            'partner_bank_id': selectedBankId,
                            'receive_date':
                                DateFormat('yyyy-MM-dd').format(receiveDate),
                            'date': DateFormat('yyyy-MM-dd').format(giroDate),
                            'date_end': DateFormat('yyyy-MM-dd')
                                .format(giroExpiredDate),
                            'check_amount':
                                double.tryParse(amountController.text) ?? 0.0,
                          };

                          _updateLine(line['id'], updatedValues);
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Save"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateLine(int lineId, Map<String, dynamic> values) {
    widget.odooService.updateCheckBookLine(lineId, values).then((_) {
      // Reload data after update
      setState(() {
        _loadCheckBookDetails();
        _loadCheckBookLines();
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giro line updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update giro line: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _showDeleteConfirmation(int lineId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Giro Line"),
          content: const Text(
              "Are you sure you want to delete this giro line? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                _deleteLine(lineId);
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  void _deleteLine(int lineId) {
    widget.odooService.deleteCheckBookLine(lineId).then((_) {
      // Reload data after delete
      setState(() {
        _loadCheckBookDetails();
        _loadCheckBookLines();
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giro line deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete giro line: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _showEditHeaderDialog(Map<String, dynamic> checkBook) {
    // Extracting current values from checkBook for the form
    int? currentCustomerId;
    int? currentUserId;
    DateTime currentReceiveDate = DateTime.now();

    if (checkBook['partner_id'] != null && checkBook['partner_id'] is List) {
      currentCustomerId = checkBook['partner_id'][0] as int?;
    }

    if (checkBook['user_id'] != null && checkBook['user_id'] is List) {
      currentUserId = checkBook['user_id'][0] as int?;
    }

    if (checkBook['date'] != null) {
      currentReceiveDate = DateTime.parse(checkBook['date']);
    }

    // Controllers and variables for form fields
    int? selectedCustomerId = currentCustomerId;
    int? selectedUserId = currentUserId; // Keep the existing user ID
    DateTime selectedDate = currentReceiveDate;

    // Search controller for customers
    final TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> filteredCustomers = [];
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Edit Giro Book Header",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Payment Type (Read-only)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: const Text(
                            "Payment Type",
                            style: TextStyle(fontSize: 14),
                          ),
                          subtitle: const Text(
                            "Receive (Inbound)",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey,
                            size: 16,
                          ),
                          enabled: false, // Read-only
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Customer Dropdown with Search
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: customers,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const ListTile(
                                  title: Text("Loading customers..."));
                            }

                            if (snapshot.hasError) {
                              return ListTile(
                                  title: Text("Error: ${snapshot.error}"));
                            }

                            final customerList = snapshot.data ?? [];

                            if (!isSearching) {
                              // Find the selected customer name for display
                              String selectedCustomerName = "Select Customer";
                              if (selectedCustomerId != null) {
                                for (var customer in customerList) {
                                  if (customer['id'] == selectedCustomerId) {
                                    selectedCustomerName =
                                        customer['name'] ?? 'Unknown';
                                    break;
                                  }
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    title: const Text(
                                      "Customer",
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      selectedCustomerName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    trailing: const Icon(Icons.search),
                                    onTap: () {
                                      setState(() {
                                        isSearching = true;
                                        filteredCustomers =
                                            List.from(customerList);
                                      });
                                    },
                                  ),
                                ],
                              );
                            } else {
                              // Show search interface
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: Text(
                                      "Customer",
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700]),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0, vertical: 8.0),
                                    child: TextField(
                                      controller: searchController,
                                      decoration: InputDecoration(
                                        hintText: "Search customer...",
                                        prefixIcon: const Icon(Icons.search),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            setState(() {
                                              isSearching = false;
                                              searchController.clear();
                                            });
                                          },
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          filteredCustomers = customerList
                                              .where((customer) =>
                                                  customer['name']
                                                      .toString()
                                                      .toLowerCase()
                                                      .contains(
                                                          value.toLowerCase()))
                                              .toList();
                                        });
                                      },
                                    ),
                                  ),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight:
                                          MediaQuery.of(context).size.height *
                                              0.3,
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: filteredCustomers.length,
                                      itemBuilder: (context, index) {
                                        final customer =
                                            filteredCustomers[index];
                                        return ListTile(
                                          title: Text(
                                              customer['name'] ?? 'Unknown'),
                                          onTap: () {
                                            setState(() {
                                              selectedCustomerId =
                                                  customer['id'] as int;
                                              isSearching = false;
                                              searchController.clear();
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Created Date (Read-only)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: const Text(
                            "Created Date",
                            style: TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            DateFormat('dd-MM-yyyy').format(selectedDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.calendar_today,
                            color: Colors.grey,
                          ),
                          enabled: false, // Read-only
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Received By (Read-only)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: users,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const ListTile(
                                  title: Text("Loading users..."));
                            }

                            if (snapshot.hasError) {
                              return ListTile(
                                  title: Text("Error: ${snapshot.error}"));
                            }

                            // Find the currently logged in user name
                            String userName = "Current User";
                            if (selectedUserId != null) {
                              final userList = snapshot.data ?? [];
                              for (var user in userList) {
                                if (user['id'] == selectedUserId) {
                                  userName = user['name'] ?? 'Unknown';
                                  break;
                                }
                              }
                            }

                            return ListTile(
                              title: const Text(
                                "Received By",
                                style: TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              enabled: false, // Read-only
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close dialog
                            },
                            child: const Text("Cancel"),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () {
                              // Save the changes
                              Map<String, dynamic> updatedValues = {
                                'payment_type': 'inbound', // Fixed as inbound
                                'partner_id': selectedCustomerId,
                                'date': DateFormat('yyyy-MM-dd')
                                    .format(selectedDate),
                                // Keep the original user_id, making it readonly
                                'user_id': selectedUserId,
                              };

                              _updateCheckBookHeader(updatedValues);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Save"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _updateCheckBookHeader(Map<String, dynamic> values) {
    widget.odooService.updateCheckBook(widget.checkBookId, values).then((_) {
      // Reload data after update
      setState(() {
        _loadCheckBookDetails();
        _loadCheckBookLines();
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check book updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update check book: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _confirmGiroBook() {
    // Tampilkan dialog konfirmasi terlebih dahulu
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // Gunakan dialogContext untuk dialog ini
        return AlertDialog(
          title: const Text("Confirm Giro Book"),
          content: const Text(
              "Are you sure you want to confirm this giro book? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Gunakan dialogContext
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Gunakan dialogContext

                // Simpan context saat ini untuk digunakan nanti
                final BuildContext currentContext = context;

                // Tampilkan loading indicator
                showDialog(
                  context: currentContext,
                  barrierDismissible: false,
                  builder: (BuildContext loadingContext) {
                    // Gunakan loadingContext untuk dialog loading
                    return const Dialog(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 20),
                            Text("Confirming giro book..."),
                          ],
                        ),
                      ),
                    );
                  },
                );

                // Panggil API untuk konfirmasi
                widget.odooService
                    .confirmGiroBook(widget.checkBookId)
                    .then((_) {
                  // Periksa apakah widget masih terpasang sebelum menggunakan context
                  if (!mounted) return;

                  // Tutup dialog loading dengan context yang benar
                  Navigator.of(currentContext).pop();

                  // Reload data
                  setState(() {
                    _loadCheckBookDetails();
                    _loadCheckBookLines();
                  });

                  // Tampilkan pesan sukses
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Giro book confirmed successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }).catchError((error) {
                  // Periksa apakah widget masih terpasang sebelum menggunakan context
                  if (!mounted) return;

                  // Tutup dialog loading dengan context yang benar
                  Navigator.of(currentContext).pop();

                  // Tampilkan pesan error
                  ScaffoldMessenger.of(currentContext).showSnackBar(
                    SnackBar(
                      content: Text('Failed to confirm giro book: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Giro Book Details",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[300],
        actions: [
          // Tampilkan tombol confirm hanya jika status giro book adalah 'draft'
          FutureBuilder<Map<String, dynamic>>(
            future: checkBookDetails,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  !snapshot.hasData ||
                  snapshot.data == null) {
                return Container(); // Tombol tidak ditampilkan saat loading
              }

              final checkBook = snapshot.data!;
              if (checkBook['state'] == 'draft') {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton(
                    onPressed: _confirmGiroBook,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    ),
                    child: const Text(
                      "Confirm",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }
              return Container(); // Tidak tampilkan tombol jika bukan draft
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: checkBookDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child:
                  Text('Error loading check book details: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No data available'));
          }

          final checkBook = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section with Edit Button
                Card(
                  margin: const EdgeInsets.all(16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    checkBook['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: _getStateColor(checkBook['state']),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _getStateDisplayName(
                                        checkBook['state'] ?? ''),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Table(
                              columnWidths: const {
                                0: IntrinsicColumnWidth(),
                                1: FixedColumnWidth(12),
                                2: FlexColumnWidth(),
                              },
                              children: [
                                _buildInfoRow(
                                    "Payment Type",
                                    _getPaymentTypeDisplay(
                                        checkBook['payment_type'] ?? '')),
                                _buildInfoRow("Customer",
                                    _getSafeValue(checkBook['partner_id'])),
                                _buildInfoRow(
                                    "Created Date",
                                    DateFormat('dd-MM-yyyy').format(
                                        DateTime.parse(
                                            checkBook['date'] ?? ''))),
                                _buildInfoRow("Received By",
                                    _getSafeValue(checkBook['user_id'])),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Edit button for draft state
                      if (checkBook['state'] == 'draft')
                        Positioned(
                          top: 8,
                          right: 70,
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              _showEditHeaderDialog(checkBook);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Giro Book Lists",
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      if (checkBook['state'] == 'draft' ||
                          checkBook['state'] == 'confirm')
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.green),
                          onPressed: () {
                            _showAddLineDialog();
                          },
                        ),
                    ],
                  ),
                ),

                // Line Items Section
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: checkBookLines,
                  builder: (context, lineSnapshot) {
                    if (lineSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (lineSnapshot.hasError) {
                      return Center(
                        child: Text(
                            'Error loading check book lines: ${lineSnapshot.error}'),
                      );
                    }
                    if (!lineSnapshot.hasData || lineSnapshot.data!.isEmpty) {
                      return const Center(child: Text('No lines available'));
                    }

                    final lines = lineSnapshot.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: lines.length,
                      itemBuilder: (context, index) {
                        final line = lines[index];
                        final bool canEdit = checkBook['state'] == 'draft' ||
                            checkBook['state'] == 'confirm';

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Table(
                                  columnWidths: const {
                                    0: IntrinsicColumnWidth(),
                                    1: FixedColumnWidth(12),
                                    2: FlexColumnWidth(),
                                  },
                                  children: [
                                    _buildInfoRow(
                                        "Giro No", line['name'] ?? ''),
                                    _buildInfoRow("Bank Penerbit",
                                        _getSafeValue(line['partner_bank_id'])),
                                    _buildInfoRow(
                                      "Receive Date",
                                      line['receive_date'] != null &&
                                              line['receive_date'] is String
                                          ? DateFormat('dd-MM-yyyy').format(
                                              DateTime.parse(
                                                  line['receive_date']))
                                          : "",
                                    ),
                                    _buildInfoRow(
                                        "Giro Date",
                                        DateFormat('dd-MM-yyyy').format(
                                            DateTime.parse(
                                                line['date'] ?? ''))),
                                    _buildInfoRow(
                                        "Giro Expired",
                                        DateFormat('dd-MM-yyyy').format(
                                            DateTime.parse(
                                                line['date_end'] ?? ''))),
                                    _buildInfoRow(
                                        "Amount",
                                        currencyFormatter
                                            .format(line['check_amount'] ?? 0)),
                                    _buildInfoRow(
                                        "Residual",
                                        currencyFormatter.format(
                                            line['check_residual'] ?? 0)),
                                    _buildInfoRow(
                                      "Payment",
                                      line['payment_names'] ?? '',
                                    ),
                                    _buildStatusRow(
                                      "Status",
                                      _getLineStatus(line['state'] ?? ''),
                                      line['state'] ?? '',
                                      false,
                                    ),
                                    _buildStatusRow(
                                      "Payment Status",
                                      _getPaymentStatus(
                                          line['payment_status'] ?? ''),
                                      line['payment_status'] ?? '',
                                      true,
                                    ),
                                  ],
                                ),
                              ),
                              // Edit and Delete buttons
                              if (canEdit)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Row(
                                    children: [
                                      if (line['payment_status'] == 'no')
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue, size: 20),
                                          onPressed: () {
                                            _showEditLineDialog(line);
                                          },
                                        ),
                                      if (line['payment_status'] == 'no')
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red, size: 20),
                                          onPressed: () {
                                            _showDeleteConfirmation(line['id']);
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                Card(
                  margin: const EdgeInsets.all(16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Table(
                      columnWidths: const {
                        0: IntrinsicColumnWidth(),
                        1: FixedColumnWidth(12),
                        2: FlexColumnWidth(),
                      },
                      children: [
                        _buildTotalRow(
                          "Total Check",
                          currencyFormatter
                              .format(checkBook['total_check'] ?? 0),
                        ),
                        _buildTotalRow(
                          "Residual Check",
                          currencyFormatter
                              .format(checkBook['residual_check'] ?? 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  TableRow _buildInfoRow(String label, String value) {
    // Implementation remains the same
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4.0),
          child: Text(" : ", style: TextStyle(fontSize: 12)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  TableRow _buildTotalRow(String label, String value) {
    // Implementation remains the same
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4.0),
          child: Text(" : ", style: TextStyle(fontSize: 12)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  TableRow _buildStatusRow(String label, String displayValue, String rawValue,
      bool isPaymentStatus) {
    // Implementation remains the same
    Color? color = isPaymentStatus
        ? _getPaymentStatusColor(rawValue)
        : _getStateColor(rawValue);

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4.0),
          child: Text(" : ", style: TextStyle(fontSize: 12)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayValue,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getSafeValue(dynamic value) {
    // Implementation remains the same
    if (value is List && value.isNotEmpty) {
      return value[1]?.toString() ?? 'N/A';
    }
    if (value == null) {
      return 'N/A';
    }
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }
    return value.toString();
  }

  String _getPaymentTypeDisplay(String? paymentType) {
    // Implementation remains the same
    if (paymentType == 'outbound') {
      return 'Send';
    } else if (paymentType == 'inbound') {
      return 'Receive';
    } else {
      return 'Unknown';
    }
  }

  String _getLineStatus(String? paymentStatus) {
    // Implementation remains the same
    switch (paymentStatus) {
      case 'hold':
        return 'Hold';
      case 'active':
        return 'Active';
      case 'paid':
        return 'Paid';
      case 'end':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  String _getPaymentStatus(String? paymentStatus) {
    // Implementation remains the same
    switch (paymentStatus) {
      case 'paid':
        return 'Fully Paid';
      case 'partial':
        return 'Partial Payment';
      case 'over':
        return 'Over Paid';
      case 'no':
        return 'Not Use';
      case 'cancel':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  String _getStateDisplayName(String? state) {
    // Implementation remains the same
    if (state == null) return 'Unknown';
    return toBeginningOfSentenceCase(state.toLowerCase()) ?? state;
  }

  Color? _getStateColor(String? state) {
    // Implementation remains the same
    switch (state) {
      case 'draft':
        return Colors.grey;
      case 'confirm':
        return Colors.green;
      case 'cancel':
        return Colors.red;
      case 'used':
        return Colors.yellow;
      case 'hold':
        return Colors.grey;
      case 'active':
        return Colors.green;
      case 'paid':
        return Colors.green[600];
      case 'end':
        return Colors.red;
      case 'partial':
        return Colors.blue;
      case 'over':
        return Colors.yellow;
      case 'no':
        return Colors.red;
      default:
        return Colors.black54; // Default color if status is unknown
    }
  }

  Color? _getPaymentStatusColor(String? paymentStatus) {
    switch (paymentStatus) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.blue;
      case 'over':
        return Colors.yellow;
      case 'no':
        return Colors.red;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.black54;
    }
  }
}
