import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'odoo_service.dart';
import 'dart:async';

class ProductSearchDialog extends StatefulWidget {
  final OdooService odooService;
  final Function(Map<String, dynamic>) onProductSelected;

  const ProductSearchDialog({
    Key? key,
    required this.odooService,
    required this.onProductSelected,
  }) : super(key: key);

  @override
  _ProductSearchDialogState createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<ProductSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  bool _hasMoreData = true;
  int _currentOffset = 0;
  final int _pageSize = 25;
  String _currentSearchQuery = '';
  final ScrollController _scrollController = ScrollController();
  late Timer _searchTimer; // Deklarasi tanpa inisialisasi
  final Duration _searchDebounce = const Duration(milliseconds: 500);

  void _onSearchChanged(String query) {
    if (_searchTimer.isActive) {
      _searchTimer.cancel(); // Batalkan timer aktif jika ada
    }
    _searchTimer = Timer(_searchDebounce, () => _performSearch(query));
  }

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _searchTimer = Timer(Duration.zero, () {}); // Inisialisasi awal
    _loadProducts();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    if (_searchTimer.isActive) {
      _searchTimer.cancel();
    }
    _searchController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Scroll listener for lazy loading
  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (!_isLoading && _hasMoreData) {
        _loadMoreProducts();
      }
    }
  }

  // Build the domain filter based on search query
  List<dynamic> _buildDomain() {
    List<dynamic> domain = [];

    // Jika tidak ada pencarian, cukup gunakan filter dasar
    if (_currentSearchQuery.isEmpty) {
      domain = [
        ['detailed_type', '=', 'product']
      ];
    } else {
      // Jika ada pencarian, struktur domain secara FLAT
      domain = [
        '&', // Operator AND
        ['detailed_type', '=', 'product'], // Kondisi 1
        '|', // Operator OR
        ['name', 'ilike', _currentSearchQuery], // Kondisi 2
        ['default_code', 'ilike', _currentSearchQuery] // Kondisi 3
      ];
    }

    print('Search domain: $domain'); // Debug log
    return domain;
  }

  // Initial load of products
  Future<void> _loadProducts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _products = []; // Clear existing products
      _currentOffset = 0;
    });

    try {
      final domain = _buildDomain();
      print('Loading products with domain: $domain');

      final fetchedProducts = await widget.odooService.fetchProducts(
        limit: _pageSize,
        offset: 0,
        domain: domain,
      );

      print('Fetched ${fetchedProducts.length} products');

      setState(() {
        _products = fetchedProducts;
        _hasMoreData = fetchedProducts.length == _pageSize;
        _currentOffset = fetchedProducts.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _loadProducts: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading products: $e')),
      );
    }
  }

  // Load more products when scrolling
  Future<void> _loadMoreProducts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final domain = _buildDomain();
      print('Loading more products with domain: $domain');

      final fetchedProducts = await widget.odooService.fetchProducts(
        limit: _pageSize,
        offset: _currentOffset,
        domain: domain,
      );

      print('Fetched ${fetchedProducts.length} more products');

      setState(() {
        _products.addAll(fetchedProducts);
        _hasMoreData = fetchedProducts.length == _pageSize;
        _currentOffset += fetchedProducts.length;
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _loadMoreProducts: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more products: $e')),
      );
    }
  }

  // Execute search
  void _performSearch(String query) {
    setState(() {
      _currentSearchQuery = query;
    });
    _loadProducts(); // Reset offset dan muat ulang data
  }

  String _formatQtyAvailable(dynamic value) {
    if (value == null) return '0';

    if (value is int) {
      return value.toString();
    } else if (value is double) {
      // Jika angka seperti 10.0, kembalikan sebagai integer
      if (value == value.toInt()) {
        return value.toInt().toString();
      } else {
        return value.toString();
      }
    } else if (value is String) {
      // Jika ternyata nilainya string, coba parse ke number
      final numVal = num.tryParse(value);
      if (numVal != null) {
        return numVal.toInt().toString();
      }
    }

    return '0'; // Default jika tidak cocok semua
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        "Select Product",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400.0,
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Search Product',
                hintText: 'Enter product name or code',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        _performSearch(_searchController.text);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    ),
                  ],
                ),
              ),
              onSubmitted: _performSearch,
            ),
            const SizedBox(height: 16),

            // Products list
            Expanded(
              child: _isLoading && _products.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                      ? const Center(child: Text('No products found'))
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _products.length + (_hasMoreData ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at the bottom while loading more
                            if (index == _products.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final product = _products[index];
                            final productImageBase64 = product['image_1920'];

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: productImageBase64 != null &&
                                          productImageBase64 is String &&
                                          productImageBase64.isNotEmpty
                                      ? Image.memory(
                                          base64Decode(productImageBase64),
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return const Icon(
                                                Icons.image_not_supported,
                                                size: 40);
                                          },
                                        )
                                      : const Icon(Icons.inventory_2, size: 40),
                                ),
                                title: Text(
                                  product['default_code'] != null
                                      ? '[${product['default_code']}] ${product['name']}'
                                      : product['name'],
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Text(
                                  'Price: ${currencyFormatter.format(product['list_price'] ?? 0.0)}\n'
                                  'Available : ${_formatQtyAvailable(product['qty_available'])}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle,
                                      color: Colors.green),
                                  onPressed: () {
                                    final productVariantId =
                                        product['product_variant_ids']
                                            [0]; // Ambil ID varian
                                    widget.onProductSelected({
                                      'id':
                                          null, // Will be assigned by the backend when created
                                      'product_id': productVariantId,
                                      'name': product['default_code'] != null
                                          ? '[${product['default_code']}] ${product['name']}'
                                          : product['name'],
                                      'product_uom_qty': 1,
                                      'price_unit':
                                          product['list_price'] ?? 0.0,
                                      'original_price':
                                          product['list_price'] ?? 0.0,
                                      'notes': '',
                                    });
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
