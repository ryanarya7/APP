// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'odoo_service.dart';
// import 'product_detail_screen.dart';

// class ProductsCategoryScreen extends StatefulWidget {
//   final OdooService odooService;
//   final String categoryId;
//   final String categoryName;

//   const ProductsCategoryScreen({
//     Key? key,
//     required this.odooService,
//     required this.categoryId,
//     required this.categoryName,
//   }) : super(key: key);

//   @override
//   _ProductsCategoryScreenState createState() => _ProductsCategoryScreenState();
// }

// class _ProductsCategoryScreenState extends State<ProductsCategoryScreen> {
//   List<Map<String, dynamic>> _products = [];
//   List<Map<String, dynamic>> _filteredProducts = [];
//   final TextEditingController _searchController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _loadProducts();
//   }

//   Future<void> _loadProducts() async {
//     try {
//       final fetchedProducts =
//           await widget.odooService.fetchProductsByCategory(widget.categoryId);
//       setState(() {
//         _products = fetchedProducts;
//         _filteredProducts = _products; // Set initial filter
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error loading products: $e')),
//       );
//     }
//   }

//   void _filterProducts(String query) {
//     setState(() {
//       if (query.isEmpty) {
//         _filteredProducts = _products;
//       } else {
//         _filteredProducts = _products.where((product) {
//           final name = product['name']?.toString().toLowerCase() ?? '';
//           final code = product['default_code']?.toString().toLowerCase() ?? '';
//           return name.contains(query.toLowerCase()) ||
//               code.contains(query.toLowerCase());
//         }).toList();
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Products in ${widget.categoryName}',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         centerTitle: true,
//         backgroundColor: Colors.blue[300],
//       ),
//       body: Column(
//         children: [
//           // Search Bar
//           Padding(
//             padding: const EdgeInsets.all(10.0),
//             child: TextField(
//               controller: _searchController,
//               onChanged: _filterProducts,
//               decoration: InputDecoration(
//                 hintText: 'Search products...',
//                 prefixIcon: const Icon(Icons.search),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//               ),
//             ),
//           ),
//           // Products List
//           Expanded(
//             child: _filteredProducts.isEmpty
//                 ? const Center(child: Text('No products found'))
//                 : ListView.builder(
//                     itemCount: _filteredProducts.length,
//                     itemBuilder: (context, index) {
//                       final product = _filteredProducts[index];
//                       return ListTile(
//                         title: Text(
//                           product['default_code'] != null &&
//                                   product['default_code'] != false
//                               ? '${product['default_code']} ${product['name']}'
//                               : product['name'],
//                         ),
//                         subtitle: Text(
//                           'Rp.${product['list_price']} - Available: ${product['qty_available']}',
//                         ),
//                         leading: product['image_1920'] != null &&
//                                 product['image_1920'] is String
//                             ? Image.memory(
//                                 base64Decode(product['image_1920']),
//                                 width: 50,
//                                 height: 50,
//                                 fit: BoxFit.cover,
//                                 errorBuilder: (context, error, stackTrace) {
//                                   return const Icon(Icons.image_not_supported);
//                                 },
//                               )
//                             : const Icon(Icons.image),
//                         onTap: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) =>
//                                   ProductDetailScreen(product: product),
//                             ),
//                           );
//                         },
//                       );
//                     },
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }
