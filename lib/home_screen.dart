// ignore_for_file: unused_field

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'odoo_service.dart';
import 'product_detail_screen.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  final OdooService odooService;

  const HomeScreen({Key? key, required this.odooService}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _productLimit = 25; // Jumlah produk per halaman
  int _productOffset = 0;
  bool _hasMoreProducts = true;
  bool _isLoadingMore = false;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId; // ID kategori yang dipilih
  bool _isGridView = true;
  bool _isCategoryLoading = false; // Status loading kategori
  final TextEditingController _searchController = TextEditingController();
  late ScrollController _scrollController;
  Timer? _searchDebounce; // Tambahkan deklarasi
  bool _isFirstLoad = false; // Tambahkan variabel ini

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onProductScroll);
    _loadFromCache().then((_) {
      if (_products.isEmpty) {
        _initializeProducts();
      }
    });
    _initializeCategories();
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        _filterProducts(_searchController.text);
      });
    });
  }

  Future<void> _saveProductsToCache(List<Map<String, dynamic>> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(products.map((p) => p).toList());
      await prefs.setString('cached_products', encoded);
      await prefs.setInt(
          'cache_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error saving cache: $e');
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString('cached_products');
      final timestamp = prefs.getInt('cache_timestamp');

      if (encoded != null && timestamp != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final cacheDuration = 30 * 60 * 1000; // 30 menit
        if (now - timestamp < cacheDuration) {
          final products = jsonDecode(encoded).cast<Map<String, dynamic>>();
          setState(() {
            _products = products;
            _filteredProducts = products;
          });
        }
      }
    } catch (e) {
      print('Error loading cache: $e');
      // Fallback ke fetch data dari server
      _initializeProducts();
    }
  }

  void _onProductScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore &&
        _hasMoreProducts) {
      _initializeProducts(
        categoryId: _selectedCategoryId,
        searchQuery: _searchController.text,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose(); // Bersihkan listener saat widget dihapus
    super.dispose();
  }

  void _initializeProducts({String? categoryId, String? searchQuery}) async {
  if (_isLoadingMore || !_hasMoreProducts) return;
  
  setState(() {
    _isLoadingMore = true;
    if (_products.isEmpty) _isFirstLoad = true;
  });

  try {
    // Create base domain for filtering products
    List<List<dynamic>> domain = [
      ['detailed_type', '=', 'product']
    ];

    // Add category filter if selected
    if (categoryId != null) {
      domain.add(['categ_id', '=', int.parse(categoryId)]);
    }

    // Track product IDs to prevent duplicates
    Set<int> productIds = _products.map((p) => p['id'] as int).toSet();

    // Handle search query if provided
    if (searchQuery?.isNotEmpty == true) {
      // First search by name
      List<List<dynamic>> nameDomain = List.from(domain);
      nameDomain.add(['name', 'ilike', searchQuery]);

      final nameProducts = await widget.odooService.fetchProductsTemplate(
        limit: _productLimit,
        offset: _productOffset,
        domain: nameDomain,
      );

      // Add non-duplicate products from name search
      List<Map<String, dynamic>> newProducts = [];
      for (var product in nameProducts) {
        int id = product['id'];
        if (!productIds.contains(id)) {
          productIds.add(id);
          newProducts.add(product);
        }
      }

      // If we need more products, search by default_code
      if (newProducts.length < _productLimit) {
        List<List<dynamic>> codeDomain = List.from(domain);
        codeDomain.add(['default_code', 'ilike', searchQuery]);

        final codeProducts = await widget.odooService.fetchProductsTemplate(
          limit: _productLimit * 2, // Fetch more to account for potential duplicates
          offset: _productOffset,
          domain: codeDomain,
        );

        // Add non-duplicate products from code search
        for (var product in codeProducts) {
          int id = product['id'];
          if (!productIds.contains(id)) {
            productIds.add(id);
            newProducts.add(product);
            // Stop once we reach the limit
            if (newProducts.length >= _productLimit) break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        // For the first page, replace products; for subsequent pages, append
        if (_productOffset == 0) {
          _products = newProducts;
          _filteredProducts = newProducts;
        } else {
          _products.addAll(newProducts);
          _filteredProducts = List.from(_products); // Create a new list to prevent reference issues
        }
        _productOffset += newProducts.length;
        _hasMoreProducts = newProducts.length == _productLimit;
        _isFirstLoad = false;
      });
      return;
    }

    // Standard product fetch (when no search query)
    final products = await widget.odooService.fetchProductsTemplate(
      limit: _productLimit,
      offset: _productOffset,
      domain: domain,
    );

    // Remove duplicates
    List<Map<String, dynamic>> newProducts = [];
    for (var product in products) {
      int id = product['id'];
      if (!productIds.contains(id)) {
        productIds.add(id);
        newProducts.add(product);
      }
    }

    if (!mounted) return;
    setState(() {
      if (_productOffset == 0) {
        _products = newProducts;
        _filteredProducts = newProducts;
      } else {
        _products.addAll(newProducts);
        _filteredProducts = List.from(_products); // Create a new list to prevent reference issues
      }
      _productOffset += newProducts.length;
      _hasMoreProducts = newProducts.length == _productLimit;
      _isFirstLoad = false;
    });

    if (categoryId == null && searchQuery == null) {
      await _saveProductsToCache(products);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }
}

  Future<void> _initializeCategories() async {
    setState(() {
      _isCategoryLoading = true;
    });

    try {
      final categories = await widget.odooService.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: $e')),
      );
    } finally {
      setState(() {
        _isCategoryLoading = false;
      });
    }
  }

  void _filterProducts(String query) {
    if (query.isEmpty && _selectedCategoryId == null) {
      setState(() {
        _productOffset = 0;
        _hasMoreProducts = true;
        _products.clear();
        _filteredProducts.clear();
      });
      _initializeProducts(); // Muat ulang semua produk
      return;
    }

    setState(() {
      _productOffset = 0;
      _hasMoreProducts = true;
      _products.clear();
      _filteredProducts.clear();
    });
    _initializeProducts(
      categoryId: _selectedCategoryId,
      searchQuery: query,
    );
  }

  void _filterProductsByCategory(String? categoryId) {
  setState(() {
    // Toggle kategori: jika sama, unselect
    _selectedCategoryId = (_selectedCategoryId == categoryId) ? null : categoryId;
    _productOffset = 0;
    _hasMoreProducts = true;
    _products = []; // Using clear array syntax instead of .clear()
    _filteredProducts = []; // Using clear array syntax instead of .clear()
  });
  
  // Use a slight delay to ensure the state is updated before fetching
  Timer(const Duration(milliseconds: 50), () {
    _initializeProducts(
      categoryId: _selectedCategoryId,
      searchQuery: _searchController.text,
    );
  });
}

  Widget _buildCategoryList() {
    if (_isCategoryLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SizedBox(
      height: 60, // Tinggi baris kategori
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategoryId == category['id'].toString();

          return GestureDetector(
            onTap: () {
              _filterProductsByCategory(category['id'].toString());
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[200] : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey,
                  width: 1.5,
                ),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Center(
                child: Text(
                  category['name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.blue[900] : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductListTile(Map<String, dynamic> product, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey,
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gambar Produk
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product['image_1920'] is String &&
                        product['image_1920'] != ''
                    ? Image.memory(
                        base64Decode(product['image_1920']),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.broken_image, size: 50);
                        },
                      )
                    : const Icon(Icons.image_not_supported, size: 50),
              ),
              const SizedBox(width: 10),
              // Informasi Produk
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama Produk
                    Text(
                      product['default_code'] != null &&
                              product['default_code'] != false
                          ? '[${product['default_code']}] ${product['name']}'
                          : product['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    // Harga
                    Text(
                      currencyFormatter.format(product['list_price'] ?? 0),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    // Ketersediaan
                    Text(
                      'Available : ${_formatQtyAvailable(product['qty_available'])}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductTile(Map<String, dynamic> product, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ProductDetailScreen(product: product),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8), // Tambahkan margin
        decoration: BoxDecoration(
          color: Colors.white, // Warna latar belakang card
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey, // Warna shadow
              blurRadius: 10, // Seberapa kabur shadow
              spreadRadius: 2, // Seberapa lebar shadow
              offset:
                  const Offset(0, 4), // Posisi shadow (horizontal, vertical)
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gambar Produk
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
                child: product['image_1920'] is String &&
                        product['image_1920'] != ''
                    ? Image.memory(
                        base64Decode(product['image_1920']),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.broken_image, size: 50);
                        },
                      )
                    : const Icon(Icons.image_not_supported, size: 50),
              ),
            ),
            // Informasi Produk
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nama Produk
                  Text(
                    product['default_code'] != null &&
                            product['default_code'] != false
                        ? '[${product['default_code']}] ${product['name']}'
                        : product['name'],
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  // Harga Produk
                  Text(
                    currencyFormatter.format(product['list_price'] ?? 0),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  // Ketersediaan Produk
                  Text(
                    'Available : ${_formatQtyAvailable(product['qty_available'])}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: const Duration(milliseconds: 500)).scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
            duration: const Duration(milliseconds: 500),
          ),
    );
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 1,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: TextField(
            controller: _searchController,
            onChanged: _filterProducts,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              hintText: 'Search products...',
              hintStyle: const TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(color: Colors.black),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.list : Icons.grid_view,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Categories Horizontal List
          _buildCategoryList(),
          if (_isFirstLoad)
            const LinearProgressIndicator()
          else
            Expanded(
              child: _filteredProducts.isEmpty && !_isLoadingMore
                  ? const Center(child: Text('No products found'))
                  : NotificationListener<ScrollNotification>(
                      onNotification: (scrollInfo) {
                        if (scrollInfo.metrics.pixels ==
                            scrollInfo.metrics.maxScrollExtent) {
                          _initializeProducts();
                        }
                        return false;
                      },
                      child: _isGridView
                          ? GridView.builder(
                              padding: const EdgeInsets.all(10),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent:
                                    200, // Lebar maksimal setiap tile/card
                                mainAxisSpacing: 10, // Jarak antar baris
                                crossAxisSpacing: 10, // Jarak antar kolom
                                childAspectRatio:
                                    0.7, // Rasio aspek tile (lebar:tinggi)
                              ),
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                return _buildProductTile(
                                    _filteredProducts[index], index);
                              },
                            )
                          : ListView.builder(
                              itemCount: _filteredProducts.length,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              itemBuilder: (context, index) {
                                return _buildProductListTile(
                                    _filteredProducts[index], index);
                              },
                            ),
                    ),
            ),
        ],
      ),
    );
  }
}
