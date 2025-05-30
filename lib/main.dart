import 'package:community_impact_tracker/main_pages/events/events_page.dart';
import 'package:community_impact_tracker/main_pages/leaderboard/leaderboard_page.dart';
import 'package:community_impact_tracker/main_pages/shop/cart_provider.dart';
import 'package:community_impact_tracker/main_pages/shop/shop_page.dart';
import 'package:community_impact_tracker/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'outer_pages/login.dart';
import 'main_pages/profile/profile.dart';
import 'firebase_options.dart';
import 'outer_pages/admin_panel.dart';
import 'package:community_impact_tracker/theme/theme_provider.dart';
import 'dart:ui';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable immersive sticky mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData, // Apply dynamic theme
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

// Utility function to check if the theme is dark
bool isDarkTheme(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
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

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  late int _selectedIndex;
  AnimationController? _gradientController;

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
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _gradientController?.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isGradient = themeProvider.appThemeMode == AppThemeMode.gradient;

    return Scaffold(
      body: Stack(
        children: [
          // Only show animated gradient if gradient theme is selected
          if (isGradient && _gradientController != null)
            Positioned.fill(
              child: GradientThemeData.shaderBackground(_gradientController!),
            ),
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          Positioned(
            bottom: -10,
            left: 0,
            right: 0,
            child: Container(
              height: 15,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(130, 0, 0, 0),
                    blurRadius: 40,
                    spreadRadius: 10,
                    offset: Offset(0, 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      extendBody:
          true, // Makes content draw under the navbar for floating effect
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white60, Colors.white10],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDarkTheme(context)
                      ? Colors.white.withOpacity(0.3)
                      : const Color.fromARGB(80, 124, 124, 124),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 3,
                    blurRadius: 10,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: BottomNavigationBar(
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
                unselectedItemColor:
                    isDarkTheme(context) ? Colors.white : Colors.black,
                backgroundColor: Colors.transparent,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                onTap: _onItemTapped,
                showSelectedLabels: true, // Show label for selected item
                showUnselectedLabels: false, // Hide labels for unselected items
              ),
            ),
          ),
        ),
      ),
    );
  }
}
