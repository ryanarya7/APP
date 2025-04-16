// import 'package:flutter/material.dart';
// import 'odoo_service.dart';
// import 'products_category_screen.dart';

// class CategoriesScreen extends StatefulWidget {
//   final OdooService odooService;

//   const CategoriesScreen({super.key, required this.odooService});

//   @override
//   _CategoriesScreenState createState() => _CategoriesScreenState();
// }

// class _CategoriesScreenState extends State<CategoriesScreen> {
//   List<Map<String, dynamic>> _categories = [];
//   List<Map<String, dynamic>> _filteredCategories = [];
//   final TextEditingController _searchController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _loadCategories();
//   }

//   Future<void> _loadCategories() async {
//     try {
//       final fetchedCategories = await widget.odooService.fetchCategories();
//       if (!mounted) return;
//       setState(() {
//         _categories = fetchedCategories.cast<Map<String, dynamic>>();
//         _filteredCategories = _categories;
//       });
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error loading categories: $e')),
//         );
//       }
//     }
//   }

//   void _filterCategories(String query) {
//     setState(() {
//       if (query.isEmpty) {
//         _filteredCategories = _categories;
//       } else {
//         _filteredCategories = _categories
//             .where((category) =>
//                 (category['name']?.toString().toLowerCase() ?? '')
//                     .contains(query.toLowerCase()))
//             .toList();
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Categories',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//         backgroundColor: Colors.blue[300],
//       ),
//       body: Column(
//         children: [
//           // Search Bar
//           Padding(
//             padding: const EdgeInsets.all(10.0),
//             child: TextField(
//               controller: _searchController,
//               onChanged: _filterCategories,
//               decoration: InputDecoration(
//                 hintText: 'Search categories...',
//                 prefixIcon: const Icon(Icons.search),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//               ),
//             ),
//           ),
//           // Categories Grid
//           Expanded(
//             child: _filteredCategories.isEmpty
//                 ? const Center(child: Text('No categories found'))
//                 : GridView.builder(
//                     padding: const EdgeInsets.all(10),
//                     gridDelegate:
//                         const SliverGridDelegateWithFixedCrossAxisCount(
//                       crossAxisCount: 2,
//                       crossAxisSpacing: 10,
//                       mainAxisSpacing: 10,
//                       childAspectRatio: 3,
//                     ),
//                     itemCount: _filteredCategories.length,
//                     itemBuilder: (context, index) {
//                       final category = _filteredCategories[index];
//                       return GestureDetector(
//                         onTap: () {
//                           // Navigate to Products Category Screen
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => ProductsCategoryScreen(
//                                 odooService: widget.odooService,
//                                 categoryId: category['id'].toString(),
//                                 categoryName: category['name'] ?? 'Unknown',
//                               ),
//                             ),
//                           );
//                         },
//                         child: Card(
//                           elevation: 2,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           child: Center(
//                             child: Text(
//                               category['name'] ?? 'Unknown',
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 16,
//                                 color: Colors.black,
//                               ),
//                               textAlign: TextAlign.center,
//                             ),
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }
