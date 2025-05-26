import 'dart:ui';
import 'package:community_impact_tracker/main.dart';
import 'package:community_impact_tracker/main_pages/shop/cart_page.dart';
import 'package:community_impact_tracker/main_pages/shop/cart_provider.dart';
import 'package:community_impact_tracker/main_pages/shop/favorite_products.dart';
import 'package:community_impact_tracker/utils/addSpace.dart';
import 'package:community_impact_tracker/widgets/build_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';

class ShopPage extends StatefulWidget {
  @override
  _ShopPageState createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> with TickerProviderStateMixin {
  late AnimationController _favoritesAnimationController;
  late AnimationController _cartAnimationController;
  AnimationController? _searchAnimationController; // Make nullable

  bool _isNavigating = false;
  String searchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _favoritesAnimationController = AnimationController(vsync: this);
    _cartAnimationController = AnimationController(vsync: this);
    // Don't initialize _searchAnimationController here, do it in onLoaded
    _searchFocusNode.addListener(_onSearchFocusChange);
  }

  void _onSearchFocusChange() {
    // Play animation only if the search bar is focused and the cursor is blinking (i.e., keyboard is up)
    if (_searchFocusNode.hasFocus) {
      // Start animation a little bit later (e.g., from 0.2s into the animation)
      Future.microtask(() {
        if (_searchAnimationController != null &&
            !_searchAnimationController!.isAnimating) {
          final controller = _searchAnimationController!;
          final double start = controller.duration != null
              ? (controller.duration!.inMilliseconds * 0.25) /
                  controller.duration!.inMilliseconds
              : 0.25;
          controller.forward(from: start);
          controller.repeat(min: start);
        }
      });
    } else {
      if (_searchAnimationController != null) {
        _searchAnimationController!.stop();
        _searchAnimationController!.reset();
      }
    }
  }

  @override
  void dispose() {
    _favoritesAnimationController.dispose();
    _cartAnimationController.dispose();
    _searchAnimationController?.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String _formatPrice(dynamic price) {
    if (price is num) {
      return price % 1 == 0 ? price.toInt().toString() : price.toString();
    }
    return 'No Price';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Vspace(8),
          PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Favorites animation button (left)
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white60, Colors.white10],
                    ),
                    borderRadius: BorderRadius.circular(10),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: GestureDetector(
                      onTap: () async {
                        if (_isNavigating) return;
                        _isNavigating = true;

                        _favoritesAnimationController.forward(from: 0);
                        await Future.delayed(Duration(milliseconds: 500));

                        if (!mounted) return;
                        await Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    FavoriteProductsPage(),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              const begin = Offset(-1.0, 0.0);
                              const end = Offset.zero;
                              const curve = Curves.easeInOut;

                              var tween = Tween(begin: begin, end: end)
                                  .chain(CurveTween(curve: curve));
                              var offsetAnimation = animation.drive(tween);

                              return SlideTransition(
                                  position: offsetAnimation, child: child);
                            },
                          ),
                        );

                        _isNavigating = false;
                      },
                      child: Transform.scale(
                        scale: 0.75, // Adjust this value to your preference
                        child: Lottie.asset(
                          'assets/animations/appbar_icons/favorites.json',
                          controller: _favoritesAnimationController,
                          onLoaded: (composition) {
                            _favoritesAnimationController.duration =
                                composition.duration;
                          },
                          repeat: false,
                        ),
                      ),
                    ),
                  ),
                ),

                // Search bar (center)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white60, Colors.white10],
                          ),
                          border: Border.all(
                            color: const Color.fromARGB(80, 124, 124, 124),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          focusNode: _searchFocusNode,
                          autofocus: false,
                          onTap: () {
                            // Start animation a little bit later (e.g., from 0.2s into the animation)
                            Future.microtask(() {
                              if (_searchFocusNode.hasFocus &&
                                  _searchAnimationController != null &&
                                  !_searchAnimationController!.isAnimating) {
                                final controller = _searchAnimationController!;
                                final double start = controller.duration != null
                                    ? (controller.duration!.inMilliseconds *
                                            0.2) /
                                        controller.duration!.inMilliseconds
                                    : 0.2;
                                controller.forward(from: start);
                                controller.repeat(min: start);
                              }
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search for products...',
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(bottom: 5.0),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Lottie.asset(
                                  'assets/animations/search.json',
                                  controller: _searchAnimationController,
                                  onLoaded: (composition) {
                                    if (_searchAnimationController == null) {
                                      final controller = AnimationController(
                                        vsync: this,
                                        duration: composition.duration,
                                      );
                                      setState(() {
                                        _searchAnimationController = controller;
                                      });
                                      // If focused when loaded, start animation
                                      if (_searchFocusNode.hasFocus) {
                                        controller.repeat();
                                      }
                                    } else {
                                      _searchAnimationController!.duration =
                                          composition.duration;
                                      // If focused and not animating, start animation
                                      if (_searchFocusNode.hasFocus &&
                                          !_searchAnimationController!
                                              .isAnimating) {
                                        _searchAnimationController!.repeat();
                                      }
                                    }
                                  },
                                  repeat: false,
                                ),
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.2),
                            contentPadding: EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: TextStyle(fontSize: 14),
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value.toLowerCase();
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Cart animation button (right)
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white60, Colors.white10],
                    ),
                    borderRadius: BorderRadius.circular(10),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: GestureDetector(
                      onTap: () async {
                        if (_isNavigating) return;
                        _isNavigating = true;

                        _cartAnimationController.forward(from: 0);
                        await Future.delayed(Duration(milliseconds: 500));

                        if (!mounted) return;
                        await Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    CartPage(),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              const begin = Offset(1.0, 0.0);
                              const end = Offset.zero;
                              const curve = Curves.easeInOut;

                              var tween = Tween(begin: begin, end: end)
                                  .chain(CurveTween(curve: curve));
                              var offsetAnimation = animation.drive(tween);

                              return SlideTransition(
                                  position: offsetAnimation, child: child);
                            },
                          ),
                        );

                        _isNavigating = false;
                      },
                      child: Transform.scale(
                        scale: 0.75, // Adjust this value to your preference
                        child: Lottie.asset(
                          'assets/animations/appbar_icons/cart.json',
                          controller: _cartAnimationController,
                          onLoaded: (composition) {
                            _cartAnimationController.duration =
                                composition.duration;
                          },
                          repeat: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            thickness: 1,
            color: Colors.grey.withOpacity(0.3),
          ),
          Container(
            height: 4,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  spreadRadius: 10,
                  offset: Offset(0, 0),
                ),
              ],
            ),
          ),
          // Scrollable item grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No products available.'));
                }

                final products = snapshot.data!.docs.where((product) {
                  final name = product['name']?.toString().toLowerCase() ?? '';
                  return name.contains(searchQuery);
                }).toList();

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16,
                      30 + kBottomNavigationBarHeight), // Removed top padding
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 7, // even smaller blur
                            spreadRadius: 1, // even smaller spread
                            offset: Offset(0, 1), // smaller offset
                          ),
                        ],
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(20.0), // changed to 20
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomCenter,
                                colors: [Colors.white60, Colors.white10],
                              ),
                              borderRadius:
                                  BorderRadius.circular(20.0), // changed to 20
                              border: Border.all(
                                color: const Color.fromARGB(80, 124, 124, 124),
                                width: 2,
                              ),
                              // boxShadow removed from here
                            ),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(20.0), // changed to 20
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  barrierColor: Colors.transparent,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (context) {
                                    return Stack(
                                      children: [
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          right: 0,
                                          height: 30,
                                          child: Container(
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
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(20),
                                              topRight: Radius.circular(20),
                                            ),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                  sigmaX: 10, sigmaY: 10),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: const Color.fromARGB(
                                                      10, 124, 124, 124),
                                                  border: Border.all(
                                                    color: const Color.fromARGB(
                                                        80, 124, 124, 124),
                                                    width: 2,
                                                  ),
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(20),
                                                    topRight:
                                                        Radius.circular(20),
                                                  ),
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      16.0),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Center(
                                                        child: product[
                                                                    'image'] !=
                                                                null
                                                            ? Image.network(
                                                                product[
                                                                    'image'],
                                                                height: 150)
                                                            : const Icon(
                                                                Icons
                                                                    .shopping_bag,
                                                                size: 100,
                                                                color: Colors
                                                                    .blue),
                                                      ),
                                                      const SizedBox(
                                                          height: 16.0),
                                                      Text(
                                                        product['name'] ??
                                                            'No Name',
                                                        style: const TextStyle(
                                                            fontSize: 24,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      ),
                                                      const SizedBox(
                                                          height: 8.0),
                                                      Text(
                                                        product['description'] ??
                                                            'No Description',
                                                        style: const TextStyle(
                                                            fontSize: 16),
                                                      ),
                                                      const SizedBox(
                                                          height: 16.0),
                                                      Text(
                                                        'Price: ⭐${_formatPrice(product['price'])}',
                                                        style: const TextStyle(
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      ),
                                                      const SizedBox(
                                                          height: 16.0),
                                                      buildListTile(
                                                        color:
                                                            Color(0xFF71CD8C),
                                                        icon:
                                                            Icons.shopping_cart,
                                                        title: 'Add to Cart',
                                                        isSelected: false,
                                                        onTap: () {
                                                          final cartProvider =
                                                              Provider.of<
                                                                      CartProvider>(
                                                                  context,
                                                                  listen:
                                                                      false);
                                                          cartProvider
                                                              .addToCart(
                                                            product['name'] ??
                                                                'No Name',
                                                            product['price'] ??
                                                                0,
                                                            product['image'],
                                                          );
                                                          Navigator.pop(
                                                              context);
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            const SnackBar(
                                                                content: Text(
                                                                    'Product added to cart!')),
                                                          );
                                                        },
                                                        isTop: true,
                                                      ),
                                                      buildListTile(
                                                        icon: Icons.close,
                                                        title: 'Close',
                                                        isSelected: false,
                                                        onTap: () {
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                      ),
                                                    ],
                                                  ),
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
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          20.0), // changed to 20
                                      child: product['image'] != null
                                          ? Image.network(product['image'],
                                              fit: BoxFit.cover)
                                          : const Icon(Icons.shopping_bag,
                                              size: 50, color: Colors.blue),
                                    ),
                                  ),
                                  Vspace(8),
                                  Text(
                                    product['name'] ?? 'No Name',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  Vspace(4),
                                  Text(
                                    '⭐${_formatPrice(product['price'])}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Vspace(8),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
