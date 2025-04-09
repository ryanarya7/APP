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
  List<Map<String, dynamic>> filteredProducts = []; // Produk yang difilter
  List<Map<String, dynamic>> quotationLines = [];
  final TextEditingController _searchController =
      TextEditingController(); // Controller untuk search bar

  @override
  void initState() {
    super.initState();
    _loadProducts();

    // Listener untuk Search Bar
    _searchController.addListener(_filterProducts);
  }

  Future<void> _loadProducts() async {
    try {
      final fetchedProducts = await widget.odooService.fetchProducts();
      setState(() {
        // Filter products to exclude items with qty_available <= 0
        products =
            fetchedProducts.where((p) => p['qty_available'] > 0).toList();
        filteredProducts =
            List.from(products); // Salin semua produk ke list yang difilter
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading products: $e')),
      );
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
          'name': '${product['default_code']} ${product['name']}',
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
          ), // Tambahkan controller
        });
      }
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final currentQty = quotationLines[index]['product_uom_qty'] ?? 0;
      final maxQty = quotationLines[index]['qty_available'] ?? double.infinity;
      final newQty = currentQty + delta;

      if (newQty > 0 && newQty <= maxQty) {
        quotationLines[index]['product_uom_qty'] = newQty;
      } else if (newQty <= 0) {
        _removeLine(index);
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

  Future<void> _saveQuotationLines() async {
    // Validasi harga sebelum menyimpan
    bool isPriceValid = true;
    List<String> invalidPriceMessages = [];

    for (int index = 0; index < quotationLines.length; index++) {
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
        await widget.odooService
            .addQuotationLine(widget.headerData['quotationId'], line);
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
                          "${currencyFormatter.format(product['list_price'])} | Available: ${product['qty_available']}",
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

            const Text("Order Lines",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: quotationLines.length,
                itemBuilder: (context, index) {
                  final line = quotationLines[index];
                  final productImageBase64 =
                      line['image_1920']; // Gambar produk
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
                              fontSize: 14,
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
                                    width: 50,
                                    child: TextField(
                                      controller: TextEditingController(
                                        text: (line['product_uom_qty'] ?? 0)
                                            .toString(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
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
                                      color: (line['product_uom_qty'] ?? 0) <
                                              (line['qty_available'] ?? 0)
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                    onPressed: (line['product_uom_qty'] ?? 0) <
                                            (line['qty_available'] ?? 0)
                                        ? () => _updateQuantity(index, 1)
                                        : null,
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
