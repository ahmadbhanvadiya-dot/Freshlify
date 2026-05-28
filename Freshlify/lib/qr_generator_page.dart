import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class QrGeneratorPage extends StatefulWidget {
  const QrGeneratorPage({super.key});

  @override
  State<QrGeneratorPage> createState() => _QrGeneratorPageState();
}

class _QrGeneratorPageState extends State<QrGeneratorPage> {
  final TextEditingController productNameController = TextEditingController();
  final GlobalKey qrKey = GlobalKey();

  DateTime? selectedDate;
  String qrData = '';

  String formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> pickDate() async {
    final DateTime now = DateTime.now();

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  void generateQr() {
    final String productName = productNameController.text.trim();

    if (productName.isEmpty || selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter product name and select expiry date'),
        ),
      );
      return;
    }

    final String expiryDate = formatDate(selectedDate!);

    setState(() {
      qrData = '$productName - Expiry: $expiryDate';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR code generated successfully'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void clearForm() {
    setState(() {
      productNameController.clear();
      selectedDate = null;
      qrData = '';
    });
  }

  Future<File?> captureQrAsImage() async {
    try {
      final RenderRepaintBoundary boundary =
          qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final Directory tempDir = await getTemporaryDirectory();

      final String safeName = productNameController.text.trim().isEmpty
          ? 'freshlify_qr'
          : productNameController.text.trim().replaceAll(' ', '_');

      final File file = File('${tempDir.path}/${safeName}_qr.png');
      await file.writeAsBytes(pngBytes);

      return file;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create image: $e'),
        ),
      );
      return null;
    }
  }

  Future<void> shareQr() async {
    if (qrData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generate a QR code first'),
        ),
      );
      return;
    }

    final File? file = await captureQrAsImage();
    if (file == null) return;

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Freshlify product QR',
    );
  }

  @override
  void dispose() {
    productNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasQr = qrData.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate QR Code'),
        centerTitle: true,
        actions: [
          if (hasQr)
            IconButton(
              onPressed: clearForm,
              icon: const Icon(Icons.refresh),
              tooltip: 'Clear',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: productNameController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: pickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  selectedDate == null
                      ? 'Select Expiry Date'
                      : 'Expiry Date: ${formatDate(selectedDate!)}',
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: generateQr,
                icon: const Icon(Icons.qr_code),
                label: const Text('Generate QR'),
              ),
            ),
            const SizedBox(height: 16),
            if (hasQr)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: shareQr,
                  icon: const Icon(Icons.share),
                  label: const Text('Share QR as Image'),
                ),
              ),
            const SizedBox(height: 24),
            if (hasQr) ...[
              RepaintBoundary(
                key: qrKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        qrData,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.qr_code,
                      size: 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Your generated QR code will appear here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}