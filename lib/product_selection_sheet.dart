// import 'package:flutter/material.dart';

// class ProductSelectionSheet extends StatelessWidget {
//   final List<Map<String, dynamic>> products;
//   final Function(Map<String, dynamic>) onProductSelected;

//   const ProductSelectionSheet({
//     Key? key,
//     required this.products,
//     required this.onProductSelected,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Material( // Add this Material widget
//       child: Padding(
//         padding: EdgeInsets.only(
//           bottom: MediaQuery.of(context).viewInsets.bottom,
//           left: 16.0,
//           right: 16.0,
//           top: 16.0,
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Text(
//               "Select Product",
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//             Expanded(
//               child: ListView.builder(
//                 itemCount: products.length,
//                 itemBuilder: (context, index) {
//                   final product = products[index];
//                   return ListTile(
//                     title: Text(product['name']),
//                     subtitle: Text(
//                       'Price: Rp ${product['list_price'].toStringAsFixed(2)}\n'
//                       'Available: ${product['qty_available']}',
//                     ),
//                     trailing: IconButton(
//                       icon: const Icon(Icons.add, color: Colors.green),
//                       onPressed: () {
//                         onProductSelected(product);
//                       },
//                     ),
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 16),
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text("Close"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }