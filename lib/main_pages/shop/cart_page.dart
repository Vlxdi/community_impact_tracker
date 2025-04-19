import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:community_impact_tracker/main_pages/shop/cart_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CartPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    Future<double> fetchWalletBalance() async {
      final userId = FirebaseAuth
          .instance.currentUser?.uid; // Get the currently logged-in user's ID
      if (userId == null) {
        throw Exception('No user is currently logged in.');
      }
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final balance = userDoc.data()?['wallet_balance'];
        if (balance is int) {
          return balance.toDouble(); // Convert int to double
        } else if (balance is double) {
          return balance;
        }
      }
      return 0.0; // Default to 0.0 if the value is null or invalid
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Cart'),
        centerTitle: true,
      ),
      body: FutureBuilder<double>(
        future: fetchWalletBalance(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error fetching wallet balance'));
          }
          final walletBalance = snapshot.data ?? 0.0;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Wallet Balance: ⭐${walletBalance.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: cartProvider.cartItems.isEmpty
                    ? Center(child: Text('Your cart is empty.'))
                    : ListView.builder(
                        itemCount: cartProvider.cartItems.length,
                        itemBuilder: (context, index) {
                          final item = cartProvider.cartItems[index];
                          return ListTile(
                            leading: item['image'] != null
                                ? Image.network(item['image'], width: 50)
                                : Icon(Icons.shopping_bag),
                            title: Text(item['name']),
                            subtitle: Text(
                                'Price: ${item['price'] is num ? item['price'].toString() : item['price']}'),
                            trailing: IconButton(
                              icon: Icon(Icons.remove_circle),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Remove Item'),
                                    content: Text(
                                        'Are you sure you want to remove this item from the cart?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(
                                              context); // Close the dialog
                                        },
                                        child: Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          cartProvider.removeFromCart(item);
                                          Navigator.pop(
                                              context); // Close the dialog
                                        },
                                        child: Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
              if (cartProvider.cartItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      double totalPrice = cartProvider.cartItems.fold(
                          0.0,
                          (sum, item) =>
                              sum +
                              (item['price'] is num ? item['price'] : 0.0));
                      if (walletBalance >= totalPrice) {
                        final newBalance = walletBalance - totalPrice;
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .update({'wallet_balance': newBalance});
                        cartProvider.clearCart();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Purchase successful! New wallet balance: \$${newBalance.toStringAsFixed(2)}'),
                        ));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Insufficient wallet balance!'),
                        ));
                      }
                    },
                    child: Text('Purchase'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
