import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class Imager extends StatefulWidget {
  const Imager({super.key});

  @override
  State<Imager> createState() => _ImagerState();
}

class _ImagerState extends State<Imager> {
  PlatformFile? pickedFile;
  bool isUploading = false;
  String? errorMessage;
  final FirebaseStorage storage = FirebaseStorage.instance;

  Future selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result == null) return;

      setState(() {
        pickedFile = result.files.first;
        errorMessage = null;
      });
    } catch (e) {
      print('Error selecting file: $e');
      setState(() {
        errorMessage = 'Error selecting file: $e';
      });
    }
  }

  Future<void> uploadFile() async {
    if (pickedFile == null) {
      setState(() {
        errorMessage = 'Please select a file first';
      });
      return;
    }

    setState(() {
      isUploading = true;
      errorMessage = null;
    });

    try {
      // Create file reference
      final fileName =
          DateTime.now().millisecondsSinceEpoch.toString() + '.jpg';
      final filePath = 'profile_pictures/$fileName';

      // Print the full path for debugging
      print('Attempting to upload to path: $filePath');

      // Create the directory first
      try {
        final dirRef = storage.ref().child('profile_pictures');
        await dirRef
            .getData(); // This will throw an error if the directory doesn't exist
      } catch (e) {
        print('Creating directory: profile_pictures');
        // Directory doesn't exist, but that's okay - Firebase will create it
      }

      // Create file reference and upload
      final fileRef = storage.ref().child(filePath);
      final file = File(pickedFile!.path!);

      // Simple upload without metadata
      final uploadTask = await fileRef.putFile(file);

      if (uploadTask.state == TaskState.success) {
        final downloadUrl = await fileRef.getDownloadURL();
        print('Upload successful! Download URL: $downloadUrl');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload successful!')),
          );
        }
      } else {
        throw Exception('Upload failed: ${uploadTask.state}');
      }
    } catch (e) {
      print('Error during upload: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Error during upload: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Upload'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: isUploading ? null : selectFile,
                  child: const Text('SELECT FILE'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isUploading ? null : uploadFile,
                  child: isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('UPLOAD FILE'),
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (pickedFile != null) ...[
                  const SizedBox(height: 16),
                  Image.file(
                    File(pickedFile!.path!),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
