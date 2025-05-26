import 'dart:ui'; // Add this import for BackdropFilter
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
        forceMaterialTransparency: true,
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

          return Stack(
            children: [
              // Main content with padding at the bottom for the button
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Wallet Balance: ⭐${walletBalance.toStringAsFixed(2)}',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: cartProvider.cartItems.isEmpty
                        ? Center(child: Text('Your cart is empty.'))
                        : ListView.builder(
                            padding: const EdgeInsets.only(
                                bottom: 80), // Add padding for button
                            itemCount: cartProvider.cartItems.length,
                            itemBuilder: (context, index) {
                              final item = cartProvider.cartItems[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 7,
                                        spreadRadius: 1,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20.0),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 10, sigmaY: 10),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.white60,
                                              Colors.white10
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20.0),
                                          border: Border.all(
                                            color: const Color.fromARGB(
                                                80, 124, 124, 124),
                                            width: 2,
                                          ),
                                        ),
                                        child: ListTile(
                                          leading: item['image'] != null
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Image.network(
                                                      item['image'],
                                                      width: 50,
                                                      height: 50,
                                                      fit: BoxFit.cover),
                                                )
                                              : Icon(Icons.shopping_bag),
                                          title: Text(item['name']),
                                          subtitle: Text(
                                              'Price: ${item['price'] is num ? item['price'].toString() : item['price']}'),
                                          trailing: IconButton(
                                            icon: Icon(Icons.remove_circle),
                                            onPressed: () {
                                              showDialog(
                                                barrierColor: Colors
                                                    .transparent, // Keep the background fully clear
                                                context: context,
                                                builder: (context) {
                                                  return Dialog(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    elevation: 0,
                                                    insetPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 24,
                                                            vertical: 24),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.3), // Shadow color
                                                            blurRadius: 30,
                                                            spreadRadius: 15,
                                                            offset:
                                                                Offset(0, 10),
                                                          ),
                                                        ],
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                        child: BackdropFilter(
                                                          filter:
                                                              ImageFilter.blur(
                                                                  sigmaX: 10,
                                                                  sigmaY: 10),
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              gradient:
                                                                  const LinearGradient(
                                                                begin: Alignment
                                                                    .topLeft,
                                                                end: Alignment
                                                                    .bottomCenter,
                                                                colors: [
                                                                  Colors
                                                                      .white60,
                                                                  Colors.white10
                                                                ],
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          20),
                                                              border:
                                                                  Border.all(
                                                                color: const Color
                                                                    .fromARGB(
                                                                    80,
                                                                    124,
                                                                    124,
                                                                    124),
                                                                width: 2,
                                                              ),
                                                            ),
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(24),
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const Text(
                                                                  'discard Item',
                                                                  style:
                                                                      TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        20,
                                                                  ),
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                ),
                                                                const SizedBox(
                                                                    height: 16),
                                                                const Text(
                                                                  'Are you sure you want to discard this item from the cart?',
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                ),
                                                                const SizedBox(
                                                                    height: 24),
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                    OutlinedButton(
                                                                      style: OutlinedButton
                                                                          .styleFrom(
                                                                        foregroundColor:
                                                                            Colors.black,
                                                                        backgroundColor:
                                                                            Colors.transparent,
                                                                        side: const BorderSide(
                                                                            color:
                                                                                Colors.black26),
                                                                        shape:
                                                                            RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(20),
                                                                        ),
                                                                      ),
                                                                      onPressed:
                                                                          () {
                                                                        Navigator.pop(
                                                                            context);
                                                                      },
                                                                      child: const Text(
                                                                          'Cancel'),
                                                                    ),
                                                                    OutlinedButton(
                                                                      style: OutlinedButton
                                                                          .styleFrom(
                                                                        foregroundColor:
                                                                            Colors.black,
                                                                        backgroundColor: const Color
                                                                            .fromARGB(
                                                                            136,
                                                                            255,
                                                                            111,
                                                                            111),
                                                                        side: const BorderSide(
                                                                            color:
                                                                                Colors.black26),
                                                                        shape:
                                                                            RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(20),
                                                                        ),
                                                                      ),
                                                                      onPressed:
                                                                          () {
                                                                        cartProvider
                                                                            .removeFromCart(item);
                                                                        Navigator.pop(
                                                                            context);
                                                                      },
                                                                      child: const Text(
                                                                          'Remove'),
                                                                    ),
                                                                  ],
                                                                ),
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
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
              // Redeem button overlay
              if (cartProvider.cartItems.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    left: false,
                    right: false,
                    minimum:
                        const EdgeInsets.only(left: 15, right: 15, bottom: 15),
                    child: Stack(
                      children: [
                        // Shadow around the button
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.22),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                            ),
                          ),
                        ),
                        // The Redeem and Discard All buttons in a Row
                        Row(
                          children: [
                            // Discard All button
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20.0),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFFFF6F6F),
                                          Colors.white10
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20.0),
                                      border: Border.all(
                                        color: const Color.fromARGB(
                                            80, 124, 124, 124),
                                        width: 2,
                                      ),
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 40, // was 50
                                      child: TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20.0),
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 16, // was 18
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            barrierColor: Colors.transparent,
                                            context: context,
                                            builder: (context) {
                                              return Dialog(
                                                backgroundColor:
                                                    Colors.transparent,
                                                elevation: 0,
                                                insetPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 24,
                                                        vertical: 24),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.3),
                                                        blurRadius: 30,
                                                        spreadRadius: 15,
                                                        offset: Offset(0, 10),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    child: BackdropFilter(
                                                      filter: ImageFilter.blur(
                                                          sigmaX: 10,
                                                          sigmaY: 10),
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          gradient:
                                                              const LinearGradient(
                                                            begin: Alignment
                                                                .topLeft,
                                                            end: Alignment
                                                                .bottomCenter,
                                                            colors: [
                                                              Colors.white60,
                                                              Colors.white10
                                                            ],
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                          border: Border.all(
                                                            color: const Color
                                                                .fromARGB(80,
                                                                124, 124, 124),
                                                            width: 2,
                                                          ),
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(24),
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            const Text(
                                                              'Discard All Items',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 20,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                            const SizedBox(
                                                                height: 16),
                                                            const Text(
                                                              'Are you sure you want to discard all items from the cart?',
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                            const SizedBox(
                                                                height: 24),
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                OutlinedButton(
                                                                  style: OutlinedButton
                                                                      .styleFrom(
                                                                    foregroundColor:
                                                                        Colors
                                                                            .black,
                                                                    backgroundColor:
                                                                        Colors
                                                                            .transparent,
                                                                    side: const BorderSide(
                                                                        color: Colors
                                                                            .black26),
                                                                    shape:
                                                                        RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              20),
                                                                    ),
                                                                  ),
                                                                  onPressed:
                                                                      () {
                                                                    Navigator.pop(
                                                                        context);
                                                                  },
                                                                  child: const Text(
                                                                      'Cancel'),
                                                                ),
                                                                OutlinedButton(
                                                                  style: OutlinedButton
                                                                      .styleFrom(
                                                                    foregroundColor:
                                                                        Colors
                                                                            .black,
                                                                    backgroundColor:
                                                                        const Color
                                                                            .fromARGB(
                                                                            136,
                                                                            255,
                                                                            111,
                                                                            111),
                                                                    side: const BorderSide(
                                                                        color: Colors
                                                                            .black26),
                                                                    shape:
                                                                        RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              20),
                                                                    ),
                                                                  ),
                                                                  onPressed:
                                                                      () {
                                                                    cartProvider
                                                                        .clearCart();
                                                                    Navigator.pop(
                                                                        context);
                                                                  },
                                                                  child: const Text(
                                                                      'Discard All'),
                                                                ),
                                                              ],
                                                            ),
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
                                        child: const Text('Discard All'),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Redeem button
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20.0),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF71CD8C),
                                          Colors.white10
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20.0),
                                      border: Border.all(
                                        color: const Color.fromARGB(
                                            80, 124, 124, 124),
                                        width: 2,
                                      ),
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 40, // was 50
                                      child: TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20.0),
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 16, // was 18
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        onPressed: () {
                                          double totalPrice =
                                              cartProvider.cartItems.fold(
                                                  0.0,
                                                  (sum, item) =>
                                                      sum +
                                                      (item['price'] is num
                                                          ? item['price']
                                                          : 0.0));
                                          if (walletBalance >= totalPrice) {
                                            showDialog(
                                              barrierColor: Colors.transparent,
                                              context: context,
                                              builder: (context) {
                                                return Dialog(
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  elevation: 0,
                                                  insetPadding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 24,
                                                      vertical: 24),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.3),
                                                          blurRadius: 30,
                                                          spreadRadius: 15,
                                                          offset: Offset(0, 10),
                                                        ),
                                                      ],
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      child: BackdropFilter(
                                                        filter:
                                                            ImageFilter.blur(
                                                                sigmaX: 10,
                                                                sigmaY: 10),
                                                        child: Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            gradient:
                                                                const LinearGradient(
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomCenter,
                                                              colors: [
                                                                Colors.white60,
                                                                Colors.white10
                                                              ],
                                                            ),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20),
                                                            border: Border.all(
                                                              color: const Color
                                                                  .fromARGB(
                                                                  80,
                                                                  124,
                                                                  124,
                                                                  124),
                                                              width: 2,
                                                            ),
                                                          ),
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(24),
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              const Text(
                                                                'Confirm Redemption',
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 20,
                                                                ),
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),
                                                              const SizedBox(
                                                                  height: 16),
                                                              Text(
                                                                'Are you sure you want to redeem these items for ⭐${totalPrice.toStringAsFixed(2)}?',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),
                                                              const SizedBox(
                                                                  height: 24),
                                                              Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .spaceBetween,
                                                                children: [
                                                                  OutlinedButton(
                                                                    style: OutlinedButton
                                                                        .styleFrom(
                                                                      foregroundColor:
                                                                          Colors
                                                                              .black,
                                                                      backgroundColor:
                                                                          Colors
                                                                              .transparent,
                                                                      side: const BorderSide(
                                                                          color:
                                                                              Colors.black26),
                                                                      shape:
                                                                          RoundedRectangleBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(20),
                                                                      ),
                                                                    ),
                                                                    onPressed:
                                                                        () {
                                                                      Navigator.pop(
                                                                          context);
                                                                    },
                                                                    child: const Text(
                                                                        'Cancel'),
                                                                  ),
                                                                  OutlinedButton(
                                                                    style: OutlinedButton
                                                                        .styleFrom(
                                                                      foregroundColor:
                                                                          Colors
                                                                              .black,
                                                                      backgroundColor: const Color
                                                                          .fromARGB(
                                                                          136,
                                                                          113,
                                                                          205,
                                                                          140),
                                                                      side: const BorderSide(
                                                                          color:
                                                                              Colors.black26),
                                                                      shape:
                                                                          RoundedRectangleBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(20),
                                                                      ),
                                                                    ),
                                                                    onPressed:
                                                                        () async {
                                                                      final newBalance =
                                                                          walletBalance -
                                                                              totalPrice;
                                                                      await FirebaseFirestore
                                                                          .instance
                                                                          .collection(
                                                                              'users')
                                                                          .doc(FirebaseAuth
                                                                              .instance
                                                                              .currentUser!
                                                                              .uid)
                                                                          .update({
                                                                        'wallet_balance':
                                                                            newBalance
                                                                      });
                                                                      cartProvider
                                                                          .clearCart();
                                                                      Navigator.pop(
                                                                          context);
                                                                      ScaffoldMessenger.of(
                                                                              context)
                                                                          .showSnackBar(
                                                                              SnackBar(
                                                                        content:
                                                                            Text('Purchase successful! New wallet balance: \$${newBalance.toStringAsFixed(2)}'),
                                                                      ));
                                                                    },
                                                                    child: const Text(
                                                                        'Redeem'),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: Text(
                                                  'Insufficient wallet balance!'),
                                            ));
                                          }
                                        },
                                        child: const Text('Redeem'),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
