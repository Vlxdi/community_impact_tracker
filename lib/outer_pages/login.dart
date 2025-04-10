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

class _LoginPageState extends State<LoginPage> {
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

  @override
  void initState() {
    super.initState();
    _getUserLocation();
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
      body: Center(
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            color: Color(0xFFF1F7FE),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 5),
              ),
            ],
          ),
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _isRegistering ? 'Sign up' : 'Login',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              Vspace(8),
              Text(
                _isRegistering
                    ? 'Create a free account with your email.'
                    : 'Log in to your account.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              Vspace(16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Registration fields
                    if (_isRegistering)
                      Column(
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Username',
                              border: InputBorder.none,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(RegExp(
                                  r'^\s+|\s+$')), // Disallow leading/trailing spaces
                            ],
                            onChanged: (value) {
                              setState(() {
                                _username =
                                    value; // Allow copying but sanitize input
                              });
                            },
                          ),
                          Divider(),
                          // Country dropdown
                          _isLoadingLocation
                              ? Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Center(
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                )
                              : DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    hint: Text('Select Country'),
                                    value: _selectedCountry.isEmpty
                                        ? null
                                        : _selectedCountry,
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedCountry = newValue!;
                                      });
                                    },
                                    items: _countries
                                        .map<DropdownMenuItem<String>>(
                                            (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  ),
                                ),
                          Divider(),
                        ],
                      ),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Email',
                        border: InputBorder.none,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(
                            r'^\s+|\s+$')), // Disallow leading/trailing spaces
                      ],
                      onChanged: (value) {
                        setState(() {
                          _email = value; // Allow copying but sanitize input
                        });
                      },
                    ),
                    Divider(),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Password',
                        border: InputBorder.none,
                      ),
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(
                            r'^\s+|\s+$')), // Disallow leading/trailing spaces
                      ],
                      onChanged: (value) {
                        setState(() {
                          _password = value; // Allow copying but sanitize input
                        });
                      },
                    ),
                  ],
                ),
              ),
              Vspace(20),
              ElevatedButton(
                onPressed: _isRegistering ? _register : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0066FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
                child: Text(
                  _isRegistering ? 'Sign up' : 'Login',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              Vspace(12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isRegistering = !_isRegistering;
                  });
                },
                child: Text(
                  _isRegistering
                      ? 'Already have an account? Log in'
                      : 'Don\'t have an account? Sign up',
                  style: TextStyle(
                    color: Color(0xFF0066FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
