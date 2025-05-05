import 'package:community_impact_tracker/main.dart';
import 'package:community_impact_tracker/main_pages/shop/cart_page.dart';
import 'package:community_impact_tracker/main_pages/shop/cart_provider.dart';
import 'package:community_impact_tracker/main_pages/shop/favorite_products.dart';
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
  late AnimationController
      _cartAnimationController; // Add cart animation controller

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _favoritesAnimationController = AnimationController(vsync: this);
    _cartAnimationController = AnimationController(
        vsync: this); // Initialize cart animation controller
  }

  @override
  void dispose() {
    _favoritesAnimationController.dispose();
    _cartAnimationController.dispose(); // Dispose cart animation controller
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
      extendBodyBehindAppBar: true, // This is correct - keeps it
      appBar: TransparentAppBar(
        title: const Center(child: Text('Shop')),
        leading: IconButton(
            icon: SizedBox(
              width: 30,
              height: 30,
              child: Lottie.asset(
                'assets/animations/appbar_icons/favorites.json',
                controller: _favoritesAnimationController,
                onLoaded: (composition) {
                  _favoritesAnimationController.duration = composition.duration;
                },
              ),
            ),
            onPressed: () async {
              if (_isNavigating) return;
              _isNavigating = true;

              _favoritesAnimationController.forward(from: 0);
              await Future.delayed(const Duration(milliseconds: 500));
              if (!mounted) return;
              await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      FavoriteProductsPage(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    const begin = Offset(-1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;

                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);

                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                ),
              );
              _isNavigating = false;
            }),
        actions: [
          IconButton(
              icon: SizedBox(
                width: 30,
                height: 30,
                child: Lottie.asset(
                  'assets/animations/appbar_icons/cart.json',
                  controller: _cartAnimationController,
                  onLoaded: (composition) {
                    _cartAnimationController.duration = composition.duration;
                  },
                ),
              ),
              onPressed: () async {
                if (_isNavigating) return;
                _isNavigating = true;

                _cartAnimationController.forward(from: 0);
                await Future.delayed(const Duration(milliseconds: 500));
                if (!mounted) return;
                await Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        CartPage(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;

                      var tween = Tween(begin: begin, end: end)
                          .chain(CurveTween(curve: curve));
                      var offsetAnimation = animation.drive(tween);

                      return SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      );
                    },
                  ),
                );
                _isNavigating = false;
              }),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
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

          final products = snapshot.data!.docs;

          return GridView.builder(
            // Add padding at the top to create space between app bar and content
            padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 8, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12.0),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: product['image'] != null
                                    ? Image.network(product['image'],
                                        height: 150)
                                    : const Icon(Icons.shopping_bag,
                                        size: 100, color: Colors.blue),
                              ),
                              const SizedBox(height: 16.0),
                              Text(
                                product['name'] ?? 'No Name',
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8.0),
                              Text(
                                product['description'] ?? 'No Description',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 16.0),
                              Text(
                                'Price: ${_formatPrice(product['price'])}*',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16.0),
                              ElevatedButton(
                                onPressed: () {
                                  final cartProvider =
                                      Provider.of<CartProvider>(context,
                                          listen: false);
                                  cartProvider.addToCart(
                                    product['name'] ?? 'No Name',
                                    product['price'] ?? 0,
                                    product['image'],
                                  );
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Product added to cart!')),
                                  );
                                },
                                child: const Text('Add to Cart'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: product['image'] != null
                              ? Image.network(product['image'],
                                  fit: BoxFit.cover)
                              : const Icon(Icons.shopping_bag,
                                  size: 50, color: Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        product['name'] ?? 'No Name',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        '\$${_formatPrice(product['price'])}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8.0),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ProductDetailsPage extends StatelessWidget {
  final String productName;
  final String productDescription;
  final String productPrice;
  final String? productImage;

  ProductDetailsPage({
    required this.productName,
    required this.productDescription,
    required this.productPrice,
    this.productImage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(productName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: productImage != null
                  ? Image.network(productImage!, height: 150)
                  : Icon(Icons.shopping_bag, size: 100, color: Colors.blue),
            ),
            SizedBox(height: 16.0),
            Text(
              productName,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.0),
            Text(
              productDescription,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16.0),
            Text(
              'Price: $productPrice',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () {
                // Add purchase logic here
              },
              child: Text('Purchase'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: ShopPage(),
  ));
}
