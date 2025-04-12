import 'package:community_impact_tracker/outer_pages/admin_utils/authUtils.dart';
import 'package:community_impact_tracker/utils/addSpace.dart';
import 'package:community_impact_tracker/utils/noLeadingZero.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart'; // Added for inputFormatters
import 'admin_panel.dart';

class AdminShopPage extends StatefulWidget {
  @override
  _AdminShopPageState createState() => _AdminShopPageState();
}

class _AdminShopPageState extends State<AdminShopPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String? _imageUrl;
  bool _isEventPanel = false; // Track the current panel

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final Set<String> _selectedProductIds = {}; // Store selected product IDs
  bool _isBatchDeleteMode = false; // Track if batch delete mode is active

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Process the product data
      final product = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'image': _imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

      try {
        await _firestore.collection('products').add(product);
        print('Product added to Firestore: $product');
        // Clear the form
        _nameController.clear();
        _descriptionController.clear();
        _priceController.clear();
        setState(() {
          _imageUrl = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product added successfully!')),
        );
      } catch (e) {
        print('Error adding product: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add product. Please try again.')),
        );
      }
    }
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        final file = pickedFile.readAsBytes();
        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = _storage.ref().child('products_images/$fileName');

        // Upload the file to Firebase Storage
        final uploadTask = await ref.putData(await file);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        setState(() {
          _imageUrl = downloadUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image uploaded successfully!')),
        );
      } catch (e) {
        print('Error uploading image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image. Please try again.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No image selected.')),
      );
    }
  }

  void _togglePanel() {
    setState(() {
      _isEventPanel = !_isEventPanel;
    });
    if (_isEventPanel) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AdminPanel()),
      );
    }
  }

  void _editProduct(String productId, Map<String, dynamic> productData) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController nameController =
            TextEditingController(text: productData['name']);
        final TextEditingController descriptionController =
            TextEditingController(text: productData['description']);
        final TextEditingController priceController =
            TextEditingController(text: productData['price'].toString());

        return AlertDialog(
          title: Text('Edit Product'),
          content: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Product Name'),
                ),
                TextFormField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: 'Product Description'),
                ),
                TextFormField(
                  controller: priceController,
                  decoration: InputDecoration(labelText: 'Product Price'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(
                        r'^\d*\.?\d*')), // Allow numbers with optional decimal
                    NoLeadingZeroFormatter(), // Prevents leading zero
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _firestore
                      .collection('products')
                      .doc(productId)
                      .update({
                    'name': nameController.text,
                    'description': descriptionController.text,
                    'price': double.tryParse(priceController.text) ?? 0.0,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Product updated successfully!')),
                  );
                } catch (e) {
                  print('Error updating product: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update product.')),
                  );
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteProduct(String productId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete this product?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close the dialog
                _deleteProduct(productId);
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product deleted successfully!')),
      );
    } catch (e) {
      print('Error deleting product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete product.')),
      );
    }
  }

  void _toggleProductSelection(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  void _toggleBatchDeleteMode() {
    setState(() {
      _isBatchDeleteMode = !_isBatchDeleteMode;
      if (!_isBatchDeleteMode) {
        _selectedProductIds
            .clear(); // Clear selections when exiting batch delete mode
      }
    });
  }

  Future<void> _batchDeleteProducts() async {
    if (_selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No products selected for deletion!")),
      );
      return;
    }

    bool confirmDelete = await _showDeleteConfirmationDialog();
    if (confirmDelete) {
      try {
        for (String productId in _selectedProductIds) {
          await _firestore.collection('products').doc(productId).delete();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Selected products deleted successfully!")),
        );

        setState(() {
          _selectedProductIds.clear();
          _isBatchDeleteMode = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirm Delete'),
            content:
                Text('Are you sure you want to delete the selected products?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel - Shop'),
        actions: [
          IconButton(
            icon:
                Icon(_isEventPanel ? Icons.shopping_cart_rounded : Icons.event),
            onPressed: _togglePanel,
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => AuthUtils.logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: 'Product Name'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a product name';
                        }
                        return null;
                      },
                    ),
                    Vspace(16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration:
                          InputDecoration(labelText: 'Product Description'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a product description';
                        }
                        return null;
                      },
                    ),
                    Vspace(16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration:
                                InputDecoration(labelText: 'Product Price'),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*')),
                              NoLeadingZeroFormatter(),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a product price';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                        Hspace(16),
                        TextButton.icon(
                          onPressed: _pickImage,
                          icon: Icon(Icons.image),
                          label: Text(_imageUrl == null
                              ? 'Pick Image'
                              : 'Change Image'),
                        ),
                      ],
                    ),
                    Vspace(16),
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _imageUrl!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Text(
                                'No Image Selected',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                    ),
                    Vspace(16),
                    if (_imageUrl != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _imageUrl = null;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Image removed.')),
                              );
                            },
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                Hspace(4),
                                Text('Remove Image'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    Vspace(16),
                    ElevatedButton(
                      onPressed: _submitForm,
                      child: Text('Add Product'),
                    ),
                  ],
                ),
              ),
              Vspace(16),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Existing Products',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  IconButton(
                    icon: Icon(
                      _isBatchDeleteMode
                          ? Icons.close
                          : Icons.select_all_rounded,
                      color: Colors.blue,
                    ),
                    onPressed: _toggleBatchDeleteMode,
                  ),
                ],
              ),
              Vspace(5),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('products').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final products = snapshot.data!.docs;
                  return Stack(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          var productData =
                              products[index].data() as Map<String, dynamic>;
                          var productId = products[index].id;
                          return ListTile(
                            leading: _isBatchDeleteMode
                                ? Checkbox(
                                    value:
                                        _selectedProductIds.contains(productId),
                                    onChanged: (isSelected) {
                                      _toggleProductSelection(productId);
                                    },
                                  )
                                : (productData['image'] != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          productData['image'],
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Icon(Icons.image_not_supported)),
                            title: Text(productData['name']),
                            subtitle: Text(
                              '\$${productData['price'].toStringAsFixed(2)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: !_isBatchDeleteMode
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit),
                                        onPressed: () => _editProduct(
                                            productId, productData),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete),
                                        onPressed: () =>
                                            _confirmDeleteProduct(productId),
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        },
                      ),
                      if (_isBatchDeleteMode && _selectedProductIds.isNotEmpty)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: FloatingActionButton(
                            onPressed: _batchDeleteProducts,
                            child: Icon(
                              Icons.delete,
                              color: Colors.red,
                            ),
                            tooltip: "Delete Selected Products",
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
