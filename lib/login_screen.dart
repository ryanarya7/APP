import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'odoo_service.dart';
import 'navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  final OdooService odooService;

  const LoginScreen({super.key, required this.odooService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _databaseController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isLoginSuccess = false; // Status keberhasilan login
  bool _passwordVisible = false; // State untuk toggle visibility password
  bool _isError = false; // Status untuk mengatur field merah saat error
  String? _errorMessage; // Pesan error
  late AnimationController _shakeController; // Kontrol untuk animasi getar

  @override
  void initState() {
    super.initState();
    _databaseController.text = 'bpa';
    _usernameController.text = 'fathur';
    _passwordController.text = 'a';

    // Inisialisasi AnimationController untuk getar
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _databaseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _isError = false; // Reset error status
      _errorMessage = null; // Reset pesan error
    });

    try {
      await widget.odooService.login(
        _databaseController.text.trim(),
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      // Jika login berhasil
      setState(() {
        _isLoginSuccess = true; // Animasi berubah menjadi ceklis
      });

      // Tunggu animasi selesai sebelum navigasi
      await Future.delayed(const Duration(seconds: 2));

      // Navigasi ke halaman Hello
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HelloScreen(
            username: _usernameController.text.trim(),
            odooService: widget.odooService,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isError = true; // Set error state untuk animasi getar dan field merah
        _errorMessage =
            "Invalid credentials or user not found. Please try again.";
        _isLoginSuccess = false; // Tetap tampilkan ikon default jika gagal
        print("Login error: $e");
      });

      // Jalankan animasi getar pada field
      _shakeController.forward(from: 0);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Widget untuk getar field input
  Widget _buildShakeWidget({required Widget child}) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final offset = _isError
            ? 10.0 *
                (1 - _shakeController.value) *
                (_shakeController.value % 0.5 == 0 ? 1 : -1)
            : 0.0; // Posisi awal tetap di tengah
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: child,
    );
  }

  // Wrapper untuk field input dengan border merah jika terjadi error
  InputDecoration _getInputDecoration({required String label, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      prefixIcon: icon != null ? Icon(icon) : null,
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: _isError ? Colors.red : Colors.blue, // Border merah jika error
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: _isError ? Colors.red : Colors.grey, // Border merah jika error
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Animation
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isError
                      ? [
                          Colors.red[300]!,
                          Colors.white
                        ] // Gradien merah dan putih saat error
                      : (_isLoading
                          ? [Colors.blue[300]!, Colors.green[700]!]
                          : [Colors.white, Colors.grey[700]!]),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 400, // Maksimal lebar 400 piksel
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Logo with Checkmark Transition
                      AnimatedCrossFade(
                        firstChild: const Icon(
                          Icons.account_circle,
                          size: 100,
                          color: Colors.white,
                        ),
                        secondChild: const Icon(
                          Icons.check_circle,
                          size: 100,
                          color: Colors.white,
                        ),
                        crossFadeState: _isLoginSuccess
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(seconds: 1),
                      ),
                      const SizedBox(height: 20),
                      // Title
                      const Text(
                        'Welcome to Odoo',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      // Shimmering Text
                      Shimmer.fromColors(
                        baseColor: Colors.white,
                        highlightColor: Colors.grey[300]!,
                        child: const Text(
                          'Powered by Alphasoft',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Input Fields
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildShakeWidget(
                                child: TextField(
                                  controller: _databaseController,
                                  decoration: _getInputDecoration(
                                    label: 'Database',
                                    icon: Icons.storage,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildShakeWidget(
                                child: TextField(
                                  controller: _usernameController,
                                  decoration: _getInputDecoration(
                                    label: 'Username',
                                    icon: Icons.person,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildShakeWidget(
                                child: TextField(
                                  controller: _passwordController,
                                  decoration: _getInputDecoration(
                                    label: 'Password',
                                    icon: Icons.lock,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _passwordVisible
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _passwordVisible = !_passwordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                  obscureText: !_passwordVisible,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Login Button
                      _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'Loading',
                                  style: TextStyle(color: Colors.white),
                                ),
                                SizedBox(width: 8),
                                SizedBox(
                                  height: 15,
                                  width: 15,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ],
                            )
                          : ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 50, vertical: 15),
                                backgroundColor: Colors.grey[900],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                      // Error Message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HelloScreen extends StatefulWidget {
  final String username;
  final OdooService odooService;

  const HelloScreen({
    super.key,
    required this.username,
    required this.odooService,
  });

  @override
  State<HelloScreen> createState() => _HelloScreenState();
}

class _HelloScreenState extends State<HelloScreen> {
  String? _fullName; // Nama lengkap pengguna
  bool _isLoading = true; // Status loading untuk fetch data

  @override
  void initState() {
    super.initState();
    _fetchUserName(); // Ambil nama pengguna saat screen dimulai
  }

  Future<void> _fetchUserName() async {
    try {
      // Panggil fetchUser dari OdooService
      final userData = await widget.odooService.fetchUser(widget.username);

      setState(() {
        _fullName = userData['name']; // Ambil nama lengkap dari data user
        _isLoading = false; // Matikan status loading
      });

      // Setelah beberapa detik, navigasi ke halaman berikutnya
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                NavigationScreen(odooService: widget.odooService),
          ),
        );
      });
    } catch (e) {
      setState(() {
        _fullName = 'Error fetching user';
        _isLoading = false; // Tetap matikan status loading meskipun error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Animation
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[300]!, Colors.blue[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Animated Text in Center
          Center(
            child: _isLoading
                ? const CircularProgressIndicator(
                    color: Colors.white,
                  )
                : TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 1),
                    tween: Tween(begin: 0, end: 1),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 50),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      'Hello, ${_fullName ?? 'User'}!',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
