import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'odoo_service.dart';
import 'check_wizard.dart';

class DetailCollectionScreen extends StatefulWidget {
  final OdooService odooService;

  const DetailCollectionScreen({super.key, required this.odooService});

  @override
  _DetailCollectionScreenState createState() => _DetailCollectionScreenState();
}

class _DetailCollectionScreenState extends State<DetailCollectionScreen> {
  late Future<Map<String, dynamic>> collectionDetail;
  int? collectionId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    collectionId = ModalRoute.of(context)?.settings.arguments as int?;
    if (collectionId != null) {
      _loadCollectionDetail(collectionId!);
    }
  }

  void _loadCollectionDetail(int id) {
    collectionDetail = widget.odooService.fetchCollectionDetail(id);
  }

  Future<List<Map<String, dynamic>>> fetchInvoices(
      List<int> accountMoveIds) async {
    if (accountMoveIds.isEmpty) return [];
    try {
      return await widget.odooService.fetchInvoiceDetails(accountMoveIds);
    } catch (e) {
      throw Exception('Failed to fetch invoice details: $e');
    }
  }

  void _openCheckWizard(Map<String, dynamic> invoice) async {
    final bool? result = await showDialog(
      context: context,
      builder: (context) {
        return CheckWizardDialog(
          odooService: widget.odooService,
          invoiceId: invoice['id'],
          invoiceName: invoice['name'],
          initialAmount: invoice['amount_residual_signed'] ?? 0,
          partnerId: invoice['partner_id']?[0]?.toString() ?? '',
        );
      },
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment updated successfully!')),
      );
    }
  }

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 2,
  );

  Color _getStateColor(String state) {
    switch (state) {
      case 'draft':
        return Colors.grey;
      case 'transfer':
        return Colors.blue;
      case 'received':
        return Colors.green;
      case 'return':
        return Colors.orange;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.black54;
    }
  }

  String _getStateDisplayName(String? state) {
    if (state == null) return 'Unknown';
    return toBeginningOfSentenceCase(state.toLowerCase()) ?? state;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text('Collection Detail',
      style: TextStyle(fontWeight: FontWeight.bold)),
  backgroundColor: Colors.blue[300],
  actions: [
    FutureBuilder<Map<String, dynamic>>(
      future: collectionDetail,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
          return Container();
        }

        final detail = snapshot.data!;
        final state = detail['state'];

        if (state == 'transfer') {
          return TextButton(
            onPressed: () async {
              try {
                await widget.odooService.callMethod(
                  'invoice.collection',
                  'action_done',
                  [collectionId],
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Collection marked as received')),
                );

                setState(() {
                  _loadCollectionDetail(collectionId!);
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('To Received', style: TextStyle(color: Colors.white)),
          );
        } else if (state == 'received') {
          return TextButton(
            onPressed: () async {
              try {
                await widget.odooService.callMethod(
                  'invoice.collection',
                  'action_return_to_piutang',
                  [collectionId],
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Returned to Adm Piutang')),
                );

                setState(() {
                  _loadCollectionDetail(collectionId!);
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Back to adm piutang', style: TextStyle(color: Colors.white)),
          );
        } else {
          return Container();
        }
      },
    ),
  ],
),
      body: FutureBuilder<Map<String, dynamic>>(
        future: collectionDetail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading detail: ${snapshot.error}'),
            );
          }

          final detail = snapshot.data!;
          final accountMoveIds =
              (detail['account_move_ids'] as List<dynamic>?)?.cast<int>() ?? [];
          final collectionState = detail['state'] ?? 'Unknown';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // Header Section
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Text Name (Kiri)
                            Text(
                              detail['name'] ?? 'Unknown Collection',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _getStateColor(collectionState),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getStateDisplayName(collectionState),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            // Spacer untuk mendorong Transfer Date ke kanan
                            const Spacer(),
                            // Text Transfer Date (Kanan)
                            Text(
                              '${detail['create_date'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Table(
                          columnWidths: const {
                            0: IntrinsicColumnWidth(),
                            1: FixedColumnWidth(12),
                            2: FlexColumnWidth(),
                          },
                          children: [
                            TableRow(
                              children: [
                                const Text(
                                  "Origin",
                                  style: TextStyle(fontSize: 12),
                                ),
                                const Text(
                                  " :",
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  detail['invoice_origin'] ?? 'N/A',
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
                                  "Destination",
                                  style: TextStyle(fontSize: 12),
                                ),
                                const Text(
                                  " :",
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  detail['invoice_destination'] ?? 'N/A',
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
                                  "Salesman",
                                  style: TextStyle(fontSize: 12),
                                ),
                                const Text(
                                  " :",
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  (detail['salesman'] is List &&
                                          detail['salesman'].length >= 2)
                                      ? detail['salesman'][1]
                                      : 'N/A',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // const Text(
                        //   'Notes:',
                        //   style: TextStyle(fontWeight: FontWeight.bold),
                        // ),
                        // Text(
                        //   (detail['notes'] is String
                        //       ? detail['notes']!
                        //           .replaceAll(RegExp(r'<[^>]*>'), '')
                        //       : 'N/A'),
                        // ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Invoices :',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: fetchInvoices(accountMoveIds),
                  builder: (context, invoiceSnapshot) {
                    if (invoiceSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (invoiceSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error fetching invoices: ${invoiceSnapshot.error}',
                        ),
                      );
                    }

                    final invoices = invoiceSnapshot.data ?? [];
                    if (invoices.isEmpty) {
                      return const Text(
                          'No invoices linked to this collection.');
                    }

                    // Hitung total amount, residual, dan partial payment
                    final totalAmount = invoices.fold<double>(
                      0.0,
                      (sum, invoice) => sum + (invoice['amount_total'] ?? 0.0),
                    );
                    final totalResidual = invoices.fold<double>(
                      0.0,
                      (sum, invoice) =>
                          sum + (invoice['amount_residual_signed'] ?? 0.0),
                    );
                    final totalPartialPayment = invoices.fold<double>(
                      0.0,
                      (sum, invoice) =>
                          sum + (invoice['partial_total_payment'] ?? 0.0),
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: invoices.length,
                          itemBuilder: (context, index) {
                            final invoice = invoices[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Informasi Utama Invoice
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Header Invoice
                                          Row(
                                            children: [
                                              Text(
                                                invoice['name'] ??
                                                    'Unknown Invoice',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 25),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: invoice[
                                                              'payment_state'] ==
                                                          'paid'
                                                      ? Colors.green
                                                      : (invoice['payment_state'] ==
                                                              'partial'
                                                          ? Colors.orange
                                                          : Colors.red),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  _getStateDisplayName(
                                                      invoice['payment_state']),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 25),
                                              Align(
                                                alignment: Alignment.topRight,
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      _openCheckWizard(invoice),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.purple,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: const Text(
                                                      'Check',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Table(
                                            columnWidths: const {
                                              0: IntrinsicColumnWidth(),
                                              1: FixedColumnWidth(12),
                                              2: FlexColumnWidth(),
                                            },
                                            children: [
                                              TableRow(
                                                children: [
                                                  const Text(
                                                    "Customer",
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                  const Text(
                                                    " :",
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                  Text(
                                                    invoice['partner_id']?[1] ??
                                                        'Unknown',
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                              const TableRow(
                                                children: [
                                                  SizedBox(height: 4),
                                                  SizedBox(),
                                                  SizedBox(),
                                                ],
                                              ),
                                              TableRow(
                                                children: [
                                                  const Text(
                                                    "Amount",
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                  const Text(
                                                    " :",
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                  Text(
                                                    currencyFormatter.format(
                                                        invoice['amount_total'] ??
                                                            0),
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                              const TableRow(
                                                children: [
                                                  SizedBox(height: 4),
                                                  SizedBox(),
                                                  SizedBox(),
                                                ],
                                              ),
                                              TableRow(
                                                children: [
                                                  const Text(
                                                    "Amount Due",
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                  const Text(
                                                    " :",
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                  Text(
                                                    currencyFormatter.format(
                                                        invoice['amount_residual_signed'] ??
                                                            0),
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                              const TableRow(
                                                children: [
                                                  SizedBox(height: 4),
                                                  SizedBox(),
                                                  SizedBox(),
                                                ],
                                              ),
                                              TableRow(
                                                children: [
                                                  const Text(
                                                    "Receipt Via",
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                  const Text(
                                                    " :",
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                  Text(
                                                    (invoice['receipt_via']
                                                                is String &&
                                                            invoice['receipt_via']
                                                                .isNotEmpty)
                                                        ? invoice['receipt_via']
                                                        : 'Unknown',
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                              const TableRow(
                                                children: [
                                                  SizedBox(height: 4),
                                                  SizedBox(),
                                                  SizedBox(),
                                                ],
                                              ),
                                              TableRow(
                                                children: [
                                                  const Text(
                                                    "Check",
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                  const Text(
                                                    " :",
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          (invoice[
                                                                  'check_payment_invoice'])
                                                              ? Icons.check
                                                              : Icons.close,
                                                          color: (invoice[
                                                                      'check_payment_invoice'] ==
                                                                  true)
                                                              ? Colors.green
                                                              : Colors.red,
                                                          size: 16,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const TableRow(
                                                children: [
                                                  SizedBox(height: 4),
                                                  SizedBox(),
                                                  SizedBox(),
                                                ],
                                              ),
                                              TableRow(
                                                children: [
                                                  const Text(
                                                    "Amount Payment",
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                  const Text(
                                                    " :",
                                                    style:
                                                        TextStyle(fontSize: 12),
                                                  ),
                                                  Text(
                                                    currencyFormatter.format(
                                                        invoice['partial_total_payment'] ??
                                                            0),
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
// Tampilkan Total Summary
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Total",
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    currencyFormatter.format(totalAmount),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Total Residual",
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    currencyFormatter.format(totalResidual),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Amount Payment",
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    currencyFormatter
                                        .format(totalPartialPayment),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
