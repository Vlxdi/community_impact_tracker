import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImagerPage extends StatefulWidget {
  const ImagerPage({Key? key}) : super(key: key);

  @override
  _ImagerPageState createState() => _ImagerPageState();
}

class _ImagerPageState extends State<ImagerPage> {
  List<UploadTask> _uploadTasks = [];

  Future<UploadTask?> uploadFile(XFile? file) async {
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No file was selected'),
        ),
      );
      return null;
    }

    UploadTask uploadTask;

    // Adjusting reference to 'profile_pictures' folder
    Reference ref = FirebaseStorage.instance
        .ref()
        .child('profile_pictures')
        .child('image_${DateTime.now().millisecondsSinceEpoch}.jpg');

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {'picked-file-path': file.path},
    );

    if (kIsWeb) {
      uploadTask = ref.putData(await file.readAsBytes(), metadata);
    } else {
      uploadTask = ref.putFile(io.File(file.path), metadata);
    }

    return Future.value(uploadTask);
  }

  UploadTask uploadString() {
    const String putStringText =
        'This upload has been generated using the putString method! Check the metadata too!';

    // Adjusting reference to 'profile_pictures' folder
    Reference ref = FirebaseStorage.instance
        .ref()
        .child('profile_pictures')
        .child('put-string-example.txt');

    return ref.putString(
      putStringText,
      metadata: SettableMetadata(
        contentLanguage: 'en',
        customMetadata: <String, String>{'example': 'putString'},
      ),
    );
  }

  Future<UploadTask> uploadUint8List() async {
    UploadTask uploadTask;

    // Adjusting reference to 'profile_pictures' folder
    Reference ref = FirebaseStorage.instance
        .ref()
        .child('profile_pictures')
        .child('some-json.json');

    const response = '{"key": "value", "number": 42}';
    final data = jsonDecode(response);

    uploadTask = ref.putData(Uint8List.fromList(utf8.encode(jsonEncode(data))));

    return Future.value(uploadTask);
  }

  Future<void> handleUploadType(UploadType type) async {
    switch (type) {
      case UploadType.string:
        setState(() {
          _uploadTasks = [..._uploadTasks, uploadString()];
        });
        break;
      case UploadType.file:
        final file = await ImagePicker().pickImage(source: ImageSource.gallery);
        UploadTask? task = await uploadFile(file);

        if (task != null) {
          setState(() {
            _uploadTasks = [..._uploadTasks, task];
          });
        }
        break;
      case UploadType.uint8List:
        final task = await uploadUint8List();
        setState(() {
          _uploadTasks = [..._uploadTasks, task];
        });
        break;
      case UploadType.clear:
        setState(() {
          _uploadTasks = [];
        });
        break;
    }
  }

  void _removeTaskAtIndex(int index) {
    setState(() {
      _uploadTasks = _uploadTasks..removeAt(index);
    });
  }

  Future<void> _downloadBytes(Reference ref) async {
    final bytes = await ref.getData();
    await saveAsBytes(bytes!, 'some-image.jpg');
  }

  Future<void> _downloadLink(Reference ref) async {
    final link = await ref.getDownloadURL();

    await Clipboard.setData(
      ClipboardData(
        text: link,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Success!\n Copied download URL to Clipboard!'),
      ),
    );
  }

  Future<void> _downloadFile(Reference ref) async {
    final io.Directory systemTempDir = io.Directory.systemTemp;
    final io.File tempFile = io.File('${systemTempDir.path}/temp-${ref.name}');
    if (tempFile.existsSync()) await tempFile.delete();

    await ref.writeToFile(tempFile);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Success!\n Downloaded ${ref.name} \n from bucket: ${ref.bucket}\n '
          'at path: ${ref.fullPath} \n'
          'Wrote "${ref.fullPath}" to tmp-${ref.name}',
        ),
      ),
    );
  }

  Future<void> _delete(Reference ref) async {
    await ref.delete();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Success!\n deleted ${ref.name} \n from bucket: ${ref.bucket}\n '
            'at path: ${ref.fullPath} \n'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Upload Page'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              handleUploadType(UploadType.file);
            },
            child: const Text('Upload File'),
          ),
          _uploadTasks.isEmpty
              ? const Center(child: Text("Press the button to upload a file."))
              : Expanded(
                  child: ListView.builder(
                    itemCount: _uploadTasks.length,
                    itemBuilder: (context, index) => UploadTaskListTile(
                      task: _uploadTasks[index],
                      onDismissed: () => _removeTaskAtIndex(index),
                      onDownloadLink: () async {
                        return _downloadLink(_uploadTasks[index].snapshot.ref);
                      },
                      onDownload: () async {
                        if (kIsWeb) {
                          return _downloadBytes(
                              _uploadTasks[index].snapshot.ref);
                        } else {
                          return _downloadFile(
                              _uploadTasks[index].snapshot.ref);
                        }
                      },
                      onDelete: () async {
                        return _delete(_uploadTasks[index].snapshot.ref);
                      },
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class UploadTaskListTile extends StatelessWidget {
  const UploadTaskListTile({
    Key? key,
    required this.task,
    required this.onDismissed,
    required this.onDownload,
    required this.onDownloadLink,
    required this.onDelete,
  }) : super(key: key);

  final UploadTask task;
  final VoidCallback onDismissed;
  final VoidCallback onDownload;
  final VoidCallback onDownloadLink;
  final VoidCallback onDelete;

  String _bytesTransferred(TaskSnapshot snapshot) {
    return '${snapshot.bytesTransferred}/${snapshot.totalBytes}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TaskSnapshot>(
      stream: task.snapshotEvents,
      builder: (
        BuildContext context,
        AsyncSnapshot<TaskSnapshot> asyncSnapshot,
      ) {
        Widget subtitle = const Text('---');
        TaskSnapshot? snapshot = asyncSnapshot.data;
        TaskState? state = snapshot?.state;

        if (asyncSnapshot.hasError) {
          if (asyncSnapshot.error is FirebaseException &&
              (asyncSnapshot.error as FirebaseException).code == 'canceled') {
            subtitle = const Text('Upload canceled.');
          } else {
            subtitle = const Text('Something went wrong.');
          }
        } else if (snapshot != null) {
          subtitle = Text('$state: ${_bytesTransferred(snapshot)} bytes sent');
        }

        return Dismissible(
          key: Key(task.hashCode.toString()),
          onDismissed: ($) => onDismissed(),
          child: ListTile(
            title: Text('Upload Task #${task.hashCode}'),
            subtitle: subtitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (state == TaskState.running)
                  IconButton(
                    icon: const Icon(Icons.pause),
                    onPressed: task.pause,
                  ),
                if (state == TaskState.running)
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed: task.cancel,
                  ),
                if (state == TaskState.paused)
                  IconButton(
                    icon: const Icon(Icons.file_upload),
                    onPressed: task.resume,
                  ),
                if (state == TaskState.success)
                  IconButton(
                    icon: const Icon(Icons.file_download),
                    onPressed: onDownload,
                  ),
                if (state == TaskState.success)
                  IconButton(
                    icon: const Icon(Icons.link),
                    onPressed: onDownloadLink,
                  ),
                if (state == TaskState.success)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum UploadType {
  string,
  file,
  uint8List,
  clear,
}

Future<void> saveAsBytes(Uint8List bytes, String filename) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = io.File('${directory.path}/$filename');
  await file.writeAsBytes(bytes);
  print('Saved file at: ${file.path}');
}
