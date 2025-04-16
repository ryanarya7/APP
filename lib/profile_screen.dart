import 'dart:convert';
import 'package:flutter/material.dart';
import 'odoo_service.dart';

class ProfileScreen extends StatelessWidget {
  final OdooService odooService;

  const ProfileScreen({super.key, required this.odooService});

  ImageProvider? _getImageProvider(dynamic imageData) {
    if (imageData == null || imageData is! String || imageData.isEmpty) {
      return null;
    }

    try {
      // Clean the base64 string - remove potential padding or metadata
      String cleanedImage = imageData.trim();

      // If it contains a data URI prefix, remove it
      if (cleanedImage.contains(';base64,')) {
        cleanedImage = cleanedImage.split(';base64,')[1];
      }

      // Decode the base64 string
      final imageBytes = base64Decode(cleanedImage);

      // Return null if we have no actual image data
      if (imageBytes.isEmpty) {
        return null;
      }

      return MemoryImage(imageBytes);
    } catch (e) {
      debugPrint('Error processing profile image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: (() async {
          try {
            await odooService.checkSession(); // Validasi sesi
            return odooService.fetchUser(); // Ambil data pengguna
          } catch (e) {
            if (e.toString().contains('Session expired')) {
              throw Exception('Session expired. Please log in again.');
            }
            rethrow;
          }
        })(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error.toString();
            if (error.contains('Session expired')) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Session expired. Please log in again.",
                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 15),
                      ),
                      child: const Text("Login"),
                    ),
                  ],
                ),
              );
            }
            return Center(
              child: Text("Error loading data: $error"),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("No user data available"));
          }

          final user = snapshot.data!;
          return Stack(
            children: [
              // Background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[300]!, Colors.blue[700]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              // Profile Content
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated Avatar
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.blue[100],
                        backgroundImage: _getImageProvider(user['image_1920']),
                        child: _getImageProvider(user['image_1920']) == null
                            ? const Icon(Icons.person,
                                size: 60, color: Colors.blue)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      // User Name
                      Text(
                        user['name'],
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // User Login
                      Text(
                        user['login'],
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Logout Button
                      ElevatedButton.icon(
                        onPressed: () {
                          odooService.logout();
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text(
                          "Logout",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
