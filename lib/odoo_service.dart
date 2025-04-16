import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/io_client.dart';

class OdooService {
  final OdooClient _client;
  static const _sessionKey = 'odoo_session';
  final _storage = const FlutterSecureStorage(); // Gunakan SecureStorage
  String? currentUsername;

  OdooService(String baseUrl) : _client = OdooClient(baseUrl);

  Future<void> _configureHttpClient() async {
    try {
      // Load the certificate from assets
      final cert = await rootBundle.load('assets/alphasoft.crt');
      final securityContext = SecurityContext();
      securityContext.setTrustedCertificatesBytes(cert.buffer.asUint8List());

      // Create an HTTP client with the custom security context
      final httpClient = HttpClient(context: securityContext);

      // Wrap the HttpClient in an IOClient (from the http package)
      final ioClient = IOClient(httpClient);

      // Assign the IOClient to the OdooClient
      _client.httpClient = ioClient;
    } catch (e) {
      throw Exception('Failed to configure HTTP client: $e');
    }
  }

  // ignore: unused_element
  Future<void> _storeSession(OdooSession session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  static Future<OdooSession?> restoreSession() async {
    try {
      final sessionData =
          await const FlutterSecureStorage().read(key: _sessionKey);
      if (sessionData == null) return null;
      final session = OdooSession.fromJson(jsonDecode(sessionData));
      final client = OdooClient('https://bpa.alphasoft.co.id/', session);
      try {
        await client.checkSession();
        return session;
      } on OdooSessionExpiredException {
        print('Session expired');
        return null;
      }
    } catch (e) {
      print('Failed to restore session: $e');
      return null;
    }
  }

  Future<void> login(String database, String username, String password) async {
    try {
      await _configureHttpClient(); // Konfigurasi HTTP client dengan sertifikat
      await _client.authenticate(database, username, password);
      currentUsername = username; // Simpan username untuk keperluan lainnya
    } on OdooException catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _client.destroySession();
      await _storage.delete(key: _sessionKey); // Hancurkan sesi di server
      currentUsername = null; // Hapus username yang tersimpan
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  Future<void> checkSession() async {
    try {
      await _client.checkSession(); // Periksa apakah sesi masih valid
    } on OdooSessionExpiredException {
      throw Exception('Session expired. Please log in again.');
    }
  }

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'product.product',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'list_price',
            'image_1920',
            'qty_available',
            'default_code',
            'uom_id',
            'company_id',
          ],
        },
      });

      // Parsing hasil dan memastikan company_id memiliki nama
      List<Map<String, dynamic>> products =
          List<Map<String, dynamic>>.from(response);
      for (var product in products) {
        product['vendor_name'] = product['company_id'] != null &&
                product['company_id'] is List &&
                product['company_id'].length >= 2
            ? product['company_id'][1] // Ambil nama dari company_id
            : 'No Vendor';
      }

      return products;
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    await checkSession(); // Pastikan session valid sebelum fetch
    try {
      final response = await _client.callKw({
        'model': 'product.category',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': ['name'],
        },
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchProductsByCategory(
      String categoryId) async {
    await checkSession(); // Ensure session is valid
    try {
      final response = await _client.callKw({
        'model': 'product.template',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['categ_id', '=', int.parse(categoryId)]
          ],
          'fields': [
            'name',
            'list_price',
            'image_1920',
            'qty_available',
            'default_code',
            'company_id', // Include company information
          ],
        },
      });

      // Parse and format the products list
      List<Map<String, dynamic>> products =
          List<Map<String, dynamic>>.from(response);
      for (var product in products) {
        product['vendor_name'] = product['company_id'] != null &&
                product['company_id'] is List &&
                product['company_id'].length >= 2
            ? product['company_id'][1] // Extract company name
            : 'No Vendor';
      }

      return products;
    } catch (e) {
      throw Exception('Failed to fetch products by category: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchProductsTemplate() async {
    await checkSession(); // Pastikan sesi valid sebelum fetch
    try {
      final response = await _client.callKw({
        'model': 'product.template',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'list_price',
            'image_1920',
            'qty_available',
            'default_code',
            'categ_id', // Ambil category_id dari product.template
          ],
        },
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch products template: $e');
    }
  }

  Future<Map<String, dynamic>> fetchUser([String? username]) async {
    await checkSession(); // Pastikan session valid sebelum fetch
    final String userToFetch = username ?? currentUsername!;
    try {
      final response = await _client.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ['login', '=', userToFetch]
          ] // Filter directly in the query
        ],
        'kwargs': {
          'fields': ['name', 'login', 'image_1920'],
          'limit': 1
        },
      });

      if (response.isEmpty) {
        throw Exception('User not found for username: $userToFetch');
      }

      final user = Map<String, dynamic>.from(response.first);

      // Process the image data if exists
      if (user.containsKey('image_1920') && user['image_1920'] != false) {
        // Ensure the image is properly formatted
        try {
          // The image should already be valid base64, but let's check
          if (user['image_1920'] is String) {
            // We keep it as is, but we could do additional validation here
          } else {
            // If it's not a string, remove it to avoid errors
            user['image_1920'] = null;
          }
        } catch (e) {
          user['image_1920'] = null; // Reset image on error
        }
      } else {
        user['image_1920'] = null; // Ensure null for non-existent images
      }

      return user;
    } catch (e) {
      throw Exception('Failed to fetch user data: $e');
    }
  }

  // SALES ORDER #################################################
  // Fungsi untuk fetch master data
  Future<List<Map<String, dynamic>>> fetchSalespersons() async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'hr.employee',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': ['id', 'name'], // Fetch the ID and name of employees
          'domain': [
            ['active', '=', true]
          ], // Optionally fetch only active employees
        },
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch salespersons: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCompanies() async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'res.company',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch companies: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPaymentTerms() async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'account.payment.term',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch payment terms: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchWarehouses() async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'stock.warehouse',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': ['id', 'name', 'lot_stock_id'],
        },
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch warehouses: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCustomers() async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'res.partner',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'street',
            'phone',
            'vat',
            'property_payment_term_id'
          ],
        },
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch customers: $e');
    }
  }

  // Membuat Quotation Baru
  Future<int> createQuotation(Map<String, dynamic> data) async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'sale.order',
        'method': 'create',
        'args': [data],
      });
      return response as int; // Return ID Quotation yang dibuat
    } catch (e) {
      throw Exception('Failed to create quotation: $e');
    }
  }

  // Fungsi untuk membuat Header Quotation
  Future<int> createQuotationHeader(Map<String, dynamic> headerData) async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'sale.order',
        'method': 'create',
        'args': [headerData], // The data to be saved
        'kwargs': {}, // Empty kwargs to satisfy the required parameter
      });
      return response as int; // The created quotation ID
    } catch (e) {
      throw Exception('Failed to create quotation header: $e');
    }
  }

  // Add a line to an existing quotation
  // In your odoo_service.dart file, add or update the following method:
  Future<int> addQuotationLine(
      int orderId, Map<String, dynamic> lineData) async {
    try {
      // Ensure the session is active
      await checkSession();

      Map<String, dynamic> values = {};

      // If it's a note line
      if (lineData['display_type'] == 'line_note') {
        // For note lines, only send these required fields
        values = {
          'order_id': orderId,
          'display_type': 'line_note', // This is critical
          'name': lineData['name'],
          // No product_id, product_uom, or other accountable fields needed
        };
      } else {
        // For regular product lines
        values = {
          'order_id': orderId,
          'product_id': lineData['product_id'],
          'name': lineData['name'],
          'product_uom_qty': lineData['product_uom_qty'],
          'product_uom': lineData['product_uom'],
          'price_unit': lineData['price_unit'],
        };

        // Add product_template_id if it exists in the lineData
        if (lineData.containsKey('product_template_id')) {
          values['product_template_id'] = lineData['product_template_id'];
        }
      }

      // Use OdooRPC client to create the sale order line
      final response = await _client.callKw({
        'model': 'sale.order.line',
        'method': 'create',
        'args': [values],
        'kwargs': {},
      });

      return response;
    } catch (e) {
      print('Error adding quotation line: $e');
      throw Exception('Failed to add quotation line: $e');
    }
  }

  // Fetch daftar sale order (quotation)
  Future<List<Map<String, dynamic>>> fetchQuotations({
    required int limit,
    required int offset,
    String searchQuery = '',
  }) async {
    if (currentUsername == null) {
      throw Exception('User is not logged in.');
    }

    try {
      // Ambil informasi pengguna dari res.users berdasarkan currentUsername
      final userResponse = await _client.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['login', '=', currentUsername]
          ],
          'fields': ['id', 'name'],
          'limit': 1,
        },
      });

      if (userResponse.isEmpty) {
        throw Exception('User not found.');
      }

      final userId = userResponse[0]['name'];

      // Gabungkan domain pencarian
      List<dynamic> domain = [
        ['user_member_id', '=', userId] // Filter berdasarkan user_id
      ];

      if (searchQuery.isNotEmpty) {
        domain = [
          ...domain,
          '|', // Tambahkan filter pencarian
          ['name', 'ilike', searchQuery],
          ['partner_id', 'ilike', searchQuery]
        ];
      }

      // Panggil data sale.order
      final response = await _client.callKw({
        'model': 'sale.order',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': domain,
          'fields': [
            'id',
            'name',
            'partner_id',
            'partner_shipping_id',
            'partner_invoice_id',
            'date_order',
            'amount_total',
            'state',
            'user_member_id',
          ],
          'limit': limit,
          'offset': offset,
          'order': 'name desc',
        },
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch quotations: $e');
    }
  }

  Future<Map<String, dynamic>> fetchQuotationById(int quotationId) async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'sale.order',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', quotationId]
          ]
        ],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'partner_id',
            'partner_invoice_id', // Invoice Address
            'partner_shipping_id', // Delivery Address
            'user_id',
            'order_line', // Order Lines
            'payment_term_id',
            'vat',
            'warehouse_id',
            'date_order', // Quotation Date
            'amount_total',
            'amount_untaxed',
            'tax_totals',
            'state',
            'user_member_id',
            'notes', // Explicitly include the notes field
          ],
          'limit': 1, // Fetch only one record
        },
      });
      if (response.isEmpty) {
        throw Exception('Quotation not found with ID: $quotationId');
      }
      // Handle missing or empty notes field
      final quotation = Map<String, dynamic>.from(response[0]);
      quotation['notes'] =
          (quotation['notes'] == false || quotation['notes'] == null)
              ? '' // Replace `false` or `null` with an empty string
              : quotation['notes'].toString(); // Ensure notes is a string
      return quotation;
    } catch (e) {
      throw Exception('Failed to fetch quotation by ID: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchOrderLines(
    List<int> orderLineIds) async {
  await checkSession();
  try {
    // Ambil data order lines
    final response = await _client.callKw({
      'model': 'sale.order.line',
      'method': 'read',
      'args': [orderLineIds],
      'kwargs': {
        'fields': [
          'product_id', // Product
          'name', // Description
          'product_uom_qty', // Quantity
          'price_unit', // Unit Price
          'price_subtotal', // Subtotal
          'price_total', // Total
          'tax_id', // Taxes
          'product_uom', // UoM
          'display_type', // Display Type (for line_note)
        ],
      },
    });

    // Casting respons ke List<Map<String, dynamic>>
    final List<Map<String, dynamic>> parsedResponse =
        List<Map<String, dynamic>>.from(
            response.map((item) => item as Map<String, dynamic>));

    // Ekstrak semua ID pajak dari order lines
    final taxIds = parsedResponse
        .where((line) => line['tax_id'] is List && line['tax_id'].isNotEmpty)
        .map((line) => line['tax_id'][0])
        .toSet()
        .toList();

    // Ambil detail pajak dari model account.tax
    final taxDetails = await _client.callKw({
      'model': 'account.tax',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['id', 'in', taxIds]
        ], // Filter berdasarkan ID pajak
        'fields': ['id', 'display_name'], // Ambil ID dan nama pajak
      },
    });

    // Casting taxDetails ke List<Map<String, dynamic>>
    final List<Map<String, dynamic>> parsedTaxDetails =
        List<Map<String, dynamic>>.from(
            taxDetails.map((item) => item as Map<String, dynamic>));

    // Buat pemetaan ID pajak ke nama pajak
    final taxNameMap = Map.fromEntries(
      parsedTaxDetails.map((tax) {
        return MapEntry(tax['id'], tax['display_name']);
      }),
    );

    // Ekstrak semua ID produk unik dari order lines
    final productIds = parsedResponse
        .where((line) => line['product_id'] is List && line['product_id'].isNotEmpty)
        .map((line) => line['product_id'][0])
        .toSet()
        .toList();

    // Ambil data produk termasuk gambar dari model product.product
    final productDetails = await _client.callKw({
      'model': 'product.product',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'domain': [
          ['id', 'in', productIds]
        ], // Filter berdasarkan ID produk
        'fields': ['id', 'image_1920'], // Ambil ID dan gambar produk
      },
    });

    // Casting productDetails ke List<Map<String, dynamic>>
    final List<Map<String, dynamic>> parsedProductDetails =
        List<Map<String, dynamic>>.from(
            productDetails.map((item) => item as Map<String, dynamic>));

    // Buat pemetaan ID produk ke gambar produk
    final productImageMap = Map.fromEntries(
      parsedProductDetails.map((product) {
        return MapEntry(product['id'], product['image_1920']);
      }),
    );

    // Proses data order lines untuk menambahkan nama pajak dan gambar produk
    return parsedResponse.map((line) {
      final taxId = line['tax_id'] is List && line['tax_id'].isNotEmpty
          ? line['tax_id'][0]
          : null; // Ambil ID pajak
      final taxName =
          taxId != null ? taxNameMap[taxId] : 'No Tax'; // Cari nama pajak

      final productId = line['product_id'] is List && line['product_id'].isNotEmpty
          ? line['product_id'][0]
          : null; // Ambil ID produk
      final productImage =
          productId != null ? productImageMap[productId] : null; // Cari gambar produk

      return {
        ...line,
        'tax_id': taxId, // Simpan ID pajak
        'tax_name': taxName, // Simpan nama pajak
        'image_1920': productImage, // Simpan gambar produk
      };
    }).toList();
  } catch (e) {
    throw Exception('Failed to fetch order lines: $e');
  }
}

  Future<List<Map<String, dynamic>>> fetchCustomerAddresses(
      int customerId) async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'res.partner',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['parent_id', '=', customerId], // Mengambil anak dari customer
            [
              'type',
              'in',
              ['invoice', 'delivery']
            ], // Ambil tipe invoice/delivery
          ],
          'fields': [
            'id',
            'name',
            'street',
            'type',
            'vat'
          ], // Dapatkan ID, nama, alamat, dan tipe
        },
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch customer addresses: $e');
    }
  }

  Future<String> fetchDeliveryOrderStatus(String saleOrderName) async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'stock.picking',
        'method': 'search_read',
        'args': [
          [
            ['origin', '=', saleOrderName],
          ]
        ],
        'kwargs': {
          'fields': ['state', 'name'],
          'limit': 1,
        },
      });

      print('Response from Odoo: $response'); // Debug response

      if (response.isNotEmpty) {
        final state = response[0]['state'];
        return state ?? 'unknown';
      }
      return 'not_found';
    } catch (e) {
      print('Error: $e'); // Debug error
      throw Exception('Failed to fetch delivery order status: $e');
    }
  }

  Future<String> fetchInvoiceStatus(String saleOrderName) async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'account.move',
        'method': 'search_read',
        'args': [
          [
            ['invoice_origin', '=', saleOrderName]
          ]
        ],
        'kwargs': {
          'fields': ['payment_state'],
          'limit': 1,
        },
      });
      print('Response from Odoo: $response'); // Debug response
      if (response.isNotEmpty) {
        return response[0]['payment_state'] ?? 'unknown';
      }
      return 'not_found';
    } catch (e) {
      throw Exception('Failed to fetch invoice status: $e');
    }
  }

  Future<void> confirmQuotation(int quotationId) async {
    await checkSession();
    try {
      await _client.callKw({
        'model': 'sale.order',
        'method': 'action_confirm',
        'args': [quotationId],
        'kwargs': {},
      });
    } catch (e) {
      throw Exception('Failed to confirm quotation: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCollections() async {
    await checkSession();

    if (currentUsername == null) {
      throw Exception('User is not logged in.');
    }

    try {
      final responseUser = await _client.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['login', '=', currentUsername]
          ],
          'fields': ['name'],
          'limit': 1,
        },
      });

      if (responseUser.isEmpty) {
        throw Exception('User not found.');
      }

      final nameUser = responseUser[0]['name'];

      // Ambil koleksi berdasarkan salesman ID yang sesuai dengan nameUser
      final response = await _client.callKw({
        'model': 'invoice.collection',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['invoice_origin', '=', '2'], // Filter invoice_origin = 2
            ['invoice_destination', '=', '4'], // Filter invoice_destination = 3
            [
              'salesman',
              '=',
              nameUser
            ], // Hanya data dengan salesman sesuai user login
          ],
          'fields': [
            'name',
            'state',
            'create_date',
            'transfer_date',
            'create_uid',
            'invoice_origin',
            'invoice_destination',
            'salesman',
          ],
          'order':
              'create_date desc', // Urutkan berdasarkan create_date terbaru
        },
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch collections: $e');
    }
  }

  Future<void> createCollection({
    required String invoiceOrigin,
    required String invoiceDestination,
    required DateTime transferDate,
    String? notes,
    required List<int> accountMoveIds,
  }) async {
    await checkSession();
    try {
      final formattedDate = DateFormat('MM/dd/yyyy').format(transferDate);

      // Log data yang akan dikirim
      print({
        'invoice_origin': invoiceOrigin,
        'invoice_destination': invoiceDestination,
        'transfer_date': formattedDate,
        'notes': notes ?? '',
        'account_move_ids': [6, 0, accountMoveIds],
      });

      await _client.callKw({
        'model': 'invoice.collection',
        'method': 'create',
        'args': [
          {
            'invoice_origin': invoiceOrigin,
            'invoice_destination': invoiceDestination,
            'transfer_date': formattedDate,
            'notes': notes ?? '',
            'account_move_ids': [6, 0, accountMoveIds],
          },
        ],
        'kwargs': {},
      });
    } catch (e) {
      throw Exception('Failed to create collection: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchInvoices({
    required String invoiceOrigin,
  }) async {
    await checkSession(); // Pastikan sesi valid
    try {
      // Fetch invoices berdasarkan logika di `_compute_suitable_account_ids`
      final response = await _client.callKw({
        'model': 'account.move',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            [
              'check_payment_invoice',
              '=',
              false
            ], // Tidak di-check sebagai payment invoice
            [
              'invoice_status',
              'in',
              [invoiceOrigin, '3_done']
            ], // Invoice status sesuai origin atau '3_done'
            [
              'payment_state',
              'in',
              ['not_paid', 'partial']
            ], // Belum lunas atau parsial
            ['state', '=', 'posted'], // Harus sudah diposting
            ['move_type', '=', 'out_invoice'], // Tipe invoice penjualan
          ],
          'fields': [
            'id',
            'name',
            'partner_id',
            'amount_total',
            'payment_state',
            'state',
            'invoice_status',
            'date',
          ], // Ambil field yang dibutuhkan
          'order': 'date desc', // Urutkan berdasarkan tanggal terbaru
        },
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch invoices: $e');
    }
  }

  Future<Map<String, dynamic>> fetchCollectionDetail(int id) async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'invoice.collection',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['id', '=', id]
          ], // Ambil collection berdasarkan ID
          'fields': [
            'name',
            'state',
            'invoice_origin',
            'invoice_destination',
            'transfer_date',
            'create_date',
            'notes',
            'salesman',
            'account_move_ids',
          ],
          'limit': 1, // Ambil hanya 1 record
        },
      });

      return response.isNotEmpty
          ? Map<String, dynamic>.from(response.first)
          : {};
    } catch (e) {
      throw Exception('Failed to fetch collection detail: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchInvoiceDetails(List<int> ids) async {
    if (ids.isEmpty) return []; // Jika tidak ada ID, return list kosong
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'account.move',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['id', 'in', ids]
          ], // Filter berdasarkan ID
          'fields': [
            'id',
            'name',
            'partner_id', // Customer
            'amount_total_signed', // Total Amount
            'amount_total',
            'amount_residual_signed', // Amount Due
            'amount_residual',
            'payment_state', // Payment State
            'receipt_via', // Receipt Method
            'check_payment_invoice', // Check Status
            'partial_total_payment', // Total Payment
          ],
        },
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch invoice details: $e');
    }
  }

  Future<void> updateInvoicePayment({
    required int invoiceId,
    required double amount,
    required bool isCheck,
    String? receiptVia,
    int? checkbookId,
  }) async {
    await checkSession();
    try {
      await _client.callKw({
        'model': 'account.move',
        'method': 'write',
        'args': [
          [invoiceId], // ID dari invoice yang akan diupdate
          {
            'partial_total_payment': amount,
            'check_payment_invoice': isCheck,
            'receipt_via': receiptVia,
            'checkbook_id': checkbookId,
          },
        ],
        'kwargs': {}, // kwargs tetap diperlukan, meskipun kosong
      });
    } catch (e) {
      throw Exception('Failed to update invoice payment: $e');
    }
  }

  Future<void> confirmWizardAction(int wizardId) async {
    try {
      await _client.callKw({
        'model': 'collection.payment.wizard',
        'method': 'action_confirm',
        'args': [
          [wizardId]
        ], // Pass the wizard ID
        'kwargs': {},
      });
    } catch (e) {
      throw Exception('Failed to confirm the wizard: $e');
    }
  }

  Future<int> createPaymentWizard({
    required int invoiceId,
    required bool isCheck,
    required double amount,
    String? receiptVia,
    int? checkbookId,
  }) async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'collection.payment.wizard',
        'method': 'create',
        'args': [
          {
            'account_id': invoiceId,
            'check': isCheck,
            'amount_total': amount,
            'receipt_via': receiptVia,
            'checkbook_id': checkbookId,
          }
        ],
        'kwargs': {},
      });

      return response as int; // Return the created wizard ID
    } catch (e) {
      throw Exception('Failed to create payment wizard: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCheckbooks(String partnerId) async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'account.checkbook.line',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            [
              'partner_id',
              '=',
              int.parse(partnerId)
            ], // Filter berdasarkan partner_id
            ['check_residual', '!=', 0], // Hanya checkbook dengan sisa
          ],
          'fields': [
            'id',
            'name',
            'check_residual'
          ], // Ambil ID, nama, dan sisa
        },
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch checkbooks: $e');
    }
  }

  Future<void> cancelQuotation(int quotationId) async {
    await checkSession();
    try {
      // Membuat wizard sale.order.cancel
      final wizardId = await _client.callKw({
        'model': 'sale.order.cancel',
        'method': 'create',
        'args': [
          {
            'order_id': quotationId, // Menggunakan order_id sebagai field utama
          }
        ],
        'kwargs': {
          'context': {}, // Tambahkan context jika diperlukan
        },
      });

      if (wizardId == null) {
        throw Exception('Failed to create cancel wizard.');
      }

      // Menjalankan action_cancel pada wizard
      await _client.callKw({
        'model': 'sale.order.cancel',
        'method': 'action_cancel',
        'args': [
          [wizardId]
        ], // ID dari wizard
        'kwargs': {
          'context': {}, // Tambahkan context jika diperlukan
        },
      });
    } catch (e) {
      throw Exception('Failed to cancel quotation: $e');
    }
  }

  Future<void> setToQuotation(int quotationId) async {
    await checkSession();
    try {
      await _client.callKw({
        'model': 'sale.order',
        'method': 'action_draft',
        'args': [
          [quotationId]
        ], // Mengirimkan ID Quotation
        'kwargs': {}, // Memastikan kwargs disertakan
      });
    } catch (e) {
      throw Exception('Failed to reset quotation to draft: $e');
    }
  }

  Future<void> updateQuotationHeader(
      int quotationId, Map<String, dynamic> data) async {
    await checkSession();
    try {
      print('Updating Quotation Header for ID: $quotationId with Data: $data');

      await _client.callKw({
        'model': 'sale.order',
        'method': 'write',
        'args': [
          [quotationId], // Quotation ID dalam array
          data, // Data yang akan ditulis
        ],
        'kwargs': {}, // Tambahkan kwargs sebagai parameter kosong
      });

      print('Quotation Header updated successfully.');
    } catch (e) {
      print('Error updating Quotation Header: $e');
      throw Exception('Failed to update quotation header: $e');
    }
  }

  Future<void> updateOrderLines(
      int quotationId, List<Map<String, dynamic>> orderLines) async {
    await checkSession();
    for (final line in orderLines) {
      if (line['id'] == null) {
        // Tambahkan order line baru
        await _client.callKw({
          'model': 'sale.order.line',
          'method': 'create',
          'args': [
            {
              'order_id': quotationId, // ID dari Quotation
              'product_id': line['product_id'], // Produk yang dipilih
              'name': line['name'], // Deskripsi produk
              'product_uom_qty': line['product_uom_qty'], // Kuantitas
              'price_unit': line['price_unit'], // Harga unit
            },
          ],
          'kwargs': {},
        });
      } else {
        await _client.callKw({
          'model': 'sale.order.line',
          'method': 'write',
          'args': [
            [line['id']],
            {
              'product_uom_qty': line['product_uom_qty'],
              'price_unit': line['price_unit'],
            },
          ],
          'kwargs': {},
        });
      }
    }
  }

  Future<void> deleteOrderLine(int lineId) async {
    await checkSession();
    try {
      await _client.callKw({
        'model': 'sale.order.line',
        'method': 'unlink',
        'args': [
          [lineId]
        ], // Hapus berdasarkan ID
        'kwargs': {},
      });
    } catch (e) {
      throw Exception('Failed to delete order line: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchGiroBook() async {
    await checkSession();

    if (currentUsername == null) {
      throw Exception('User is not logged in.');
    }

    try {
      // Fetch the current user's ID based on their username
      final responseUser = await _client.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['login', '=', currentUsername]
          ],
          'fields': ['id'],
          'limit': 1,
        },
      });

      if (responseUser.isEmpty) {
        throw Exception('User not found.');
      }

      final userId = responseUser[0]['id']; // Get the user's ID

      // Fetch giro book data filtered by the current user's ID
      final response = await _client.callKw({
        'model': 'account.checkbook',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['user_id', '=', userId] // Filter by the logged-in user's ID
          ],
          'fields': [
            'name',
            'date',
            'payment_type',
            'partner_id',
            'user_id',
            'total_check',
            'residual_check',
            'state',
          ],
          'order': 'date desc', // Sort by date in descending order
        },
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch giro book: $e');
    }
  }

  // Fetch Checkbook Header Details
  Future<Map<String, dynamic>> fetchCheckBookById(int checkBookId) async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'account.checkbook',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['id', '=', checkBookId]
          ],
          'fields': [
            'name',
            'date',
            'payment_type',
            'partner_id',
            'user_id',
            'state',
            'total_check',
            'residual_check',
          ],
          'limit': 1,
        },
      });
      if (response.isEmpty) {
        throw Exception('Checkbook not found with ID: $checkBookId');
      }
      return Map<String, dynamic>.from(response[0]);
    } catch (e) {
      throw Exception('Failed to fetch checkbook details: $e');
    }
  }

// Fetch Checkbook Line Items
  Future<List<Map<String, dynamic>>> fetchCheckBookLinesByCheckBookId(
      int checkBookId) async {
    await checkSession();
    try {
      // Fetch checkbook lines
      final response = await _client.callKw({
        'model': 'account.checkbook.line',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['checkbook_id', '=', checkBookId]
          ],
          'fields': [
            'name',
            'partner_bank_id',
            'date',
            'date_end',
            'check_amount',
            'check_residual',
            'payment_ids',
            'state',
            'payment_status',
          ],
        },
      });

      // Process each line to fetch payment names
      for (var line in response) {
        final paymentIds = line['payment_ids'] as List<dynamic>? ?? [];
        if (paymentIds.isNotEmpty) {
          final paymentNames = await _fetchPaymentNames(paymentIds);
          line['payment_names'] =
              paymentNames.join(', '); // Combine names into a single string
        } else {
          line['payment_names'] = ''; // Default message if no payments
        }
      }

      print(
          'Fetched Check Book Lines with Payment Names: $response'); // Log the response
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch checkbook lines: $e');
    }
  }

  Future<List<String>> _fetchPaymentNames(List<dynamic> paymentIds) async {
    try {
      final response = await _client.callKw({
        'model': 'account.payment',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['id', 'in', paymentIds]
          ],
          'fields': ['name'], // Only fetch the 'name' field
        },
      });
      return List<String>.from(response.map((payment) => payment['name']));
    } catch (e) {
      throw Exception('Failed to fetch payment names: $e');
    }
  }

  // Future<Map<String, dynamic>> fetchWarehouseDetails(int warehouseId) async {
  //   await checkSession(); // Pastikan sesi valid
  //   try {
  //     final response = await _client.callKw({
  //       'model': 'stock.warehouse',
  //       'method': 'read',
  //       'args': [
  //         [warehouseId]
  //       ],
  //       'kwargs': {
  //         'fields': ['lot_stock_id']
  //       },
  //     });

  //     if (response.isEmpty || response[0]['lot_stock_id'] == null) {
  //       throw Exception('Failed to fetch warehouse or lot_stock_id.');
  //     }

  //     return Map<String, dynamic>.from(response[0]);
  //   } catch (e) {
  //     throw Exception('Failed to fetch warehouse details: $e');
  //   }
  // }

  // Future<List<Map<String, dynamic>>> fetchProductsByWarehouse(
  //     int lotStockId) async {
  //   await checkSession(); // Pastikan sesi valid
  //   try {
  //     // Ambil data dari stock.quant untuk produk dengan location_id == lot_stock_id
  //     final quantResponse = await _client.callKw({
  //       'model': 'stock.quant',
  //       'method': 'search_read',
  //       'args': [],
  //       'kwargs': {
  //         'domain': [
  //           ['location_id', '=', lotStockId],
  //         ],
  //         'fields': ['product_id', 'inventory_quantity_auto_apply'],
  //       },
  //     });

  //     // Group quantities by product_id
  //     Map<int, double> productQuantities = {};

  //     for (var quant in quantResponse) {
  //       if (quant['product_id'] is List && quant['product_id'].isNotEmpty) {
  //         final productId = quant['product_id'][0];
  //         final qty = quant['inventory_quantity_auto_apply'] ?? 0;

  //         // Sum up quantities for the same product
  //         if (productQuantities.containsKey(productId)) {
  //           productQuantities[productId] = productQuantities[productId]! + qty;
  //         } else {
  //           productQuantities[productId] = qty;
  //         }
  //       }
  //     }

  //     // Filter out products with non-positive quantities
  //     final validProductIds = productQuantities.entries
  //         .where((entry) => entry.value > 0)
  //         .map((entry) => entry.key)
  //         .toList();

  //     if (validProductIds.isEmpty) {
  //       return []; // Return empty list if no products found
  //     }

  //     // Ambil detail produk dari product.product berdasarkan product_ids
  //     final productResponse = await _client.callKw({
  //       'model': 'product.product',
  //       'method': 'read',
  //       'args': [validProductIds],
  //       'kwargs': {
  //         'fields': [
  //           'id',
  //           'name',
  //           'default_code',
  //           'list_price',
  //           'image_1920',
  //           'uom_id',
  //         ],
  //       },
  //     });

  //     // Create final products list with aggregated quantities
  //     final List<Map<String, dynamic>> productsWithStock = [];

  //     for (var product in productResponse) {
  //       final productId = product['id'];
  //       final qty = productQuantities[productId] ?? 0;

  //       if (qty > 0) {
  //         Map<String, dynamic> productWithStock =
  //             Map<String, dynamic>.from(product);
  //         productWithStock['qty_available'] = qty;
  //         productsWithStock.add(productWithStock);
  //       }
  //     }

  //     return productsWithStock;
  //   } catch (e) {
  //     throw Exception('Failed to fetch products by warehouse: $e');
  //   }
  // }

  Future<void> callMethod(String model, String method, List<dynamic> args,
      [Map<String, dynamic>? kwargs]) async {
    await checkSession(); // Pastikan sesi masih aktif
    try {
      await _client.callKw({
        'model': model,
        'method': method,
        'args': args,
        'kwargs': kwargs ?? {},
      });
    } catch (e) {
      throw Exception('RPC call failed: $e');
    }
  }

  Future<void> createNoteLine(int quotationId, String note) async {
    await checkSession();
    try {
      await _client.callKw({
        'model': 'sale.order.line',
        'method': 'create',
        'args': [
          {
            'order_id': quotationId,
            'display_type': 'line_note',
            'name': note,
            'product_uom_qty': 0, // Not needed for notes
            'price_unit': 0, // Not needed for notes
          },
        ],
        'kwargs': {},
      });
    } catch (e) {
      throw Exception('Failed to create note line: $e');
    }
  }

  Future<void> updateNoteLine(int lineId, String note) async {
    await checkSession();
    try {
      await _client.callKw({
        'model': 'sale.order.line',
        'method': 'write',
        'args': [
          [lineId],
          {
            'name': note,
          },
        ],
        'kwargs': {},
      });
    } catch (e) {
      throw Exception('Failed to update note line: $e');
    }
  }

  Future<void> createProductLine(int quotationId, int productId, String name,
      int quantity, double price) async {
    await checkSession();
    try {
      await _client.callKw({
        'model': 'sale.order.line',
        'method': 'create',
        'args': [
          {
            'order_id': quotationId,
            'product_id': productId,
            'name': name,
            'product_uom_qty': quantity,
            'price_unit': price,
          },
        ],
        'kwargs': {},
      });
    } catch (e) {
      throw Exception('Failed to create product line: $e');
    }
  }

  Future<void> updateProductLine(int lineId, int quantity, double price) async {
    await checkSession();
    try {
      await _client.callKw({
        'model': 'sale.order.line',
        'method': 'write',
        'args': [
          [lineId],
          {
            'product_uom_qty': quantity,
            'price_unit': price,
          },
        ],
        'kwargs': {},
      });
    } catch (e) {
      throw Exception('Failed to update product line: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': ['id', 'name', 'login', 'image_1920'],
        },
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  Future<int> createCheckBook(Map<String, dynamic> checkBookData) async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'account.checkbook',
        'method': 'create',
        'args': [checkBookData],
        'kwargs': {},
      });

      return response;
    } catch (e) {
      throw Exception('Failed to create check book: $e');
    }
  }

  Future<void> updateCheckBook(
      int checkBookId, Map<String, dynamic> values) async {
    await checkSession();
    try {
      await _client.callKw({
        'model': 'account.checkbook',
        'method': 'write',
        'args': [
          [checkBookId], // ID must be in a list
          values // Values to update
        ],
        'kwargs': {},
      });
    } catch (e) {
      throw Exception('Failed to update check book: $e');
    }
  }

  // Create a new checkbook line
  Future<int> createCheckBookLine(
      Map<String, dynamic> checkBookLineData) async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'account.checkbook.line',
        'method': 'create',
        'args': [checkBookLineData],
        'kwargs': {},
      });
      return response; // Return the ID of the newly created line
    } catch (e) {
      throw Exception('Failed to create checkbook line: $e');
    }
  }

  Future<Map<String, dynamic>> fetchCheckBookLine(int checkBookLineId) async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'account.checkbook.line',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['id', '=', checkBookLineId]
          ], // Filter by ID
          'fields': [
            'name', // Giro number
            'date', // Giro date
            'date_end', // Giro expiry date
            'check_amount', // Amount
            'partner_bank_id', // Bank ID
          ],
          'limit': 1, // Fetch only one record
        },
      });
      return response.isNotEmpty
          ? Map<String, dynamic>.from(response.first)
          : {};
    } catch (e) {
      throw Exception('Failed to fetch checkbook line details: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchBanks(int partnerId) async {
    await checkSession();
    try {
      final response = await _client.callKw({
        'model': 'res.partner.bank',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['partner_id', '=', partnerId], // Filter by partner_id
            ['active', '=', true], // Only active banks
          ],
          'fields': [
            'id', // Bank ID
            'acc_number', // Bank Account Number
            'bank_name', // Bank Name
            'bank_bic', // Bank BIC/SWIFT Code
            'currency_id', // Currency
          ],
        },
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch banks: $e');
    }
  }

  Future<void> updateCheckBookLine(
      int lineId, Map<String, dynamic> values) async {
    await checkSession();
    try {
      await _client.callKw({
        'model': 'account.checkbook.line',
        'method': 'write',
        'args': [lineId, values],
        'kwargs': {},
      });
    } catch (e) {
      throw Exception('Failed to update check book line: $e');
    }
  }

  Future<void> deleteCheckBookLine(int lineId) async {
    await checkSession();
    try {
      await _client.callKw({
        'model': 'account.checkbook.line',
        'method': 'unlink',
        'args': [lineId],
        'kwargs': {},
      });
    } catch (e) {
      throw Exception('Failed to delete check book line: $e');
    }
  }

  Future<void> confirmGiroBook(int checkBookId) async {
    await checkSession();
    try {
      await _client.callKw({
        'model': 'account.checkbook',
        'method': 'confirm_check',
        'args': [checkBookId],
        'kwargs': {},
      });
    } catch (e) {
      throw Exception('Failed to confirm giro book: $e');
    }
  }
}
