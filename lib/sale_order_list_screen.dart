import 'package:flutter/material.dart';
import 'odoo_service.dart';
import 'form_header_quotation_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SaleOrderListScreen extends StatefulWidget {
  final OdooService odooService;

  const SaleOrderListScreen({super.key, required this.odooService});

  @override
  State<SaleOrderListScreen> createState() => _SaleOrderListScreenState();
}

class _SaleOrderListScreenState extends State<SaleOrderListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _quotations = [];
  List<Map<String, dynamic>> _filteredQuotations = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _limit = 20;
  int _offset = 0;
  String _searchQuery = '';
  bool _isFilterVisible = false;
  int? _selectedMonth;
  int? _selectedYear;
  final List<int> _availableYears = [];
  final int _yearRangeStart = 2020;
  final int _yearRangeEnd = DateTime.now().year + 10;
  // ignore: unused_field
  DateTime? _lastCacheTime;
  final Duration _cacheDuration = const Duration(minutes: 30);
  bool _isSearching =
      false; // Flag untuk menandai apakah sedang dalam mode pencarian
  Set<int> _loadedIds = {}; // Set untuk melacak ID yang sudah dimuat

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initialize filter with current month and year
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;

    // Create list of available years (from start year to current year + 1)
    _availableYears.add(0); // For "All Years" option
    for (int i = _yearRangeStart; i <= _yearRangeEnd; i++) {
      _availableYears.add(i);
    }

    // Try to load from cache first
    _loadFromCache().then((_) {
      // If cache is empty, proceed with normal loading
      if (_quotations.isEmpty) {
        _loadQuotations();
      }
    });
  }

  String _getCacheKey() {
    return 'quotations_${_selectedMonth ?? 0}_${_selectedYear ?? 0}';
  }

  Future<void> _saveToCache(List<Map<String, dynamic>> data) async {
    if (data.isEmpty || !mounted) return;

    // Jangan simpan ke cache jika sedang dalam mode pencarian
    if (_isSearching) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();

      // Convert data to JSON string - handle potential serialization errors
      final List<String> jsonDataList = [];
      final Set<int> savedIds = {}; // Untuk menghindari duplikasi

      for (var item in data) {
        try {
          // Pastikan item memiliki ID dan belum disimpan sebelumnya
          if (item.containsKey('id') && !savedIds.contains(item['id'])) {
            jsonDataList.add(jsonEncode(item));
            savedIds.add(item['id']);
          }
        } catch (e) {
          print('Error encoding item for cache: $e');
          // Continue with other items
        }
      }

      if (jsonDataList.isEmpty) return; // Nothing to save

      // Save data and timestamp
      await prefs.setStringList(cacheKey, jsonDataList);
      await prefs.setString(
          '${cacheKey}_timestamp', DateTime.now().toIso8601String());

      _lastCacheTime = DateTime.now();
      print(
          'Data saved to cache with key: $cacheKey (${jsonDataList.length} items)');
    } catch (e) {
      print('Error saving to cache: $e');
    }
  }

  Future<void> _loadFromCache() async {
    if (!mounted) return;

    // Jangan muat dari cache jika sedang dalam mode pencarian
    if (_isSearching) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey();

      // Check if cache exists and is not expired
      final String? timestampStr = prefs.getString('${cacheKey}_timestamp');
      if (timestampStr != null) {
        final cacheTimestamp = DateTime.parse(timestampStr);
        final now = DateTime.now();

        if (now.difference(cacheTimestamp) < _cacheDuration) {
          // Cache is still valid
          final List<String>? jsonDataList = prefs.getStringList(cacheKey);

          if (jsonDataList != null && jsonDataList.isNotEmpty) {
            final List<Map<String, dynamic>> loadedData = [];
            final Set<int> uniqueIds = {}; // Set untuk mencegah duplikasi

            for (var jsonStr in jsonDataList) {
              try {
                final item = Map<String, dynamic>.from(jsonDecode(jsonStr));
                // Hanya tambahkan item jika ID-nya belum ada
                if (item.containsKey('id') && !uniqueIds.contains(item['id'])) {
                  loadedData.add(item);
                  uniqueIds.add(item['id']);
                  _loadedIds.add(item['id']); // Lacak ID yang sudah dimuat
                }
              } catch (e) {
                print('Error decoding cached item: $e');
              }
            }

            if (mounted && loadedData.isNotEmpty) {
              setState(() {
                _quotations = loadedData;
                _filteredQuotations = loadedData;
                _lastCacheTime = cacheTimestamp;
                print(
                    'Loaded ${loadedData.length} items from cache with key: $cacheKey');
              });
              return;
            }
          }
        } else {
          print('Cache expired for key: $cacheKey');
        }
      }
    } catch (e) {
      print('Error loading from cache: $e');
    }
  }

  Future<void> _updateInvoiceStatuses() async {
    if (_quotations.isEmpty) return;

    try {
      List<String> orderNames =
          _quotations.map((order) => order['name'].toString()).toList();

      Map<String, String> statusMap =
          await widget.odooService.fetchInvoiceStatusBatch(orderNames);

      if (mounted) {
        setState(() {
          for (var quotation in _quotations) {
            String orderName = quotation['name'];
            quotation['payment_state'] = statusMap[orderName];
          }
          _applyFiltersToQuotations();
        });
      }
    } catch (e) {
      print('Error updating invoice statuses: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID', // Format Indonesia
    symbol: 'Rp ', // Simbol Rupiah
    decimalDigits: 2,
  );

  Future<void> _loadQuotations({bool isRefreshing = false}) async {
    if (_isLoading || (!_hasMore && !isRefreshing)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (isRefreshing) {
        _quotations.clear();
        _filteredQuotations.clear();
        _loadedIds.clear(); // Reset ID yang sudah dimuat
        _offset = 0;
        _hasMore = true;
      }

      // Jika sedang dalam mode pencarian, gunakan parameter khusus
      final fetchedQuotations = await widget.odooService.fetchQuotations(
        limit: _limit,
        offset: _offset,
        searchQuery: _searchQuery,
        month: _selectedMonth == 0 ? null : _selectedMonth,
        year: _selectedYear == 0 ? null : _selectedYear,
      );

      if (!mounted) return;

      // Filter untuk menghindari duplikasi
      final List<Map<String, dynamic>> newQuotations = [];
      for (var quotation in fetchedQuotations) {
        if (quotation.containsKey('id') &&
            !_loadedIds.contains(quotation['id'])) {
          newQuotations.add(quotation);
          _loadedIds.add(quotation['id']);
        }
      }

      setState(() {
        if (isRefreshing) {
          _quotations = newQuotations;
        } else {
          _quotations.addAll(newQuotations);
        }

        _applyFiltersToQuotations();
        _hasMore = fetchedQuotations.length == _limit;
        _offset += _limit;
      });

      // Setelah quotations dimuat, update invoice statuses
      if (newQuotations.isNotEmpty) {
        await _updateInvoiceStatuses();
      }

      // Save to cache if refreshing or first load (dan tidak sedang mode pencarian)
      if (!_isSearching && (isRefreshing || _offset == _limit)) {
        _saveToCache(_quotations);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quotations: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyFiltersToQuotations() {
    if (_searchQuery.isEmpty) {
      _filteredQuotations = List.from(_quotations);
    } else {
      _filteredQuotations = _applySearchQuery(_searchQuery);
    }
  }

  List<Map<String, dynamic>> _applySearchQuery(String query) {
    if (query.isEmpty) return List.from(_quotations);

    // Gunakan Set untuk menghindari duplikasi berdasarkan ID
    final Set<int> uniqueIds = {};
    final List<Map<String, dynamic>> filtered = [];

    for (var quotation in _quotations) {
      if ((quotation['name']?.toString().toLowerCase() ?? '')
              .contains(query.toLowerCase()) ||
          (quotation['partner_invoice_id']?.toString().toLowerCase() ?? '')
              .contains(query.toLowerCase()) ||
          (quotation['partner_id']?[1]?.toString().toLowerCase() ?? '')
              .contains(query.toLowerCase()) ||
          (quotation['partner_shipping_id']?[1]?.toString().toLowerCase() ?? '')
              .contains(query.toLowerCase())) {
        // Pastikan tidak ada duplikasi
        if (quotation.containsKey('id') &&
            !uniqueIds.contains(quotation['id'])) {
          filtered.add(quotation);
          uniqueIds.add(quotation['id']);
        }
      }
    }

    return filtered;
  }

  void _applyFilters(int? month, int? year) {
    if (month == _selectedMonth && year == _selectedYear) return;

    setState(() {
      _selectedMonth = month;
      _selectedYear = year;
      _quotations = [];
      _filteredQuotations = [];
      _loadedIds.clear(); // Reset ID yang sudah dimuat
      _offset = 0;
      _hasMore = true;
      _isSearching = false; // Reset flag pencarian
      _searchController.clear(); // Clear search input
      _searchQuery = '';
    });

    _loadFromCache().then((_) {
      if (_quotations.isEmpty) {
        _loadQuotations(isRefreshing: true);
      } else {
        _applyFiltersToQuotations();
      }
    });
  }

  Widget _buildFilterDropdowns() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isFilterVisible ? 100 : 0,
      color: Colors.white,
      child: _isFilterVisible
          ? SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Month:', style: TextStyle(fontSize: 12)),
                          SizedBox(
                            height: 40,
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: _selectedMonth,
                              underline:
                                  Container(height: 1, color: Colors.grey[300]),
                              items: [
                                const DropdownMenuItem<int>(
                                  value: 0,
                                  child: Text('All Months'),
                                ),
                                for (int i = 1; i <= 12; i++)
                                  DropdownMenuItem<int>(
                                    value: i,
                                    child: Text(DateFormat('MMMM')
                                        .format(DateTime(2022, i))),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  _applyFilters(value, _selectedYear);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Year:', style: TextStyle(fontSize: 12)),
                          SizedBox(
                            height: 40,
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: _selectedYear,
                              menuMaxHeight: 300,
                              underline:
                                  Container(height: 1, color: Colors.grey[300]),
                              items: _availableYears.map((year) {
                                return DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(year == 0
                                      ? 'All Years'
                                      : year.toString()),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _applyFilters(_selectedMonth, value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent &&
        !_isLoading &&
        _hasMore) {
      _loadQuotations();
    }
  }

  void _filterQuotations(String query) {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;

      if (query.isEmpty) {
        // Jika pencarian kosong, kembalikan ke tampilan normal
        _filteredQuotations = List.from(_quotations);
      } else {
        // Jika pencarian server, refresh data dari server
        if (query.length >= 3) {
          // Hanya search dari server jika minimal 3 karakter
          // Reset data dan muat ulang dengan query pencarian
          _quotations.clear();
          _filteredQuotations.clear();
          _loadedIds.clear();
          _offset = 0;
          _hasMore = true;
          _loadQuotations(isRefreshing: true);
        } else {
          // Pencarian lokal jika kurang dari 3 karakter
          _filteredQuotations = _applySearchQuery(query);
        }
      }
    });
  }

  Widget _buildQuotationTile(Map<String, dynamic> item) {
    final name = item['name'] ?? 'No Name';
    final customer = item['partner_id']?[1] ?? '-';
    final shippingAddress = item['partner_shipping_id']?[1] ?? '-';
    final invoiceAddress = item['partner_invoice_id']?[1] ?? '-';
    final dateOrder =
        item['date_order']?.split(' ')[0] ?? 'Unknown'; // Format tanggal
    // final totalPrice = item['amount_total'] ?? 0.0; // Total price
    final state = item['state'] ?? 'quotation';
    final invoiceState = item['payment_state'] ?? 'not_found';

    Color _getStateColor(String state) {
      switch (state) {
        case 'sent':
          return Colors.grey;
        case 'cancel':
          return Colors.red;
        case 'sale':
          return Colors.green;
        case 'draft':
        default:
          return Colors.blue;
      }
    }

    String _getStateLabel(String state) {
      switch (state) {
        case 'sent':
          return 'Sent';
        case 'cancel':
          return 'Cancelled';
        case 'sale':
          return 'Sales Order';
        case 'draft':
        default:
          return 'Quotation';
      }
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 1.8, horizontal: 6.0),
                    margin: const EdgeInsets.only(left: 8.0),
                    decoration: BoxDecoration(
                      color: _getStateColor(state),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                    child: Text(
                      _getStateLabel(state),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              dateOrder,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Table(
              columnWidths: const {
                0: IntrinsicColumnWidth(), // Kolom label (Customer, Shipping Address)
                1: FixedColumnWidth(12), // Kolom titik dua ":"
              },
              children: [
                TableRow(
                  children: [
                    const Text(
                      "Customer",
                      style: TextStyle(fontSize: 12),
                    ),
                    const Text(
                      " :",
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      customer,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Text(
                      "Invoice address",
                      style: TextStyle(fontSize: 12),
                    ),
                    const Text(
                      " :",
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      invoiceAddress,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                TableRow(
                  children: [
                    const Text(
                      "Delivery address",
                      style: TextStyle(fontSize: 12),
                    ),
                    const Text(
                      " :",
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      shippingAddress,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currencyFormatter.format(item['amount_total'] ?? 0),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 13,
                  ),
                ),
                if (state != 'draft')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(invoiceState),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _mapInvoiceStatus(invoiceState),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/quotationDetail',
            arguments: item['id'],
          );
        },
      ),
    );
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
      case 'not_found':
        return 'Unknown';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'not_paid':
        return Colors.orange;
      case 'in_payment':
        return Colors.blue;
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.purple;
      case 'reversed':
        return Colors.red;
      case 'not_found':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60), // Atur tinggi AppBar
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 1,
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterQuotations,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                hintText: 'Search sales orders...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _filterQuotations('');
                        },
                      )
                    : null,
              ),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.filter_list,
                color: _isFilterVisible ? Colors.blue : Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _isFilterVisible = !_isFilterVisible;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey),
              onPressed: () => _loadQuotations(isRefreshing: true),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterDropdowns(),
          if (_isSearching)
            Container(
              color: Colors.yellow[100],
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing search results for: "${_searchQuery}"',
                      style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading && _filteredQuotations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _filteredQuotations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _isSearching
                                  ? 'No records found for "${_searchQuery}".'
                                  : 'No quotations found.',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadQuotations(isRefreshing: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _filteredQuotations.length +
                              (_hasMore && !_isSearching ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _filteredQuotations.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }
                            final item = _filteredQuotations[index];
                            return _buildQuotationTile(item);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  FormHeaderQuotation(odooService: widget.odooService),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
