import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:community_impact_tracker/utils/AddSpace.dart'; // Add this import

class ImageUtils {
  static final ImagePicker _imagePicker = ImagePicker();

  static Future<XFile?> pickImage(BuildContext context) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      return pickedFile;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
      return null;
    }
  }

  static Future<String?> uploadImageToStorage(
    BuildContext context,
    XFile imageFile,
    String folder,
  ) async {
    try {
      final String fileName =
          '${folder}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef =
          FirebaseStorage.instance.ref().child(folder).child(fileName);

      final UploadTask uploadTask = storageRef.putFile(File(imageFile.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }

  static Future<void> deleteImageFromStorage(String imageUrl) async {
    try {
      final Reference storageRef =
          FirebaseStorage.instance.refFromURL(imageUrl);
      await storageRef.delete();
    } catch (e) {
      debugPrint('Error deleting image from storage: $e');
    }
  }

  static Widget buildImagePreview({
    required XFile? pickedImage,
    required String? currentImageUrl,
    required bool isRemovingImage,
    required VoidCallback onPickImage,
    required VoidCallback onRemoveImage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Event Image", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: onPickImage,
              child: Text('Select'),
            ),
            if (pickedImage != null || currentImageUrl != null)
              ElevatedButton(
                onPressed: onRemoveImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: Text('Remove'),
              ),
          ],
        ),
        Vspace(10),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: !isRemovingImage
              ? (pickedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(pickedImage.path),
                        fit: BoxFit.cover,
                      ),
                    )
                  : currentImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            currentImageUrl,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Text('No image selected'),
                        ))
              : Center(
                  child: Text('No image selected'),
                ),
        ),
      ],
    );
  }
}
