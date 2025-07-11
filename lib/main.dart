import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:edge_detection/edge_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runZonedGuarded(() {
    runApp(DocumentScannerApp());
  }, (error, stackTrace) {
    debugPrint('Uncaught error: \$error');
    debugPrint('Stack trace: \$stackTrace');
  });
}

class DocumentScannerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: DocumentScannerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DocumentScannerPage extends StatefulWidget {
  @override
  _DocumentScannerPageState createState() => _DocumentScannerPageState();
}

class _DocumentScannerPageState extends State<DocumentScannerPage> {
  List<String> scannedImagePaths = [];

  Future<void> scanDocument() async {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Scanning not supported on emulator")),
    );
    return;
  }

  try {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/scanned_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (!(await Permission.camera.request().isGranted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Camera permission denied")),
      );
      return;
    }

    final success = await EdgeDetection.detectEdge(filePath);
    if (success && mounted) {
      setState(() {
        scannedImagePaths.add(filePath);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Edge detection failed")),
      );
    }
  } catch (e) {
    debugPrint("Edge detection error: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Unexpected error during scan")),
    );
  }
}
  Future<void> pickImagesFromDesktop() async {
    try {
      final files = await openFiles(acceptedTypeGroups: [
        XTypeGroup(label: 'images', extensions: ['jpg', 'png', 'jpeg'])
      ]);

      if (files.isNotEmpty) {
        setState(() {
          scannedImagePaths.addAll(files.map((f) => f.path));
        });
      }
    } catch (e) {
      debugPrint("File picking error: \$e");
    }
  }

  Future<void> pickFromGalleryMobile() async {
    final picker = ImagePicker();
    final pickedImages = await picker.pickMultiImage();

    if (pickedImages != null && pickedImages.isNotEmpty) {
      setState(() {
        scannedImagePaths.addAll(pickedImages.map((e) => e.path));
      });
    }
  }

  Future<void> generatePDF() async {
    if (scannedImagePaths.isEmpty) return;

    try {
      final pdf = pw.Document();

      for (String path in scannedImagePaths) {
        final image = File(path).readAsBytesSync();
        pdf.addPage(
          pw.Page(
            build: (pw.Context context) => pw.Center(
              child: pw.Image(pw.MemoryImage(image)),
            ),
          ),
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final pdfFile = File("${dir.path}/scanned_output_\${DateTime.now().millisecondsSinceEpoch}.pdf");

      await pdfFile.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved at: \${pdfFile.path}')),
      );
    } catch (e) {
      debugPrint("PDF generation error: \$e");
    }
  }

  void clearAllImages() {
    setState(() {
      scannedImagePaths.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Document Scanner'),
        actions: [
          IconButton(
            icon: Icon(Icons.image),
            tooltip: "Pick from Gallery",
            onPressed: () {
              if (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS) {
                pickFromGalleryMobile();
              } else {
                pickImagesFromDesktop();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_forever),
            onPressed: scannedImagePaths.isNotEmpty ? clearAllImages : null,
            tooltip: "Clear All",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: scannedImagePaths.isEmpty
                ? Center(child: Text('No images selected or scanned'))
                : ReorderableListView.builder(
                    itemCount: scannedImagePaths.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = scannedImagePaths.removeAt(oldIndex);
                        scannedImagePaths.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final path = scannedImagePaths[index];
                      return Dismissible(
                        key: ValueKey(path),
                        background: Container(color: Colors.red),
                        onDismissed: (_) {
                          setState(() {
                            scannedImagePaths.removeAt(index);
                          });
                        },
                        child: Card(
                          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: ListTile(
                            leading: Image.file(File(path), width: 50, height: 50, fit: BoxFit.cover),
                            title: Text('Image ${index + 1}'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 15,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.camera),
                  label: Text('Scan'),
                  onPressed: scanDocument,
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.picture_as_pdf),
                  label: Text('Generate PDF'),
                  onPressed: scannedImagePaths.isNotEmpty ? generatePDF : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}