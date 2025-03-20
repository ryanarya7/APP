import 'package:flutter/material.dart';
import 'odoo_service.dart';
import 'package:intl/intl.dart';

class CollectionScreen extends StatefulWidget {
  final OdooService odooService;

  const CollectionScreen({super.key, required this.odooService});

  @override
  _CollectionScreenState createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late Future<List<Map<String, dynamic>>> collectionList;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredCollections = [];
  List<Map<String, dynamic>> _allCollections = [];

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCollections() {
    collectionList = widget.odooService.fetchCollections();
    collectionList.then((collections) {
      setState(() {
        _allCollections = collections;
        _filteredCollections = collections; // Awal tampilkan semua
      });
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading collections: $error')),
      );
    });
  }

  void _refresh() {
    setState(() {
      _loadCollections();
    });
  }

  void _filterCollections(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCollections = _allCollections; // Reset jika kosong
      } else {
        _filteredCollections = _allCollections.where((collection) {
          final name = collection['name'] ?? '';
          final createdBy = collection['create_uid']?[1] ?? '';
          final state = collection['state'] ?? '';
          return name.toLowerCase().contains(query.toLowerCase()) ||
              createdBy.toLowerCase().contains(query.toLowerCase()) ||
              state.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          automaticallyImplyLeading: false, // Hilangkan tombol back
          backgroundColor: Colors.white,
          elevation: 1,
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCollections,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                hintText: 'Search collections...',
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: collectionList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading collections: ${snapshot.error}'),
            );
          }

          if (_filteredCollections.isEmpty) {
            return const Center(child: Text('No collections available.'));
          }

          return ListView.builder(
            itemCount: _filteredCollections.length,
            itemBuilder: (context, index) {
              final collection = _filteredCollections[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/collectionDetail',
                      arguments: collection['id'],
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              collection['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _getStateColor(collection['state']),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getStateDisplayName(collection['state']),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                                  "Created By",
                                  style: TextStyle(fontSize: 12),
                                ),
                                const Text(
                                  " :",
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  collection['create_uid']?[1] ?? 'N/A',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            const TableRow(
                              children: [
                                SizedBox(height: 2), // Jarak antar baris
                                SizedBox(),
                                SizedBox(),
                              ],
                            ),
                            TableRow(
                              children: [
                                const Text(
                                  "Created At",
                                  style: TextStyle(fontSize: 12),
                                ),
                                const Text(
                                  " :",
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  collection['create_date'] ?? 'N/A',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            const TableRow(
                              children: [
                                SizedBox(height: 2),
                                SizedBox(),
                                SizedBox(),
                              ],
                            ),
                            TableRow(
                              children: [
                                const Text(
                                  "Transfer Date",
                                  style: TextStyle(fontSize: 12),
                                ),
                                const Text(
                                  " :",
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  collection['create_date'] ?? 'N/A',
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
        },
      ),
    );
  }

  Color _getStateColor(String? state) {
    switch (state) {
      case 'draft':
        return Colors.grey;
      case 'transfer':
        return Colors.blue;
      case 'received':
        return Colors.green;
      case 'cancel':
        return Colors.red;
      case 'return':
        return Colors.yellow;
      default:
        return Colors.black54;
    }
  }

  String _getStateDisplayName(String? state) {
    if (state == null) return 'Unknown';
    return toBeginningOfSentenceCase(state.toLowerCase()) ?? state;
  }
}
