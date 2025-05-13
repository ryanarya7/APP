import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'odoo_service.dart';

class FormDetailQuotation extends StatefulWidget {
  final OdooService odooService;
  final Map<String, dynamic> headerData;

  const FormDetailQuotation({
    Key? key,
    required this.odooService,
    required this.headerData,
  }) : super(key: key);

  @override
  _FormDetailQuotationState createState() => _FormDetailQuotationState();
}

class _FormDetailQuotationState extends State<FormDetailQuotation> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];
  List<Map<String, dynamic>> quotationLines = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  Future<void> _loadProducts() async {
    try {
      final fetchedProducts = await widget.odooService.fetchProducts();
      setState(() {
        // Store all products in both lists
        products = List.from(fetchedProducts);
        filteredProducts = List.from(fetchedProducts);
      });
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      });
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredProducts = products.where((product) {
        // Ambil nilai name dan default_code dengan validasi
        final name = product['name']?.toLowerCase() ?? '';
        final code = product['default_code'];
        final lowerCaseCode =
            (code != null && code is String) ? code.toLowerCase() : '';

        // Pastikan nama atau kode cocok dengan query
        return name.contains(query) || lowerCaseCode.contains(query);
      }).toList();
    });
  }

  void _addProductLine(Map<String, dynamic> product) {
    setState(() {
      final existingIndex = quotationLines
          .indexWhere((line) => line['product_id'] == product['id']);
      if (existingIndex >= 0) {
        final availableQty = product['qty_available'];
        if (quotationLines[existingIndex]['product_uom_qty'] < availableQty) {
          quotationLines[existingIndex]['product_uom_qty'] += 1;
        }
      } else {
        quotationLines.add({
          'product_id': product['id'],
          'product_template_id': product['id'],
          'name': '[${product['default_code']}] ${product['name']}',
          'product_uom_qty': 1,
          'product_uom': product['uom_id'][0],
          'price_unit': product['list_price'],
          'qty_available': product['qty_available'],
          'image_1920': product['image_1920'],
          'price_controller': MoneyMaskedTextController(
            decimalSeparator: ',',
            thousandSeparator: '.',
            initialValue: product['list_price'] ?? 0.0,
            precision: 2,
          ),
          'notes': '',
          'notes_controller': TextEditingController(),
          'display_type': null,
        });
      }
    });
  }

  // void _addNote() {
  //   _noteController.clear(); // Clear previous note text
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Add a Note'),
  //         content: TextField(
  //           controller: _noteController,
  //           decoration: const InputDecoration(
  //             hintText: 'Enter your note here',
  //             border: OutlineInputBorder(),
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
  //               // Add the note to quotation lines
  //               if (_noteController.text.isNotEmpty) {
  //                 setState(() {
  //                   quotationLines.add({
  //                     'name': _noteController.text,
  //                     'display_type': 'line_note', // This is crucial for Odoo
  //                     // Note: Don't include product_id, product_uom, or other product-related fields
  //                   });
  //                 });
  //               }
  //               Navigator.of(context).pop();
  //             },
  //             child: const Text('Add'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  void _updateQuantity(int index, int delta) {
    setState(() {
      // Only update quantity for product lines, not notes
      if (quotationLines[index]['display_type'] != 'line_note') {
        final currentQty = quotationLines[index]['product_uom_qty'] ?? 0;
        // final maxQty =
        //     quotationLines[index]['qty_available'] ?? double.infinity;
        final newQty = currentQty + delta;

        if (newQty > 0) {
          quotationLines[index]['product_uom_qty'] = newQty;
        } else if (newQty <= 0) {
          _removeLine(index);
        }
      }
    });
  }

  // void _updatePriceUnit(int index, String newPrice) {
  //   setState(() {
  //     quotationLines[index]['price_unit'] =
  //         double.tryParse(newPrice) ?? quotationLines[index]['price_unit'];
  //   });
  // }

  void _removeLine(int index) {
    setState(() {
      quotationLines.removeAt(index);
    });
  }

  void _editNote(int index, String currentNote) {
    _noteController.text = currentNote;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Note'),
          content: TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Update the note
                if (_noteController.text.isNotEmpty) {
                  setState(() {
                    quotationLines[index]['name'] = _noteController.text;
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveQuotationLines() async {
    // Validasi harga sebelum menyimpan
    bool isPriceValid = true;
    List<String> invalidPriceMessages = [];

    for (int index = 0; index < quotationLines.length; index++) {
      // Skip validation for note lines
      if (quotationLines[index]['display_type'] == 'line_note') {
        continue;
      }

      // Sinkronkan nilai dari controller ke quotationLines
      final currentLine = quotationLines[index];
      final controllerValue = currentLine['price_controller'].numberValue;
      final originalPrice = currentLine['price_unit'];

      if (controllerValue < originalPrice) {
        isPriceValid = false;
        invalidPriceMessages.add(
            'Produk ${currentLine['name']} tidak bisa diturunkan harganya. Harga minimal adalah ${currencyFormatter.format(originalPrice)}');
      } else {
        // Update price_unit dengan nilai dari controller
        currentLine['price_unit'] = controllerValue;
      }
      if (currentLine.containsKey('notes_controller')) {
        currentLine['notes'] = currentLine['notes_controller'].text;
      }
    }

    // Jika ada harga yang tidak valid, tampilkan dialog
    if (!isPriceValid) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Peringatan Harga'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: invalidPriceMessages
                .map((message) => Text(
                      message,
                      style: const TextStyle(color: Colors.red),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      return; // Hentikan proses penyimpanan
    }

    try {
      // Proses penyimpanan jika semua harga valid
      for (var line in quotationLines) {
        // Create a clean copy without controller objects
        Map<String, dynamic> cleanLine = {...line};
        if (cleanLine.containsKey('price_controller')) {
          cleanLine.remove('price_controller');
        }
        if (cleanLine.containsKey('notes_controller')) {
          cleanLine.remove('notes_controller');
        }

        await widget.odooService
            .addQuotationLine(widget.headerData['quotationId'], cleanLine);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quotation lines saved successfully!')),
      );

      Navigator.pushNamed(
        context,
        '/quotationDetail',
        arguments: widget.headerData['quotationId'],
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving quotation lines: $e')),
      );
    }
  }

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID', // Format Indonesia
    symbol: 'Rp ', // Simbol Rupiah
    decimalDigits: 2,
  );

  String _formatQty(dynamic value) {
    if (value == null) return '0';

    if (value is int) {
      return value.toString();
    } else if (value is double) {
      // Jika nilainya seperti 10.0, ubah jadi 10
      if (value == value.toInt()) {
        return value.toInt().toString();
      }
      return value.toString();
    } else if (value is String) {
      // Jika berupa string, coba parse ke number
      final numVal = num.tryParse(value);
      if (numVal != null) {
        return numVal.toInt().toString();
      }
    }

    return '0'; // Default jika tidak cocok semua
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Search products...",
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(color: Colors.black),
          cursorColor: Colors.black,
        ),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  final productImageBase64 = product['image_1920'];
                  return Card(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            8), // Membulatkan sudut gambar
                        child: productImageBase64 != null &&
                                productImageBase64 is String
                            ? Image.memory(
                                base64Decode(productImageBase64),
                                width: 50, // Lebar gambar
                                height: 50, // Tinggi gambar
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.broken_image,
                                    size:
                                        50, // Jika terjadi kesalahan, tampilkan ikon
                                  );
                                },
                              )
                            : const Icon(
                                Icons.image_not_supported,
                                size: 50, // Placeholder jika gambar tidak ada
                              ),
                      ),
                      title: Text(
                        "[${product['default_code']}] ${product['name']}",
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                      subtitle: Text(
                          "${currencyFormatter.format(product['list_price'])} | Available: ${_formatQty(product['qty_available'])}",
                          style: const TextStyle(
                            fontSize: 12,
                          )),
                      trailing: IconButton(
                        icon: const Icon(Icons.add, color: Colors.blue),
                        onPressed: () => _addProductLine(product),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 5),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Order Lines",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    )),
                // Add Note button
                // IconButton(
                //   icon: const Icon(Icons.note_add, color: Colors.blue),
                //   tooltip: 'Add a note',
                //   onPressed: _addNote,
                // ),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: quotationLines.length,
                itemBuilder: (context, index) {
                  final line = quotationLines[index];
                  final productImageBase64 =
                      line['image_1920']; // Gambar produk

                  if (line['display_type'] == 'line_note') {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      color: Colors
                          .yellow[100], // Light yellow background for notes
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.note, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                line['name'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editNote(index, line['name']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeLine(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nama produk di bagian atas
                          Text(
                            line['name'],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(
                              height: 8), // Jarak antara nama dan baris kedua
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Kolom Kiri
                              Row(
                                children: [
                                  // Gambar Produk
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: productImageBase64 != null &&
                                            productImageBase64 is String
                                        ? Image.memory(
                                            base64Decode(productImageBase64),
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.broken_image,
                                                size:
                                                    50, // Jika error, tampilkan ikon ini
                                              );
                                            },
                                          )
                                        : const Icon(
                                            Icons.image_not_supported,
                                            size:
                                                50, // Placeholder jika gambar tidak ada
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        "Rp ",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: TextField(
                                          controller: line['price_controller'],
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(fontSize: 12),
                                          onChanged: (value) {
                                            setState(() {
                                              // Jika kolom kosong, atur teks menjadi "0"
                                              if (value.isEmpty) {
                                                line['price_controller'].text =
                                                    "0,00";
                                                line['price_controller']
                                                        .selection =
                                                    TextSelection.fromPosition(
                                                  TextPosition(
                                                      offset: line[
                                                              'price_controller']
                                                          .text
                                                          .length),
                                                );
                                              } else {
                                                // Perbarui posisi kursor untuk teks yang valid
                                                final cursorPosition =
                                                    line['price_controller']
                                                        .selection
                                                        .start;
                                                line['price_controller'].text =
                                                    line['price_controller']
                                                        .text;
                                                line['price_controller']
                                                        .selection =
                                                    TextSelection.fromPosition(
                                                  TextPosition(
                                                      offset: cursorPosition),
                                                );
                                              }
                                            });
                                          },
                                          onSubmitted: (value) {
                                            // Tetapkan nilai price_unit saat selesai mengedit
                                            final parsedPrice =
                                                line['price_controller']
                                                    .numberValue;
                                            setState(() {
                                              quotationLines[index]
                                                  ['price_unit'] = parsedPrice;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                              Row(
                                children: [
                                  // Tombol (-)
                                  IconButton(
                                    icon: Icon(
                                      Icons.remove_circle,
                                      color: (line['product_uom_qty'] ?? 0) > 0
                                          ? Colors.red
                                          : Colors.grey,
                                    ),
                                    onPressed:
                                        (line['product_uom_qty'] ?? 0) > 0
                                            ? () => _updateQuantity(index, -1)
                                            : null,
                                  ),
                                  // Kuantitas
                                  SizedBox(
                                    width: 40,
                                    child: TextField(
                                      controller: TextEditingController(
                                        text: (line['product_uom_qty'] ?? 0)
                                            .toString(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true, // Kurangi padding
                                      ),
                                      onSubmitted: (value) {
                                        final parsedQty = int.tryParse(value) ??
                                            line['product_uom_qty'];
                                        setState(() {
                                          quotationLines[index]
                                              ['product_uom_qty'] = parsedQty;
                                        });
                                      },
                                      onChanged: (value) {
                                        final parsedQty = int.tryParse(value) ??
                                            line['product_uom_qty'];
                                        setState(() {
                                          quotationLines[index]
                                              ['product_uom_qty'] = parsedQty;
                                        });
                                      },
                                    ),
                                  ),
                                  // Tombol (+)
                                  IconButton(
                                    icon: Icon(
                                      Icons.add_circle,
                                      color: Colors
                                          .green, // Selalu hijau karena tidak ada pengecekan
                                    ),
                                    onPressed: () => _updateQuantity(
                                        index, 1), // Selalu aktif
                                  ),
                                  // Tombol Delete
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _removeLine(index),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Tambahkan field notes di bawah
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            child: TextField(
                              controller: line['notes_controller'] ??
                                  TextEditingController(),
                              decoration: const InputDecoration(
                                hintText: "Add notes for this product...",
                                prefixIcon: Icon(Icons.notes,
                                    size: 16, color: Colors.grey),
                                hintStyle: TextStyle(
                                    fontSize: 12, fontStyle: FontStyle.italic),
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 8.0),
                                border: UnderlineInputBorder(),
                              ),
                              style: const TextStyle(fontSize: 12),
                              onChanged: (value) {
                                setState(() {
                                  quotationLines[index]['notes'] = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Save Button
            Center(
              child: ElevatedButton(
                onPressed: _saveQuotationLines,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text("Save Quotation Lines",
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
