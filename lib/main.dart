import 'package:community_impact_tracker/main_pages/events_page.dart';
import 'package:community_impact_tracker/main_pages/leaderboard/leaderboard_page.dart';
import 'package:community_impact_tracker/main_pages/shop/cart_provider.dart';
import 'package:community_impact_tracker/main_pages/shop/shop_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'outer_pages/login.dart';
import 'main_pages/profile/profile.dart';
import 'firebase_options.dart';
import 'outer_pages/admin_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/', // Default route when app starts
      routes: {
        '/': (context) => AuthenticationWrapper(), // Authentication check route
        '/login': (context) => LoginPage(), // Login route
        '/admin_panel': (context) => AdminPanel(), // Admin Panel route
        '/main': (context) => MainPage(), // Main page route
      },
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  Future<bool> _isAdminUser(String uid) async {
    // Check if the user exists in the 'admins' collection
    final adminDoc =
        await FirebaseFirestore.instance.collection('admins').doc(uid).get();
    return adminDoc.exists;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          final currentUser = snapshot.data!;
          return FutureBuilder<bool>(
            future: _isAdminUser(currentUser.uid),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (adminSnapshot.hasData && adminSnapshot.data == true) {
                // Redirect to Admin Panel if the user is an admin
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => AdminPanel()),
                  );
                });
                return SizedBox.shrink();
              }

              // Redirect to normal user MainPage
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MainPage(
                      initialIndex: currentUser.metadata.creationTime ==
                              currentUser.metadata.lastSignInTime
                          ? 3
                          : 0,
                    ),
                  ),
                );
              });
              return SizedBox.shrink();
            },
          );
        }

        // Show login page if no user is logged in
        return LoginPage();
      },
    );
  }
}

class MainPage extends StatefulWidget {
  final int initialIndex;

  const MainPage({super.key, this.initialIndex = 0});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late int _selectedIndex;

  final List<Widget> _pages = <Widget>[
    EventsPage(),
    ShopPage(),
    LeaderboardPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.event_rounded),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Leaderboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_2),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
