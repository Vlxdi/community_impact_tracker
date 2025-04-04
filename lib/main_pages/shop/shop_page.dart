import 'package:community_impact_tracker/main_pages/shop/cart_page.dart';
import 'package:community_impact_tracker/main_pages/shop/cart_provider.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

class ShopPage extends StatelessWidget {
  String _formatPrice(dynamic price) {
    if (price is num) {
      return price % 1 == 0 ? price.toInt().toString() : price.toString();
    }
    return 'No Price';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shop'),
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CartPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No products available.'));
          }
          final products = snapshot.data!.docs;
          return GridView.builder(
            padding: EdgeInsets.all(16.0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                elevation: 4.0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    product['image'] != null
                        ? Image.network(product['image'], height: 80)
                        : Icon(Icons.shopping_bag,
                            size: 50, color: Colors.blue),
                    SizedBox(height: 8.0),
                    Text(product['name'] ?? 'No Name',
                        style: TextStyle(fontSize: 16)),
                    SizedBox(height: 8.0),
                    ElevatedButton(
                      onPressed: () {
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
                                        : Icon(Icons.shopping_bag,
                                            size: 100, color: Colors.blue),
                                  ),
                                  SizedBox(height: 16.0),
                                  Text(
                                    product['name'] ?? 'No Name',
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 8.0),
                                  Text(
                                    product['description'] ?? 'No Description',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  SizedBox(height: 16.0),
                                  Text(
                                    'Price: ${_formatPrice(product['price'])}*',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 16.0),
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
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Product added to cart!'),
                                        ),
                                      );
                                    },
                                    child: Text('Add to Cart'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: Text('View Details'),
                    ),
                  ],
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
