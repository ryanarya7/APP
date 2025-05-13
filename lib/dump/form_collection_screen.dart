// import 'package:flutter/material.dart';
// import 'odoo_service.dart';

// class FormCollectionScreen extends StatefulWidget {
//   final OdooService odooService;

//   const FormCollectionScreen({Key? key, required this.odooService}) : super(key: key);

//   @override
//   _FormCollectionScreenState createState() => _FormCollectionScreenState();
// }

// class _FormCollectionScreenState extends State<FormCollectionScreen> {
//   final _formKey = GlobalKey<FormState>();
//   String invoiceOrigin = '0';
//   String invoiceDestination = '2';
//   String? notes;
//   DateTime? transferDate;
//   List<Map<String, dynamic>> invoices = [];
//   List<int> selectedInvoiceIds = [];

//   @override
//   void initState() {
//     super.initState();
//     _fetchInvoices('0');
//   }

//   Future<void> _fetchInvoices(String invoiceOrigin) async {
//     try {
//       // Fetch invoices berdasarkan invoiceOrigin
//       final fetchedInvoices = await widget.odooService.fetchInvoices(
//         invoiceOrigin: invoiceOrigin,
//       );
//       setState(() {
//         invoices = fetchedInvoices; // Simpan hasil fetch ke state
//       });
//     } catch (e) {
//       // Tampilkan error jika ada masalah saat fetch
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching invoices: $e')),
//       );
//     }
//   }

//   Future<void> _pickDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: transferDate ?? DateTime.now(),
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2100),
//     );
//     if (picked != null && picked != transferDate) {
//       setState(() {
//         transferDate = picked;
//       });
//     }
//   }

//   Future<void> _saveCollection() async {
//     if (!_formKey.currentState!.validate()) return;

//     // Validasi bahwa semua invoice yang dipilih memiliki partner_id yang sama
//     final selectedInvoices = invoices
//         .where((invoice) => selectedInvoiceIds.contains(invoice['id']))
//         .toList();
//     final uniqueCustomers = selectedInvoices.map((e) => e['partner_id']).toSet();
//     if (uniqueCustomers.length > 1) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('All invoices must belong to the same customer.')),
//       );
//       return;
//     }

//     _formKey.currentState!.save();

//     // Debug: Log data yang akan dikirim ke Odoo
//     print({
//       'invoice_origin': invoiceOrigin,
//       'invoice_destination': invoiceDestination,
//       'transfer_date': transferDate!.toIso8601String(), // Pastikan tidak null
//       'notes': notes,
//       'account_move_ids': [6, 0, selectedInvoiceIds],
//     });

//     try {
//       await widget.odooService.createCollection(
//         invoiceOrigin: invoiceOrigin,
//         invoiceDestination: invoiceDestination,
//         transferDate: transferDate!,
//         notes: notes,
//         accountMoveIds: selectedInvoiceIds, // Kirim invoice yang dipilih
//       );
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Collection created successfully!')),
//       );
//       Navigator.pop(context);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Create Collection'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             children: [
//               // Invoice Origin (Read-only)
//               TextFormField(
//                 initialValue: invoiceOrigin,
//                 decoration: const InputDecoration(
//                   labelText: 'Invoice Origin',
//                   border: OutlineInputBorder(),
//                 ),
//                 readOnly: true,
//               ),
//               const SizedBox(height: 16),

//               // Invoice Destination (Read-only)
//               TextFormField(
//                 initialValue: invoiceDestination,
//                 decoration: const InputDecoration(
//                   labelText: 'Invoice Destination',
//                   border: OutlineInputBorder(),
//                 ),
//                 readOnly: true,
//               ),
//               const SizedBox(height: 16),

//               // Transfer Date
//               GestureDetector(
//                 onTap: () => _pickDate(context),
//                 child: AbsorbPointer(
//                   child: TextFormField(
//                     decoration: const InputDecoration(
//                       labelText: 'Transfer Date',
//                       border: OutlineInputBorder(),
//                     ),
//                     controller: TextEditingController(
//                       text: transferDate != null
//                           ? "${transferDate!.year}-${transferDate!.month.toString().padLeft(2, '0')}-${transferDate!.day.toString().padLeft(2, '0')}"
//                           : '',
//                     ),
//                     validator: (value) => transferDate == null ? 'Transfer Date is required' : null,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),

//               // Notes
//               TextFormField(
//                 decoration: const InputDecoration(
//                   labelText: 'Notes',
//                   border: OutlineInputBorder(),
//                 ),
//                 maxLines: 3,
//                 onSaved: (value) => notes = value,
//               ),
//               const SizedBox(height: 16),

//               // Invoice List
//               const Text(
//                 'Select Invoices',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//               ),
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: invoices.length,
//                   itemBuilder: (context, index) {
//                     final invoice = invoices[index];
//                     return CheckboxListTile(
//                       title: Text(invoice['name'] ?? 'Unnamed Invoice'),
//                       subtitle: Text(
//                         'Customer: ${invoice['partner_id']?[1] ?? 'Unknown'}\n'
//                         'Amount: Rp ${invoice['amount_total'] ?? 0}',
//                       ),
//                       value: selectedInvoiceIds.contains(invoice['id']),
//                       onChanged: (isSelected) {
//                         setState(() {
//                           if (isSelected == true) {
//                             selectedInvoiceIds.add(invoice['id']);
//                           } else {
//                             selectedInvoiceIds.remove(invoice['id']);
//                           }
//                         });
//                       },
//                     );
//                   },
//                 ),
//               ),

//               // Save Button
//               ElevatedButton(
//                 onPressed: _saveCollection,
//                 child: const Text('Save Collection'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
