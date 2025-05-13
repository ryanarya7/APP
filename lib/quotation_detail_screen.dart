// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'dart:convert';
import 'odoo_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'edit_header_dialog.dart';

class QuotationDetailScreen extends StatefulWidget {
  final OdooService odooService;
  final int quotationId;

  const QuotationDetailScreen({
    Key? key,
    required this.odooService,
    required this.quotationId,
  }) : super(key: key);

  @override
  _QuotationDetailScreenState createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  late Future<Map<String, dynamic>> quotationDetails;
  late List<Map<String, dynamic>> tempOrderLines = [];
  List<int> deletedOrderLines = [];
  late List<Map<String, dynamic>> editOrderLines = [];
  late List<TextEditingController> _quantityControllers;
  late List<TextEditingController> _priceControllers;
  late Future<List<Map<String, dynamic>>> orderLines;
  late Future<String> deliveryOrderStatus;
  late Future<String> invoiceStatus;
  bool isEditLineMode = false;
  Map<int, TextEditingController> _noteControllers = {};
  String notes = '';

  @override
  void initState() {
    super.initState();
    _quantityControllers = [];
    _priceControllers = [];
    _noteControllers = {};
    _loadQuotationDetails();
    quotationDetails =
        widget.odooService.fetchQuotationById(widget.quotationId);
    quotationDetails.then((data) {
      final saleOrderName = data['name'];
      setState(() {
        deliveryOrderStatus =
            widget.odooService.fetchDeliveryOrderStatus(saleOrderName);
        invoiceStatus = widget.odooService.fetchInvoiceStatus(saleOrderName);
      });
    });
  }

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID', // Format Indonesia
    symbol: 'Rp ', // Simbol Rupiah
    decimalDigits: 2,
  );

  void _loadQuotationDetails() {
    quotationDetails =
        widget.odooService.fetchQuotationById(widget.quotationId);
    quotationDetails.then((data) {
      final saleOrderName = data['name'];
      setState(() {
        deliveryOrderStatus =
            widget.odooService.fetchDeliveryOrderStatus(saleOrderName);
        invoiceStatus = widget.odooService.fetchInvoiceStatus(saleOrderName);
      });
    });
  }

  Future<void> _loadOrderLines() async {
    try {
      final data = await quotationDetails;
      final orderLineIds = List<int>.from(data['order_line'] ?? []);
      final fetchedOrderLines =
          await widget.odooService.fetchOrderLines(orderLineIds);

      setState(() {
        tempOrderLines = fetchedOrderLines
            .map((line) => {
                  ...line,
                  'original_price': line['price_unit'],
                  // Ensure product_id is properly stored as an integer
                  'product_id': line['product_id'] is List
                      ? line['product_id'][0]
                      : line['product_id'],
                })
            .toList();
        _noteControllers.clear();

        // Print for debugging
        print(
            'Loaded tempOrderLines product IDs: ${tempOrderLines.map((e) => e['product_id']).toList()}');

        // Reinitialize controllers with the NEW tempOrderLines length
        _quantityControllers = tempOrderLines.map((line) {
          final qty = line['product_uom_qty'];
          final initialQty =
              qty is double ? qty.toInt().toString() : qty.toString();
          return TextEditingController(text: initialQty);
        }).toList();

        _priceControllers = tempOrderLines
            .map((line) => TextEditingController(
                text: line['price_unit'].toStringAsFixed(2)))
            .toList();

        for (int i = 0; i < tempOrderLines.length; i++) {
          if (tempOrderLines[i]['display_type'] != 'line_note') {
            final noteValue = tempOrderLines[i]['notes'];
            final noteText = noteValue is String ? noteValue : '';
            _noteControllers[i] = TextEditingController(text: noteText);
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading order lines: $e')),
      );
    }
  }

  // Future<void> _confirmQuotation() async {
  //   try {
  //     await widget.odooService.confirmQuotation(widget.quotationId);
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Quotation Confirmed Successfully!')),
  //     );
  //     setState(() {
  //       // Reload quotation details after confirmation
  //       quotationDetails =
  //           widget.odooService.fetchQuotationById(widget.quotationId);
  //     });
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error confirming quotation: $e')),
  //     );
  //   }
  // }

  // Future<void> _cancelQuotation() async {
  //   try {
  //     await widget.odooService.cancelQuotation(widget.quotationId);
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Quotation Cancelled Successfully!')),
  //     );
  //     setState(() {
  //       quotationDetails =
  //           widget.odooService.fetchQuotationById(widget.quotationId);
  //     });
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Error cancelling quotation: $e')),
  //     );
  //   }
  // }

  Future<void> _setToQuotation() async {
    try {
      print('Resetting quotation to draft with ID: ${widget.quotationId}');
      await widget.odooService.setToQuotation(widget.quotationId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quotation Reset to Draft Successfully!')),
      );
      setState(() {
        quotationDetails =
            widget.odooService.fetchQuotationById(widget.quotationId);
      });
    } catch (e) {
      print('Error resetting quotation to draft: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resetting quotation: $e')),
      );
    }
  }

  void _showEditHeaderDialog(Map<String, dynamic> headerData) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditHeaderDialog(
        initialData: headerData, // Menggunakan initialData sebagai parameter
        odooService: widget.odooService,
      ),
    );

    if (result != null) {
      // Update quotationDetails setelah edit
      setState(() {
        quotationDetails =
            widget.odooService.fetchQuotationById(widget.quotationId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quotation header updated successfully!')),
      );
    }
  }

  String _mapDeliveryStatus(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'cancel':
        return 'Cancelled';
      case 'waiting':
        return 'Waiting';
      case 'confirmed':
        return 'Confirmed';
      case 'assigned':
        return 'Ready';
      case 'done':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  String _mapInvoiceStatus(String status) {
    switch (status) {
      case 'not_paid':
        return 'Not Paid';
      case 'in_payment':
        return 'In Payment';
      case 'paid':
        return 'Paid';
      case 'partial':
        return 'Partially Paid';
      case 'reversed':
        return 'Reversed';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'cancel':
        return Colors.red;
      case 'waiting':
        return Colors.purple;
      case 'not_paid':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'in_payment':
        return Colors.blue;
      case 'assigned':
        return Colors.teal;
      case 'done':
        return Colors.grey;
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.purple;
      case 'sent':
        return Colors.grey;
      case 'sale':
        return Colors.green;
      default:
        return const Color.fromARGB(255, 79, 80, 74);
    }
  }

  void _navigateToSaleOrderList() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home', // Explicitly target the Sales Order List screen
      (route) => false,
      arguments: 1, // Ensure no lingering arguments are passed
    );
  }

  Future<void> _saveChanges() async {
    try {
      // Validasi harga sebelum menyimpan
      bool isValid = true;
      List<String> errorMessages = [];

      for (int i = 0; i < tempOrderLines.length; i++) {
        final currentLine = tempOrderLines[i];
        if (currentLine['display_type'] == 'line_note') continue;
        final originalPrice =
            currentLine['original_price'] ?? currentLine['price_unit'];
        final currentPrice = currentLine['price_unit'];

        if (currentPrice < originalPrice) {
          isValid = false;
          errorMessages.add(
            'The price for "${currentLine['name']}" cannot be lower than the normal price (${currencyFormatter.format(originalPrice)}).',
          );
        }
      }

      // Jika ada harga yang lebih rendah, tampilkan pop-up error
      if (!isValid) {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: Colors.red, // Background merah
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8), // Border radius
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Error",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessages.join('\n'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Tutup dialog
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                      ),
                      child: const Text("OK"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        return; // Batalkan proses penyimpanan
      }

      // Simpan perubahan ke backend jika semua harga valid
      await _updateOrderLinesWithNotes();

      // Hapus baris yang ditandai untuk dihapus
      for (final id in deletedOrderLines) {
        await widget.odooService.deleteOrderLine(id);
      }

      setState(() {
        isEditLineMode = false;
        deletedOrderLines.clear(); // Kosongkan daftar baris yang dihapus
        _loadQuotationDetails(); // Reload data setelah penyimpanan
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order lines updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving changes: $e')),
      );
    }
  }

  Future<void> _updateOrderLinesWithNotes() async {
    for (final line in tempOrderLines) {
      if (line['id'] == null) {
        // Creating new line
        if (line['display_type'] == 'line_note') {
          // Create note line
          await widget.odooService.createNoteLine(
            widget.quotationId,
            line['name'],
          );
        } else {
          // Create product line
          // Convert product_uom_qty to int explicitly
          final qty = line['product_uom_qty'] is String
              ? int.tryParse(line['product_uom_qty'] as String) ?? 0
              : line['product_uom_qty'] is double
                  ? (line['product_uom_qty'] as double).toInt()
                  : line['product_uom_qty'] is int
                      ? line['product_uom_qty']
                      : 0;

          // Convert notes to string safely
          final notes = (line['notes'] == null || line['notes'] == false)
              ? '' // Handle null or false values
              : line['notes'].toString(); // Convert any other type to string

          await widget.odooService.createProductLine(
            widget.quotationId,
            line['product_id'],
            line['name'],
            qty, // Using the converted integer value
            line['price_unit'],
            notes, // Using the safe string value
          );
        }
      } else {
        // Updating existing line
        if (line['display_type'] == 'line_note') {
          // Update note line - only name needs to be updated
          await widget.odooService.updateNoteLine(
            line['id'],
            line['name'],
          );
        } else {
          // Update product line
          // Convert product_uom_qty to int explicitly
          final qty = line['product_uom_qty'] is String
              ? int.tryParse(line['product_uom_qty'] as String) ?? 0
              : line['product_uom_qty'] is double
                  ? (line['product_uom_qty'] as double).toInt()
                  : line['product_uom_qty'] is int
                      ? line['product_uom_qty']
                      : 0;

          // Convert notes to string safely
          final notes = (line['notes'] == null || line['notes'] == false)
              ? '' // Handle null or false values
              : line['notes'].toString(); // Convert any other type to string

          await widget.odooService.updateProductLine(
              line['id'],
              qty, // Using the converted integer value
              line['price_unit'],
              notes); // Using the safe string value
        }
      }
    }
  }

  void _addProduct(Map<String, dynamic> product) {
    setState(() {
      // Check if the product already exists in tempOrderLines
      final productId = product['product_id'];

      // Look for this product ID in the entire tempOrderLines array
      final existingProductIndex =
          tempOrderLines.indexWhere((line) => line['product_id'] == productId);

      // If product already exists in order lines, update quantity
      if (existingProductIndex != -1) {
        // Get current quantity and add 1
        final currentQty =
            tempOrderLines[existingProductIndex]['product_uom_qty'] ?? 0;

        // Update quantity
        tempOrderLines[existingProductIndex]['product_uom_qty'] =
            currentQty + 1;

        // Update the quantity controller text
        if (existingProductIndex < _quantityControllers.length) {
          _quantityControllers[existingProductIndex].text =
              (currentQty + 1).toString();
        }

        // Make sure we're comparing the correct product IDs by logging them
        print(
            'Added to existing product: ${productId} at index ${existingProductIndex}');
        print(
            'Current tempOrderLines products: ${tempOrderLines.map((e) => e['id']).toList()}');
      } else {
        // If product doesn't exist, add a new line
        final price = product['price_unit'];
        final newIndex = tempOrderLines.length;

        tempOrderLines.add({
          'id': null,
          'product_id': productId,
          'name': product['name'],
          'product_uom_qty': 1,
          'price_unit': price,
          'original_price': price,
          'notes': '',
        });

        // Add new controllers for the new line
        _quantityControllers.add(TextEditingController(text: '1'));
        _priceControllers.add(
          TextEditingController(text: price.toStringAsFixed(2)),
        );
        _noteControllers[newIndex] = TextEditingController(text: '');

        print('Added new product: ${productId}');
      }
    });
  }

  // void _updateLinePrice(int index, String newPrice) {
  //   final currentLine = tempOrderLines[index];
  //   final originalPrice =
  //       currentLine['original_price'] ?? currentLine['price_unit'];
  //   final parsedPrice = double.tryParse(newPrice) ?? currentLine['price_unit'];

  //   if (parsedPrice < originalPrice) {
  //     // Show a dialog warning about minimum price
  //     showDialog(
  //       context: context,
  //       builder: (BuildContext context) {
  //         return AlertDialog(
  //           title: const Text('Price Validation'),
  //           content: Text(
  //             'Price cannot be lower than the original price of ${currencyFormatter.format(originalPrice)}.',
  //             style: const TextStyle(fontSize: 14),
  //           ),
  //           actions: <Widget>[
  //             TextButton(
  //               child: const Text('OK'),
  //               onPressed: () {
  //                 Navigator.of(context).pop();
  //                 // Reset the price controller to the original price
  //                 _priceControllers[index].text =
  //                     originalPrice.toStringAsFixed(2);
  //               },
  //             ),
  //           ],
  //         );
  //       },
  //     );
  //     return;
  //   }

  //   setState(() {
  //     tempOrderLines[index]['price_unit'] = parsedPrice;
  //     _priceControllers[index].text = parsedPrice.toStringAsFixed(2);
  //   });
  // }

  // void _updateLineQuantity(int index, String newQty) {
  //   final parsedQty =
  //       int.tryParse(newQty) ?? tempOrderLines[index]['product_uom_qty'];
  //   setState(() {
  //     tempOrderLines[index]['product_uom_qty'] = parsedQty;
  //     _quantityControllers[index].text = parsedQty.toString();
  //   });
  // }

  void _removeLine(int index) {
    setState(() {
      if (tempOrderLines[index]['id'] != null) {
        // Tambahkan ID ke daftar baris yang dihapus
        deletedOrderLines.add(tempOrderLines[index]['id']);
      }
      if (_noteControllers.containsKey(index)) {
        _noteControllers[index]!.dispose();
        _noteControllers.remove(index);
      }
      // Hapus baris dari daftar terkait
      tempOrderLines.removeAt(index);
      _quantityControllers.removeAt(index);
      _priceControllers.removeAt(index);
    });
  }

  // void _toggleEditMode() {
  //   setState(() {
  //     isEditLineMode = !isEditLineMode;
  //     if (isEditLineMode) {
  //       // Masuk ke mode edit: Salin data ke editOrderLines
  //       editOrderLines = List<Map<String, dynamic>>.from(tempOrderLines);
  //     } else {
  //       // Keluar mode edit: Kembalikan data dari editOrderLines
  //       tempOrderLines = List<Map<String, dynamic>>.from(editOrderLines);
  //       _quantityControllers = tempOrderLines
  //           .map((line) =>
  //               TextEditingController(text: line['product_uom_qty'].toString()))
  //           .toList();
  //       _priceControllers = tempOrderLines
  //           .map((line) => TextEditingController(
  //               text: line['price_unit'].toStringAsFixed(2)))
  //           .toList();
  //     }
  //   });
  // }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final currentQty = tempOrderLines[index]['product_uom_qty'] ?? 0;
      // Make sure we're working with int values
      int intCurrentQty =
          currentQty is double ? currentQty.toInt() : currentQty;
      final newQty = intCurrentQty + delta;

      if (newQty > 0) {
        tempOrderLines[index]['product_uom_qty'] = newQty; // Store as int
        _quantityControllers[index].text = newQty.toString();
      } else {
        _removeLine(index);
      }
    });
  }

  void _showAddProductDialog() async {
    try {
      // Fetch daftar produk
      final products = await widget.odooService.fetchProducts();

      // State lokal untuk pencarian
      List<Map<String, dynamic>> filteredProducts = List.from(products);
      final searchController = TextEditingController();

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              "Select Product",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            content: StatefulBuilder(
              builder: (context, setState) {
                return SizedBox(
                  width: double.maxFinite,
                  height: 400.0,
                  child: Column(
                    children: [
                      // Search TextField
                      TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search Product',
                          hintText: 'Enter product name or code',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (query) {
                          setState(() {
                            filteredProducts = products.where((product) {
                              final nameMatch = product['name']
                                  .toString()
                                  .toLowerCase()
                                  .contains(query.toLowerCase());
                              final codeMatch = product['default_code'] != null
                                  ? product['default_code']
                                      .toString()
                                      .toLowerCase()
                                      .contains(query.toLowerCase())
                                  : false;
                              return nameMatch || codeMatch;
                            }).toList();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Filtered Product List
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return ListTile(
                              title: Text(
                                '[${product['default_code']}] ${product['name']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                'Price: ${currencyFormatter.format(product['list_price'] ?? 0.0)}\n'
                                'Available: ${product['qty_available']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle,
                                    color: Colors.green),
                                onPressed: () {
                                  Navigator.of(context).pop({
                                    'id': null,
                                    'product_id': product['id'],
                                    'name':
                                        '[${product['default_code']}] ${product['name']}',
                                    'product_uom_qty': 1,
                                    'price_unit': product['list_price'],
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ).then((result) {
        if (result != null) {
          _addProduct(result);
        }
        searchController.dispose(); // Dispose the search controller after use
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading products: $e')),
      );
    }
  }

  void _cancelEditMode() {
    setState(() {
      isEditLineMode = false;
      tempOrderLines = List.from(editOrderLines);
      _quantityControllers = tempOrderLines
          .map((line) =>
              TextEditingController(text: line['product_uom_qty'].toString()))
          .toList();
      _priceControllers = tempOrderLines
          .map((line) => TextEditingController(
              text: line['price_unit'].toStringAsFixed(2)))
          .toList();
      _noteControllers.clear(); // Clear note controllers
    });
  }

  @override
  void dispose() {
    for (var controller in _quantityControllers) {
      controller.dispose();
    }
    for (var controller in _priceControllers) {
      controller.dispose();
    }
    _noteControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  // void _addLineNote() {
  //   // Create a text controller for the note
  //   final noteController = TextEditingController();

  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: const Text(
  //           "Add Note Line",
  //           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
  //         ),
  //         content: TextField(
  //           controller: noteController,
  //           decoration: const InputDecoration(
  //             labelText: 'Note Content',
  //             hintText: 'Enter your note here...',
  //           ),
  //           maxLines: 3,
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //             child: const Text('Cancel'),
  //           ),
  //           TextButton(
  //             onPressed: () {
  //               if (noteController.text.trim().isNotEmpty) {
  //                 setState(() {
  //                   tempOrderLines.add({
  //                     'id': null,
  //                     'display_type': 'line_note',
  //                     'name': noteController.text,
  //                     'product_uom_qty': 0, // Not needed for notes
  //                     'price_unit': 0.0, // Not needed for notes
  //                   });

  //                   // Add dummy controllers to maintain index consistency
  //                   _quantityControllers.add(TextEditingController(text: '0'));
  //                   _priceControllers.add(TextEditingController(text: '0.0'));
  //                 });
  //                 Navigator.of(context).pop();
  //               }
  //             },
  //             child: const Text('Add'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _navigateToSaleOrderList(); // Handle  hardware back button
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Quotation Details",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          centerTitle: true,
          backgroundColor: Colors.blue[300],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _navigateToSaleOrderList, // Custom back button behavior
          ),
          actions: [
            FutureBuilder<Map<String, dynamic>>(
              future: quotationDetails,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    !snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                final status = snapshot.data!['state'] ?? '';
                final List<Widget> actions = [];
                if (status == 'draft') {
                  actions.addAll([
                    // IconButton(
                    //   icon: const Icon(Icons.check, color: Colors.white),
                    //   onPressed: _confirmQuotation,
                    //   tooltip: 'Confirm',
                    // ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () async {
                        final data = await quotationDetails;
                        _showEditHeaderDialog(data);
                      },
                      tooltip: 'Edit',
                    ),
                    // IconButton(
                    //   icon: const Icon(Icons.close, color: Colors.white),
                    //   onPressed: _cancelQuotation,
                    //   tooltip: 'Cancel',
                    // ),
                  ]);
                }
                if (status == 'cancel') {
                  actions.add(
                    IconButton(
                      icon: const Icon(Icons.undo, color: Colors.white),
                      onPressed: _setToQuotation,
                      tooltip: 'Set to Quotation',
                    ),
                  );
                }

                return Row(children: actions);
              },
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: quotationDetails,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: Text('No data found.'));
            }
            final data = snapshot.data!;
            final customerName = data['partner_id']?[1] ?? 'Unknown';
            final deliveryAddress =
                data['partner_shipping_id']?[1] ?? 'Unknown';
            final invoiceAddress = data['partner_invoice_id']?[1] ?? 'Unknown';
            final dateOrder = data['date_order'] ?? 'Unknown';
            final notes = data['notes'] ?? '';
            final vat = (data['vat'] is String && data['vat']!.isNotEmpty)
                ? data['vat']
                : '';
            final orderLineIds = List<int>.from(data['order_line'] ?? []);
            final untaxedAmount = data['amount_untaxed'] ?? 0.0;
            final totalCost = data['amount_total'] ?? 0.0;
            final totalTax = totalCost - untaxedAmount;
            final state = data['state'] ?? 'Unknown';

            orderLines = widget.odooService.fetchOrderLines(orderLineIds);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Name and Status
                      Expanded(
                        child: Text(
                          '${data['name']}',
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
                          color: _getStatusColor(state),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          state.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Table(
                    columnWidths: const {
                      0: IntrinsicColumnWidth(), // Kolom label
                      1: FixedColumnWidth(12), // Kolom titik dua
                    },
                    children: [
                      TableRow(children: [
                        const Text('Customer', style: TextStyle(fontSize: 12)),
                        const Text(' :', style: TextStyle(fontSize: 12)),
                        Text(customerName,
                            style: const TextStyle(fontSize: 12)),
                      ]),
                      TableRow(children: [
                        const Text('Invoice Address',
                            style: TextStyle(fontSize: 12)),
                        const Text(' :', style: TextStyle(fontSize: 12)),
                        Text(invoiceAddress,
                            style: const TextStyle(fontSize: 12)),
                      ]),
                      TableRow(children: [
                        const Text('NPWP', style: TextStyle(fontSize: 12)),
                        const Text(' :', style: TextStyle(fontSize: 12)),
                        Text(vat, style: const TextStyle(fontSize: 12)),
                      ]),
                      TableRow(children: [
                        const Text('Delivery Address',
                            style: TextStyle(fontSize: 12)),
                        const Text(' :', style: TextStyle(fontSize: 12)),
                        Text(deliveryAddress,
                            style: const TextStyle(fontSize: 12)),
                      ]),
                      TableRow(children: [
                        const Text('Date', style: TextStyle(fontSize: 12)),
                        const Text(' :', style: TextStyle(fontSize: 12)),
                        Text(dateOrder, style: const TextStyle(fontSize: 12)),
                      ]),
                      TableRow(children: [
                        const Text('Note', style: TextStyle(fontSize: 12)),
                        const Text(' :', style: TextStyle(fontSize: 12)),
                        Text(
                          (snapshot.data!['notes'] is String)
                              ? snapshot.data!['notes']
                              : '',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ]),
                      if (state != 'draft' && state != 'cancel')
                        TableRow(children: [
                          const Text('Delivery Order',
                              style: TextStyle(fontSize: 12)),
                          const Text(' :', style: TextStyle(fontSize: 12)),
                          FutureBuilder<String>(
                            future: deliveryOrderStatus,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Text('Loading...',
                                    style: TextStyle(fontSize: 12));
                              }
                              if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}',
                                    style: TextStyle(fontSize: 12));
                              }
                              final deliveryStatus =
                                  snapshot.data ?? 'Not Found';
                              return Wrap(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 0),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(deliveryStatus),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _mapDeliveryStatus(deliveryStatus),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                        ]),
                      if (state != 'draft' && state != 'cancel')
                        TableRow(children: [
                          const Text('Invoice', style: TextStyle(fontSize: 12)),
                          const Text(' :', style: TextStyle(fontSize: 12)),
                          FutureBuilder<String>(
                            future: invoiceStatus,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Text('Loading...',
                                    style: TextStyle(fontSize: 12));
                              }
                              if (snapshot.hasError) {
                                return const Text('Error',
                                    style: TextStyle(fontSize: 12));
                              }
                              final invoiceState = snapshot.data ?? 'Not Found';
                              return Wrap(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 0),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(invoiceState),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _mapInvoiceStatus(invoiceState),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ]),
                    ],
                  ),
                  const Divider(height: 16, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Order Lines",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (isEditLineMode)
                        Row(
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.add_box, color: Colors.blue),
                              onPressed: _showAddProductDialog,
                              tooltip: 'Add Product',
                            ),
                            IconButton(
                              icon: const Icon(Icons.save, color: Colors.green),
                              onPressed: _saveChanges,
                              tooltip: 'Save Changes',
                            ),
                            IconButton(
                              icon: const Icon(Icons.undo_rounded,
                                  color: Colors.red),
                              onPressed: _cancelEditMode,
                              tooltip: 'Cancel Edit',
                            ),
                          ],
                        ),
                      if (!isEditLineMode && state == 'draft')
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            await _loadOrderLines();
                            setState(() {
                              isEditLineMode = true;
                            });
                          },
                          tooltip: 'Edit Order Lines',
                        ),
                    ],
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: isEditLineMode
                        ? ListView.builder(
                            itemCount: tempOrderLines.length,
                            itemBuilder: (context, index) {
                              if (index >= _priceControllers.length ||
                                  index >= tempOrderLines.length) {
                                return const SizedBox();
                              }
                              final line = tempOrderLines[index];
                              final name = line['name'] ?? 'No Description';
                              final isNoteLine =
                                  line['display_type'] == 'line_note';
                              if (isNoteLine) {
                                if (!_noteControllers.containsKey(index)) {
                                  _noteControllers[index] =
                                      TextEditingController(text: name);
                                }
                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  color: Colors.amber[50],
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: TextField(
                                            controller: _noteControllers[index],
                                            maxLines: 3,
                                            decoration: const InputDecoration(
                                              labelText: 'Note Content',
                                              border: OutlineInputBorder(),
                                            ),
                                            style:
                                                const TextStyle(fontSize: 12),
                                            onChanged: (value) {
                                              setState(() {
                                                tempOrderLines[index]['name'] =
                                                    value;
                                              });
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () => _removeLine(index),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              } else {
                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 1,
                                              child: TextField(
                                                controller:
                                                    _priceControllers[index],
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                        labelText: 'Price'),
                                                style: const TextStyle(
                                                    fontSize: 12),
                                                onChanged: (value) {
                                                  final parsedPrice =
                                                      double.tryParse(value) ??
                                                          tempOrderLines[index]
                                                              ['price_unit'];
                                                  setState(() {
                                                    tempOrderLines[index]
                                                            ['price_unit'] =
                                                        parsedPrice;
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              flex: 1,
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.remove_circle,
                                                        color: Colors.red),
                                                    onPressed: () =>
                                                        _updateQuantity(
                                                            index, -1),
                                                  ),
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          _quantityControllers[
                                                              index],
                                                      keyboardType:
                                                          TextInputType.number,
                                                      inputFormatters: [
                                                        FilteringTextInputFormatter
                                                            .digitsOnly
                                                      ],
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                          fontSize: 12),
                                                      onChanged: (value) {
                                                        if (value.isNotEmpty) {
                                                          final parsedQty =
                                                              int.parse(value);
                                                          setState(() {
                                                            tempOrderLines[
                                                                        index][
                                                                    'product_uom_qty'] =
                                                                parsedQty;
                                                          });
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.add_circle,
                                                        color: Colors.green),
                                                    onPressed: () =>
                                                        _updateQuantity(
                                                            index, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red),
                                              onPressed: () =>
                                                  _removeLine(index),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: _noteControllers[index],
                                          decoration: const InputDecoration(
                                            labelText: 'Notes',
                                            border: OutlineInputBorder(),
                                          ),
                                          style: const TextStyle(fontSize: 12),
                                          maxLines: 2,
                                          onChanged: (value) {
                                            setState(() {
                                              tempOrderLines[index]['notes'] =
                                                  value;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            },
                          )
                        : FutureBuilder<List<Map<String, dynamic>>>(
                            future: orderLines,
                            builder: (context, lineSnapshot) {
                              if (lineSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              if (lineSnapshot.hasError) {
                                return Center(
                                    child:
                                        Text('Error: ${lineSnapshot.error}'));
                              }
                              if (!lineSnapshot.hasData ||
                                  lineSnapshot.data!.isEmpty) {
                                return const Center(
                                    child: Text('No order lines.'));
                              }
                              final lines = lineSnapshot.data!;
                              return ListView.builder(
                                itemCount: lines.length,
                                itemBuilder: (context, index) {
                                  final line = lines[index];
                                  final isNoteLine =
                                      line['display_type'] == 'line_note';
                                  if (isNoteLine) {
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      color: Colors.amber[50],
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Text(
                                          line['name'] ?? 'No Note',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    );
                                  } else {
                                    final qty = line['product_uom_qty'] ?? 0;
                                    final taxName =
                                        line['tax_name'] ?? 'No Tax';
                                    final price = line['price_unit'] ?? 0.0;
                                    final subtotal = line['price_total'] ?? 0.0;
                                    final productImageBase64 =
                                        line['image_1920'];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      child: ListTile(
                                        leading: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: productImageBase64 != null &&
                                                  productImageBase64 is String
                                              ? Image.memory(
                                                  base64Decode(
                                                      productImageBase64),
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return const Icon(
                                                        Icons.broken_image,
                                                        size: 50);
                                                  },
                                                )
                                              : const Icon(
                                                  Icons.image_not_supported,
                                                  size: 50),
                                        ),
                                        title: Text(
                                            line['name'] ?? 'No Description',
                                            style:
                                                const TextStyle(fontSize: 12)),
                                        subtitle: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 1),
                                          child: Table(
                                            columnWidths: const {
                                              0: IntrinsicColumnWidth(),
                                              1: FixedColumnWidth(12),
                                            },
                                            children: [
                                              TableRow(children: [
                                                const Text('Qty',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                                const Text(' : ',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                                Text(
                                                  qty is double
                                                      ? qty.toInt().toString()
                                                      : qty.toString(),
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                              ]),
                                              TableRow(children: [
                                                const Text('Price',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                                const Text(' : ',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                                Text(
                                                    currencyFormatter
                                                        .format(price),
                                                    style: const TextStyle(
                                                        fontSize: 12)),
                                              ]),
                                              TableRow(children: [
                                                const Text('Taxes',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                                const Text(' : ',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                                Text(taxName.toString(),
                                                    style: const TextStyle(
                                                        fontSize: 12)),
                                              ]),
                                              TableRow(children: [
                                                const Text('Notes',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                                const Text(' : ',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                                Text(
                                                  (line['notes'] is String &&
                                                          line['notes'] !=
                                                              false &&
                                                          line['notes'] != true)
                                                      ? line['notes']
                                                      : '',
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                              ]),
                                              TableRow(children: [
                                                const Text('Subtotal',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                                const Text(' : ',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                                Text(
                                                    currencyFormatter
                                                        .format(subtotal),
                                                    style: const TextStyle(
                                                        fontSize: 12)),
                                              ]),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 16, thickness: 1),
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Untaxed Amount:',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  currencyFormatter.format(untaxedAmount),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'PPN:',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  currencyFormatter.format(totalTax),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total:',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  currencyFormatter.format(totalCost),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
