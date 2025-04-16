import 'package:flutter/material.dart';
import 'odoo_service.dart';
import 'package:intl/intl.dart';

class CheckGiroScreen extends StatefulWidget {
  final OdooService odooService;
  const CheckGiroScreen({super.key, required this.odooService});

  @override
  _CheckGiroState createState() => _CheckGiroState();
}

class _CheckGiroState extends State<CheckGiroScreen> {
  late Future<List<Map<String, dynamic>>> giroList;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredGiroBooks = [];
  List<Map<String, dynamic>> _allGiroBooks = [];

  @override
  void initState() {
    super.initState();
    _loadGiroBook();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadGiroBook() {
    giroList = widget.odooService.fetchGiroBook();
    giroList.then((girobook) {
      setState(() {
        _allGiroBooks = girobook;
        _filteredGiroBooks = girobook; // Initially show all entries
      });
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading giro book: $error')),
      );
    });
  }

  void _refresh() {
    setState(() {
      _loadGiroBook();
    });
  }

  void _filterCollections(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredGiroBooks =
            _allGiroBooks; // Reset if the search query is empty
      } else {
        _filteredGiroBooks = _allGiroBooks.where((girobook) {
          // Safely extract fields with defensive checks
          final name = girobook['name']?.toString().toLowerCase() ?? '';
          final customer = _getSafeValue(girobook['partner_id']);
          final receivedBy = _getSafeValue(girobook['user_id']);
          final paymentType =
              girobook['payment_type']?.toString().toLowerCase() ?? '';
          final state = girobook['state']?.toString().toLowerCase() ?? '';

          // Check if any of the fields contain the query
          return name.contains(query.toLowerCase()) ||
              customer.contains(query.toLowerCase()) ||
              receivedBy.contains(query.toLowerCase()) ||
              paymentType.contains(query.toLowerCase()) ||
              state.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  String _getSafeValue(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return value[1]?.toString().toLowerCase() ?? 'N/A';
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          automaticallyImplyLeading: false, // Remove back button
          backgroundColor: Colors.white,
          elevation: 1,
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCollections,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                hintText: 'Search Check Giro',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey),
              onPressed: _refresh,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: giroList,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                } else if (snapshot.hasData) {
                  return ListView.builder(
                    itemCount: _filteredGiroBooks.length,
                    itemBuilder: (context, index) {
                      final girobook = _filteredGiroBooks[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/checkGiroDetail',
                              arguments: {'checkBookId': girobook['id']},
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      girobook['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: _getStateColor(
                                            girobook['state'] ?? ''),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _getStateDisplayName(
                                            girobook['state'] ?? ''),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Table(
                                  columnWidths: const {
                                    0: IntrinsicColumnWidth(),
                                    1: FixedColumnWidth(20),
                                    2: FlexColumnWidth(),
                                  },
                                  children: [
                                    TableRow(
                                      children: [
                                        const Text(
                                          "Receive Date",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        const Text(
                                          " :",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          DateFormat('yyyy-MM-dd').format(
                                              DateTime.parse(
                                                  girobook['date'] ?? '')),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    TableRow(
                                      children: [
                                        const Text(
                                          "Payment Type",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        const Text(
                                          " :",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          _getPaymentTypeDisplay(
                                              girobook['payment_type'] ?? ''),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
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
                                          _getSafeValue(girobook['partner_id']),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    TableRow(
                                      children: [
                                        const Text(
                                          "Received By",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        const Text(
                                          " :",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          _getSafeValue(girobook['user_id']),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    TableRow(
                                      children: [
                                        const Text(
                                          "Residual",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        const Text(
                                          " :",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          NumberFormat.currency(
                                            locale: 'en_US',
                                            symbol: 'Rp ',
                                          ).format(
                                              girobook['residual_check'] ?? 0),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    TableRow(
                                      children: [
                                        const Text(
                                          "Total",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        const Text(
                                          " :",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          NumberFormat.currency(
                                            locale: 'en_US',
                                            symbol: 'Rp ',
                                          ).format(
                                              girobook['total_check'] ?? 0),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
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
                } else {
                  return const Center(child: Text('No data available'));
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/giroFormHeader',
            arguments: {'odooService': widget.odooService},
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
        tooltip: 'Create New Giro Book',
      ),
    );
  }

  Color _getStateColor(String? state) {
    switch (state) {
      case 'draft':
        return Colors.grey;
      case 'confirm':
        return Colors.green;
      case 'cancel':
        return Colors.red;
      case 'used':
        return Colors.yellow;
      default:
        return Colors.black54;
    }
  }

  String _getStateDisplayName(String? state) {
    if (state == null) return 'Unknown';
    return toBeginningOfSentenceCase(state.toLowerCase()) ?? state;
  }

  String _getPaymentTypeDisplay(String? paymentType) {
    if (paymentType == 'outbound') {
      return 'Send';
    } else if (paymentType == 'inbound') {
      return 'Receive';
    } else {
      return 'Unknown';
    }
  }
}
