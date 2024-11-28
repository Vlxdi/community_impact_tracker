import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';

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
  //add phone registering later
  //final String _phone = '';
  //final String _verificationId = '';
  bool _isRegistering = false;

  void _register() async {
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
        });

        // Directly sign the user in
        await _auth.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );

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

      // Retrieve username
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

  // Uncomment and adjust this function if using phone authentication in the future
  // void _loginWithPhone() async {
  //   try {
  //     await _auth.verifyPhoneNumber(
  //       phoneNumber: _phone,
  //       verificationCompleted: (PhoneAuthCredential credential) async {
  //         await _auth.signInWithCredential(credential);
  //         if (mounted) {
  //           Navigator.pushReplacement(
  //             context,
  //             MaterialPageRoute(builder: (context) => MainPage(initialIndex: 3)),
  //           );
  //         }
  //       },
  //       verificationFailed: (FirebaseAuthException e) {
  //         print(e);
  //         if (mounted) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //               SnackBar(content: Text('Phone verification failed')));
  //         }
  //       },
  //       codeSent: (String verificationId, int? resendToken) {
  //         setState(() {
  //           _verificationId = verificationId;
  //         });
  //         ScaffoldMessenger.of(context)
  //             .showSnackBar(SnackBar(content: Text('Code sent')));
  //       },
  //       codeAutoRetrievalTimeout: (String verificationId) {},
  //     );
  //   } catch (e) {
  //     print(e);
  //     ScaffoldMessenger.of(context)
  //         .showSnackBar(SnackBar(content: Text('Phone login failed')));
  //   }
  // }

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
              SizedBox(height: 8),
              Text(
                _isRegistering
                    ? 'Create a free account with your email.'
                    : 'Log in to your account.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // New username field
                    if (_isRegistering)
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Username',
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _username = value;
                          });
                        },
                      ),
                    Divider(),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Email',
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _email = value;
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
                      onChanged: (value) {
                        setState(() {
                          _password = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
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
              SizedBox(height: 12),
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
