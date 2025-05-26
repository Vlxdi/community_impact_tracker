import 'dart:ui';
import 'package:community_impact_tracker/main.dart';
import 'package:community_impact_tracker/outer_pages/admin_panel.dart';
import 'package:community_impact_tracker/utils/addSpace.dart';
import 'package:community_impact_tracker/utils/countriesList.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _username = '';
  String _email = '';
  String _password = '';
  final String _profile_picture = '';
  double _wallet_balance = 0.0; // Change type to double
  String _selectedCountry = '';
  bool _isLoadingLocation = true;
  //add phone registering later
  //final String _phone = '';
  //final String _verificationId = '';
  bool _isRegistering = false;
  // List of countries for dropdown
  final List<String> _countries = countries;

  late final AnimationController _shaderController;
  late Animation<double> _shaderAnimation;
  Future<FragmentProgram>? _shaderProgramFuture;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _shaderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _shaderAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _shaderController, curve: Curves.linear));
    _shaderController.repeat(reverse: true);
    _shaderProgramFuture =
        FragmentProgram.fromAsset('assets/shaders/moving_gradient.frag');
  }

  @override
  void dispose() {
    _shaderController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Handle denied permission
          setState(() {
            _selectedCountry = 'United States'; // Default country
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Handle permanently denied permission
        setState(() {
          _selectedCountry = 'United States'; // Default country
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);

      // Reverse geocoding to get country
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String countryName = place.country ?? 'United States';

        // Check if country exists in our list
        if (_countries.contains(countryName)) {
          setState(() {
            _selectedCountry = countryName;
          });
        } else {
          setState(() {
            _selectedCountry =
                'United States'; // Default if country not in list
          });
        }
      } else {
        setState(() {
          _selectedCountry = 'United States'; // Default if geocoding fails
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _selectedCountry = 'United States'; // Default on error
      });
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  bool _isValidUsername(String username) {
    return username.length >= 4 && username.length <= 20;
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(email);
  }

  bool _isValidPassword(String password) {
    final passwordRegex = RegExp(
        r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,16}$');
    return passwordRegex.hasMatch(password);
  }

  void _register() async {
    if (!_isValidUsername(_username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Username must be 4-20 characters long.')),
      );
      return;
    }

    if (!_isValidEmail(_email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    if (!_isValidPassword(_password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Password must be 8-16 characters long, include an uppercase letter, a lowercase letter, a number, and a special character.')),
      );
      return;
    }

    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _email,
        password: _password,
      );

      if (mounted) {
        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'username': _username,
          'email': _email,
          'profile_picture': '', // Empty profile picture field
          'wallet_balance': 0.0, // Initial wallet balance as double
          'location': _selectedCountry, // Save the selected country
          'total_points': 0.0, // Initial total points as double
          'level': 1, // Initial level of 0
        });

        // Ensure user_events document is created with createdAt field
        await _firestore
            .collection('user_events')
            .doc(userCredential.user?.uid)
            .set({
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Automatically navigate the user to the app
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainPage(initialIndex: 3)),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return; // Prevent showing a snackbar if unmounted
      if (e.code == 'email-already-in-use') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('The email is already registered. Please log in.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred.')),
        );
      }
    }
  }

  void _login() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _email, password: _password);

      // Predefined admin email
      const String adminEmail = "admin@goodtrack.com";

      // Check if the logged-in user is the admin
      if (userCredential.user?.email == adminEmail) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => AdminPanel()), // Navigate to Admin Panel
        );
        return;
      }

      // For regular users, retrieve the username
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user?.uid)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          _username = userDoc.data()?['username'] ?? '';
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainPage(initialIndex: 3)),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User data not found.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Login failed, check if your email and password are valid')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<FragmentProgram>(
        future: _shaderProgramFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final program = snapshot.data!;
          return AnimatedBuilder(
            animation: _shaderAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  // Use ShaderPainter here
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ShaderPainter(
                        program: program,
                        time: _shaderAnimation.value * 10.0,
                      ),
                    ),
                  ),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          width: 350,
                          padding: EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white60, Colors.white10],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color.fromARGB(80, 124, 124, 124),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isRegistering ? 'Sign Up' : 'Sign In',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Vspace(18),
                              Container(
                                decoration: BoxDecoration(
                                  // Gradient background for the text fields container
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white60,
                                      Colors.white10,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.18)),
                                ),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Column(
                                  children: [
                                    if (_isRegistering)
                                      Column(
                                        children: [
                                          // Username field with icon
                                          Row(
                                            children: [
                                              Icon(Icons.person_outline,
                                                  color: Colors.grey[600]),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: TextField(
                                                  decoration: InputDecoration(
                                                    hintText: 'Username',
                                                    border: InputBorder.none,
                                                    // Make the field background transparent
                                                    filled: true,
                                                    fillColor:
                                                        Colors.transparent,
                                                  ),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .deny(RegExp(
                                                            r'^\s+|\s+$')),
                                                  ],
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _username = value;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          Divider(),
                                          // Country dropdown
                                          _isLoadingLocation
                                              ? Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 10),
                                                  child: Center(
                                                    child: SizedBox(
                                                      height: 20,
                                                      width: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2),
                                                    ),
                                                  ),
                                                )
                                              : Row(
                                                  children: [
                                                    Icon(Icons.public,
                                                        color:
                                                            Colors.grey[600]),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Stack(
                                                        children: [
                                                          DropdownButtonHideUnderline(
                                                            child:
                                                                DropdownButton<
                                                                    String>(
                                                              isExpanded: true,
                                                              hint: Text(
                                                                  'Select Country'),
                                                              value: _selectedCountry
                                                                      .isEmpty
                                                                  ? null
                                                                  : _selectedCountry,
                                                              items: _countries
                                                                  .map(
                                                                      (country) {
                                                                return DropdownMenuItem<
                                                                    String>(
                                                                  value:
                                                                      country,
                                                                  child: Text(
                                                                      country),
                                                                );
                                                              }).toList(),
                                                              onChanged: null,
                                                              // Disable default dropdown
                                                            ),
                                                          ),
                                                          Positioned.fill(
                                                            child: Material(
                                                              color: Colors
                                                                  .transparent,
                                                              child: InkWell(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            20),
                                                                onTap:
                                                                    () async {
                                                                  String?
                                                                      selected =
                                                                      await showModalBottomSheet<
                                                                          String>(
                                                                    context:
                                                                        context,
                                                                    barrierColor:
                                                                        Colors
                                                                            .transparent,
                                                                    backgroundColor:
                                                                        Colors
                                                                            .transparent,
                                                                    isScrollControlled:
                                                                        true,
                                                                    builder:
                                                                        (context) {
                                                                      return Stack(
                                                                        children: [
                                                                          Positioned(
                                                                            top:
                                                                                0,
                                                                            left:
                                                                                0,
                                                                            right:
                                                                                0,
                                                                            height:
                                                                                30,
                                                                            child:
                                                                                Container(
                                                                              decoration: const BoxDecoration(
                                                                                boxShadow: [
                                                                                  BoxShadow(
                                                                                    color: Colors.black26,
                                                                                    blurRadius: 30,
                                                                                    spreadRadius: 5,
                                                                                    offset: Offset(0, 10),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          Container(
                                                                            margin:
                                                                                const EdgeInsets.only(top: 20),
                                                                            child:
                                                                                ClipRRect(
                                                                              borderRadius: const BorderRadius.only(
                                                                                topLeft: Radius.circular(20),
                                                                                topRight: Radius.circular(20),
                                                                              ),
                                                                              child: BackdropFilter(
                                                                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                                                                child: Container(
                                                                                  decoration: BoxDecoration(
                                                                                    color: const Color.fromARGB(10, 124, 124, 124),
                                                                                    border: Border.all(
                                                                                      color: const Color.fromARGB(80, 124, 124, 124),
                                                                                      width: 2,
                                                                                    ),
                                                                                    borderRadius: const BorderRadius.only(
                                                                                      topLeft: Radius.circular(20),
                                                                                      topRight: Radius.circular(20),
                                                                                    ),
                                                                                  ),
                                                                                  child: Column(
                                                                                    mainAxisSize: MainAxisSize.min,
                                                                                    children: [
                                                                                      Padding(
                                                                                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                                                                                        child: Text(
                                                                                          'Select Country',
                                                                                          style: TextStyle(
                                                                                            fontWeight: FontWeight.bold,
                                                                                            fontSize: 18,
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                      Divider(height: 1),
                                                                                      Flexible(
                                                                                        child: ListView.builder(
                                                                                          shrinkWrap: true,
                                                                                          itemCount: _countries.length,
                                                                                          itemBuilder: (context, index) {
                                                                                            final country = _countries[index];
                                                                                            return ListTile(
                                                                                              title: Text(country),
                                                                                              onTap: () {
                                                                                                Navigator.pop(context, country);
                                                                                              },
                                                                                              selected: country == _selectedCountry,
                                                                                              selectedTileColor: Colors.blue,
                                                                                              shape: RoundedRectangleBorder(
                                                                                                borderRadius: BorderRadius.circular(20),
                                                                                              ),
                                                                                            );
                                                                                          },
                                                                                        ),
                                                                                      ),
                                                                                      SizedBox(height: 12),
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      );
                                                                    },
                                                                  );
                                                                  if (selected !=
                                                                      null) {
                                                                    setState(
                                                                        () {
                                                                      _selectedCountry =
                                                                          selected;
                                                                    });
                                                                  }
                                                                },
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          Divider(),
                                        ],
                                      ),
                                    // Email field with icon
                                    Row(
                                      children: [
                                        Icon(Icons.mail_outline,
                                            color: Colors.grey[600]),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            decoration: InputDecoration(
                                              hintText: 'Username or email',
                                              border: InputBorder.none,
                                              filled: true,
                                              fillColor: Colors.transparent,
                                            ),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.deny(
                                                  RegExp(r'^\s+|\s+$')),
                                            ],
                                            onChanged: (value) {
                                              setState(() {
                                                _email = value;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    Divider(),
                                    // Password field with icon
                                    Row(
                                      children: [
                                        Icon(Icons.lock_outline,
                                            color: Colors.grey[600]),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            decoration: InputDecoration(
                                              hintText: 'Password',
                                              border: InputBorder.none,
                                              filled: true,
                                              fillColor: Colors.transparent,
                                            ),
                                            obscureText: true,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.deny(
                                                  RegExp(r'^\s+|\s+$')),
                                            ],
                                            onChanged: (value) {
                                              setState(() {
                                                _password = value;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Vspace(10),
                              // Show only one main button, and the toggle text + secondary button below the divider
                              if (_isRegistering) ...[
                                // Register mode: show Register button below, toggle text + Sign In button below divider
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.white10,
                                        Colors.green,
                                        Colors.white10,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: const Color.fromARGB(
                                          80, 124, 124, 124),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  margin: EdgeInsets.only(bottom: 10),
                                  child: ElevatedButton(
                                    onPressed: _register,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      padding:
                                          EdgeInsets.symmetric(vertical: 14),
                                      minimumSize: Size(double.infinity, 0),
                                    ),
                                    child: Text(
                                      "Register",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                // Sign In mode: show Sign In button below, toggle text + Register button below divider
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.white10,
                                        Colors.blue,
                                        Colors.white10,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: const Color.fromARGB(
                                          80, 124, 124, 124),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  margin: EdgeInsets.only(bottom: 10),
                                  child: ElevatedButton(
                                    onPressed: _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      padding:
                                          EdgeInsets.symmetric(vertical: 14),
                                      minimumSize: Size(double.infinity, 0),
                                    ),
                                    child: Text(
                                      "Sign In",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              Vspace(14),
                              // Divider with "Or"
                              Row(
                                children: [
                                  Expanded(
                                      child: Divider(
                                          color: Colors.grey[400],
                                          thickness: 1)),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      'Or',
                                      style: TextStyle(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Expanded(
                                      child: Divider(
                                          color: Colors.grey[400],
                                          thickness: 1)),
                                ],
                              ),
                              Vspace(10),
                              // Toggle text and secondary button below the divider
                              if (_isRegistering) ...[
                                // Not clickable, smaller, no underline
                                Text(
                                  "Already have an account? Sign In",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 13,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                Vspace(10),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.white10,
                                        Colors.blue,
                                        Colors.white10,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: const Color.fromARGB(
                                          80, 124, 124, 124),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _isRegistering = false;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      padding:
                                          EdgeInsets.symmetric(vertical: 14),
                                      minimumSize: Size(double.infinity, 0),
                                    ),
                                    child: Text(
                                      "Sign In",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  "Don't have an account? Register",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 13,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                Vspace(10),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.white10,
                                        Colors.green,
                                        Colors.white10,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: const Color.fromARGB(
                                          80, 124, 124, 124),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _isRegistering = true;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      padding:
                                          EdgeInsets.symmetric(vertical: 14),
                                      minimumSize: Size(double.infinity, 0),
                                    ),
                                    child: Text(
                                      "Register",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// Replace the _ShaderBackgroundPainter with ShaderPainter
class ShaderPainter extends CustomPainter {
  final FragmentProgram program;
  final double time;

  ShaderPainter({required this.program, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    shader.setFloat(0, size.width); // iResolution.x
    shader.setFloat(1, size.height); // iResolution.y
    shader.setFloat(2, time); // iTime

    // colorPrimary: deep blue
    shader.setFloat(3, 0.0); // R
    shader.setFloat(4, 0.2); // G
    shader.setFloat(5, 0.8); // B

    // colorAccent: lighter blue
    shader.setFloat(6, 0.4); // R
    shader.setFloat(7, 0.7); // G
    shader.setFloat(8, 1.0); // B

    // colorBlend: soft green (Color(0xFF71CD8C) ~ rgb(113, 205, 140))
    shader.setFloat(9, 113 / 255); // R
    shader.setFloat(10, 205 / 255); // G
    shader.setFloat(11, 140 / 255); // B

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant ShaderPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}
