import 'package:flutter/material.dart';
import 'odoo_service.dart';

class CheckWizardDialog extends StatefulWidget {
  final OdooService odooService;
  final int invoiceId;
  final String invoiceName;
  final double initialAmount;
  final String partnerId;

  const CheckWizardDialog({
    super.key,
    required this.odooService,
    required this.invoiceId,
    required this.invoiceName,
    required this.initialAmount,
    required this.partnerId,
  });

  @override
  _CheckWizardDialogState createState() => _CheckWizardDialogState();
}

class _CheckWizardDialogState extends State<CheckWizardDialog> {
  final _formKey = GlobalKey<FormState>();
  bool isChecked = false;
  double amountTotal = 0;
  String? receiptVia;

  @override
  void initState() {
    super.initState();
    amountTotal = widget.initialAmount > 0 ? widget.initialAmount : 0;
  }

  Future<void> _confirmCheck() async {
    try {
      // Validasi form
      if (!_formKey.currentState!.validate()) {
        return;
      }

      // Simpan nilai form
      _formKey.currentState!.save();

      // Create the wizard record
      final wizardId = await widget.odooService.createPaymentWizard(
        invoiceId: widget.invoiceId,
        isCheck: isChecked,
        amount:
            amountTotal, // Kirim nilai amountTotal apa pun kondisi isChecked
        receiptVia: receiptVia ??
            '', // Kirim nilai receiptVia apa pun kondisi isChecked
        checkbookId: null, // Selalu kirim null untuk checkbookId
      );

      // Confirm the wizard
      await widget.odooService.confirmWizardAction(wizardId);

      Navigator.of(context).pop(true); // Indicate success
    } catch (e) {
      // Tangkap pesan kesalahan dari backend
      String errorMessage = e.toString();

      // Jika pesan kesalahan spesifik, tampilkan pop-up
      if (errorMessage.contains('Amount Residual Dalam Giro Tidak Cukup')) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Error'),
              content: const Text('Amount Residual Dalam Giro Tidak Cukup'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      } else {
        // Untuk kesalahan lain, gunakan SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $errorMessage')),
        );
      }
    }
  }

  void _showAmountExceededDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Warning'),
          content: Text('Amount cannot exceed ${widget.initialAmount}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.invoiceName),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('Check'),
                value: isChecked,
                onChanged: (value) {
                  setState(() {
                    isChecked = value ?? false;
                  });
                },
              ),
              TextFormField(
                initialValue: '0.0',
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Amount is required';
                  }
                  final double? parsed = double.tryParse(value);
                  if (parsed == null || parsed < 0) {
                    return 'Enter a valid amount';
                  }
                  // Add validation for maximum amount
                  if (parsed > widget.initialAmount) {
                    // Schedule the dialog to show after the current build cycle
                    Future.microtask(() => _showAmountExceededDialog());
                    return 'Amount cannot exceed ${widget.initialAmount}';
                  }
                  return null;
                },
                onSaved: (value) {
                  amountTotal = double.parse(value!);
                },
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Receipt Via'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'giro', child: Text('Giro')),
                  DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                ],
                value: receiptVia,
                onChanged: (value) {
                  setState(() {
                    receiptVia = value;
                  });
                },
                validator: (value) {
                  if (isChecked) {
                    // Mandatory jika isChecked == true
                    if (value == null || value.isEmpty) {
                      return 'Receipt Via is required';
                    }
                  }
                  // Tidak mandatory jika isChecked == false
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              _confirmCheck();
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
