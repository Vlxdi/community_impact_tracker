import 'package:community_impact_tracker/main_pages/events/events_page.dart';
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
import 'package:community_impact_tracker/theme/theme_provider.dart';
import 'dart:ui';

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
        ChangeNotifierProvider(
            create: (_) => ThemeProvider()), // Add ThemeProvider
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

class TransparentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;

  const TransparentAppBar({
    required this.title,
    this.actions,
    this.leading,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if the theme is dark
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AppBar(
          centerTitle: true,
          backgroundColor: isDarkTheme
              ? Colors.transparent
              : Colors.white.withOpacity(
                  0.2), // transparent for dark theme, semi-transparent for light
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          elevation: 0,
          title: title,
          actions: actions,
          leading: leading,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
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
      extendBody:
          true, // Makes content draw under the navbar for floating effect
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white
                    .withOpacity(0.2), // Semi-transparent for blur effect
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.light
                      ? const Color.fromARGB(80, 124, 124, 124)
                      : Colors.white
                          .withOpacity(0.3), // Dark grey for light theme
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
                unselectedItemColor: Colors.grey,
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
