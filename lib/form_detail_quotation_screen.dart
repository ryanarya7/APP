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
  List<Map<String, dynamic>> quotationLines = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  // Lazy loading properties
  bool _isLoading = false;
  bool _hasMoreProducts = true;
  int _currentOffset = 0;
  final int _productsPerPage = 20;

  // Search mode tracking
  bool _isSearchMode = false;
  String _lastSearchQuery = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialProducts();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Listener for scroll events to implement lazy loading
  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      if (!_isLoading && _hasMoreProducts) {
        if (_isSearchMode) {
          _searchProducts(_lastSearchQuery, loadMore: true);
        } else {
          _loadMoreProducts();
        }
      }
    }
  }

  // Debounced search function
  int _searchDebounce = 0;
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _lastSearchQuery = query;

    // If search is empty, load regular products
    if (query.isEmpty) {
      setState(() {
        _isSearchMode = false;
        _currentOffset = 0;
      });
      _loadInitialProducts();
      return;
    }

    // Set search mode flag
    _isSearchMode = true;

    // Simple debounce implementation
    final currentDebounce = ++_searchDebounce;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (currentDebounce == _searchDebounce &&
          query == _searchController.text.trim()) {
        _searchProducts(query);
      }
    });
  }

  // Initial products load
  Future<void> _loadInitialProducts() async {
    if (_isSearchMode) return;

    setState(() {
      _isLoading = true;
      _currentOffset = 0;
      products = [];
    });

    try {
      final fetchedProducts = await widget.odooService.fetchProducts(
        limit: _productsPerPage,
        offset: 0,
      );

      setState(() {
        products = List.from(fetchedProducts);
        _isLoading = false;
        _hasMoreProducts = fetchedProducts.length == _productsPerPage;
        _currentOffset = fetchedProducts.length;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      });
    }
  }

  // Load more products when scrolling down (lazy loading)
  Future<void> _loadMoreProducts() async {
    if (_isLoading || !_hasMoreProducts || _isSearchMode) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final fetchedProducts = await widget.odooService.fetchProducts(
        limit: _productsPerPage,
        offset: _currentOffset,
      );

      setState(() {
        products.addAll(fetchedProducts);
        _isLoading = false;
        _hasMoreProducts = fetchedProducts.length == _productsPerPage;
        _currentOffset += fetchedProducts.length;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more products: $e')),
      );
    }
  }

  // Search products directly from the database
  Future<void> _searchProducts(String query, {bool loadMore = false}) async {
    if (_isLoading) return;

    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _currentOffset = 0;
        products = [];
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Create a domain that searches both name and default_code
      final searchDomain = [
        '&',
        ['detailed_type', '=', 'product'],
        '|',
        ['name', 'ilike', query],
        ['default_code', 'ilike', query]
      ];

      final fetchedProducts = await widget.odooService.fetchProducts(
        limit: _productsPerPage,
        offset: _currentOffset,
        domain: searchDomain,
      );

      setState(() {
        if (loadMore) {
          products.addAll(fetchedProducts);
        } else {
          products = List.from(fetchedProducts);
        }
        _isLoading = false;
        _hasMoreProducts = fetchedProducts.length == _productsPerPage;
        _currentOffset += fetchedProducts.length;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching products: $e')),
      );
    }
  }

  void _addProductLine(Map<String, dynamic> product) {
    // Check if product exists
    // ignore: unnecessary_null_comparison
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Error: Product does not exist or has been deleted.')),
      );
      return;
    }

    setState(() {
      // Get product ID safely, prefer variant ID if available
      int productId;
      if (product['product_variant_ids'] != null &&
          product['product_variant_ids'] is List &&
          product['product_variant_ids'].isNotEmpty) {
        productId = product['product_variant_ids'][0];
      } else {
        productId = product['id'];
      }

      // Check if product already exists in quotation lines
      final existingIndex =
          quotationLines.indexWhere((line) => line['product_id'] == productId);

      if (existingIndex >= 0) {
        final availableQty = product['qty_available'] ?? 0;
        final currentQty =
            quotationLines[existingIndex]['product_uom_qty'] ?? 0;

        if (currentQty < availableQty) {
          quotationLines[existingIndex]['product_uom_qty'] = currentQty + 1;
        }
      } else {
        // Create a direct product name
        final productName = product['name'] ?? 'Unknown Product';
        final defaultCode = product['default_code'];
        final formattedName = (defaultCode != null &&
                defaultCode is String &&
                defaultCode.isNotEmpty)
            ? '[$defaultCode] $productName'
            : productName;

        // Get UOM ID safely
        int productUomId = 1; // Default value
        if (product['uom_id'] != null &&
            product['uom_id'] is List &&
            product['uom_id'].isNotEmpty) {
          productUomId = product['uom_id'][0];
        }

        // Get price safely
        final priceUnit = product['list_price'] ?? 0.0;

        quotationLines.add({
          'product_id': productId,
          'product_template_id': product['id'],
          'name': formattedName,
          'product_uom_qty': 1,
          'product_uom': productUomId,
          'price_unit': priceUnit,
          'qty_available': product['qty_available'] ?? 0,
          'image_1920': product['image_1920'],
          // Using a simple TextEditingController instead of MoneyMaskedTextController
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
          decoration: const InputDecoration(
            hintText: "Search products by name or code...",
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
              child: Stack(
                children: [
                  // Products list
                  ListView.builder(
                    controller: _scrollController,
                    itemCount: products.length + (_hasMoreProducts ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show loading indicator at the end
                      if (index == products.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final product = products[index];
                      final productImageBase64 = product['image_1920'];
                      return Card(
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: productImageBase64 != null &&
                                    productImageBase64 is String
                                ? Image.memory(
                                    base64Decode(productImageBase64),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.broken_image,
                                        size: 50,
                                      );
                                    },
                                  )
                                : const Icon(
                                    Icons.image_not_supported,
                                    size: 50,
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

                  // Initial loading overlay
                  if (_isLoading && products.isEmpty)
                    Container(
                      color: Colors.white.withOpacity(0.7),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
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
                  final productImageBase64 = line['image_1920'];

                  if (line['display_type'] == 'line_note') {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      color: Colors.yellow[100],
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
                          Text(
                            line['name'],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
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
                                                size: 50,
                                              );
                                            },
                                          )
                                        : const Icon(
                                            Icons.image_not_supported,
                                            size: 50,
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
                                        isDense: true,
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
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: Colors.green,
                                    ),
                                    onPressed: () => _updateQuantity(index, 1),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _removeLine(index),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
