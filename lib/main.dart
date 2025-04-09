import 'package:flutter/material.dart';
import 'form_detail_quotation_screen.dart';
import 'login_screen.dart';
import 'navigation_screen.dart';
import 'odoo_service.dart';
import 'quotation_detail_screen.dart';
import 'sale_order_list_screen.dart';
// import 'form_collection_screen.dart';
import 'detail_collection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final odooService = OdooService('https://bpa.alphasoft.co.id/');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Odoo Flutter Integration',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(odooService: odooService),
        '/home': (context) => NavigationScreen(odooService: odooService),
        '/formDetail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return FormDetailQuotation(
              odooService: odooService, headerData: args);
        },
        '/saleOrderList': (context) =>
            SaleOrderListScreen(odooService: odooService),
        '/quotationDetail': (context) => QuotationDetailScreen(
              odooService: odooService,
              quotationId: ModalRoute.of(context)!.settings.arguments as int,
            ),
        // '/formCollection': (context) => FormCollectionScreen(odooService: odooService),
        '/collectionDetail': (context) => DetailCollectionScreen(
              odooService: odooService,
            ),
      },
    );
  }
}