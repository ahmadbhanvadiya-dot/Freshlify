import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'product_item.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  final ImagePicker picker = ImagePicker();

  String scannedData = "Scan a QR code";
  Color statusColor = Colors.white;

  bool isProcessing = false;
  bool isPickingImage = false;
  String lastScannedCode = "";

  ProductItem? parseProduct(String code) {
    if (!code.contains("Expiry:")) return null;

    try {
      final List<String> parts = code.split("Expiry:");
      final String name = parts[0].replaceAll("-", "").trim();
      final String expiryText = parts[1].trim();

      final DateTime today = DateTime.now();
      final DateTime normalizedToday = DateTime(
        today.year,
        today.month,
        today.day,
      );

      final DateTime expiryDate = DateTime.parse(expiryText);
      final DateTime normalizedExpiry = DateTime(
        expiryDate.year,
        expiryDate.month,
        expiryDate.day,
      );

      final int daysLeft = normalizedExpiry.difference(normalizedToday).inDays;

      String status;
      if (daysLeft < 0) {
        status = "Expired";
      } else if (daysLeft <= 2) {
        status = "Expiring Soon";
      } else {
        status = "Fresh";
      }

      return ProductItem(
        name: name,
        expiryText: expiryText,
        daysLeft: daysLeft,
        status: status,
      );
    } catch (e) {
      return null;
    }
  }

  ProductItem createManualProduct(String name, DateTime expiryDate) {
    final DateTime today = DateTime.now();
    final DateTime normalizedToday = DateTime(today.year, today.month, today.day);
    final DateTime normalizedExpiry =
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

    final String expiryText =
        "${normalizedExpiry.year.toString().padLeft(4, '0')}-"
        "${normalizedExpiry.month.toString().padLeft(2, '0')}-"
        "${normalizedExpiry.day.toString().padLeft(2, '0')}";

    final int daysLeft = normalizedExpiry.difference(normalizedToday).inDays;

    String status;
    if (daysLeft < 0) {
      status = "Expired";
    } else if (daysLeft <= 2) {
      status = "Expiring Soon";
    } else {
      status = "Fresh";
    }

    return ProductItem(
      name: name.trim(),
      expiryText: expiryText,
      daysLeft: daysLeft,
      status: status,
    );
  }

  Color getStatusColor(String status) {
    if (status == "Expired") return Colors.red;
    if (status == "Expiring Soon") return Colors.orange;
    return Colors.green;
  }

  Future<void> scheduleExpiryNotifications(ProductItem product) async {
    try {
      final DateTime now = DateTime.now();
      final DateTime expiryDate = DateTime.parse(product.expiryText);

      final DateTime expiryAtNineAm = DateTime(
        expiryDate.year,
        expiryDate.month,
        expiryDate.day,
        9,
        0,
      );

      final DateTime oneDayBefore =
          expiryAtNineAm.subtract(const Duration(days: 1));

      final int baseId = product.name.hashCode ^ product.expiryText.hashCode;

      if (oneDayBefore.isAfter(now)) {
        await NotificationService.scheduleNotification(
          id: baseId,
          title: 'Product expiring soon',
          body: '${product.name} will expire tomorrow',
          scheduledDate: oneDayBefore,
        );
      }

      if (expiryAtNineAm.isAfter(now)) {
        await NotificationService.scheduleNotification(
          id: baseId + 1,
          title: 'Product expires today',
          body: '${product.name} expires today',
          scheduledDate: expiryAtNineAm,
        );
      }
    } catch (e) {
      debugPrint('Notification scheduling failed: $e');
    }
  }

  Future<void> saveProduct(ProductItem product) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyJson = prefs.getStringList('scan_history') ?? [];

    final List<ProductItem> history = historyJson
        .map((item) => ProductItem.fromMap(jsonDecode(item)))
        .toList();

    final bool alreadyExists = history.any(
      (item) =>
          item.name == product.name && item.expiryText == product.expiryText,
    );

    if (!alreadyExists) {
      history.insert(0, product);
      history.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

      final List<String> updatedJson =
          history.map((item) => jsonEncode(item.toMap())).toList();

      await prefs.setStringList('scan_history', updatedJson);
      await scheduleExpiryNotifications(product);
    }
  }

  Future<void> addManualItem(ProductItem product) async {
    setState(() {
      scannedData =
          "${product.name}\nExpiry: ${product.expiryText}\n${product.status}";
      statusColor = getStatusColor(product.status).withOpacity(0.25);
    });

    await saveProduct(product);
  }

  Future<void> showAddProductDialog() async {
    final TextEditingController nameController = TextEditingController();
    DateTime? selectedDate;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Product"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Product Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final DateTime now = DateTime.now();
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (pickedDate != null) {
                          setDialogState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                      child: Text(
                        selectedDate == null
                            ? "Select Expiry Date"
                            : "Expiry: ${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}",
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final String name = nameController.text.trim();

                    if (name.isEmpty || selectedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Please enter product name and expiry date",
                          ),
                        ),
                      );
                      return;
                    }

                    final product = createManualProduct(name, selectedDate!);
                    await addManualItem(product);

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("${product.name} added successfully"),
                        ),
                      );
                    }
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> processScannedCode(String code, {required String source}) async {
    final product = parseProduct(code);

    if (product != null) {
      setState(() {
        scannedData =
            "${product.name}\nExpiry: ${product.expiryText}\n${product.status}";
        statusColor = getStatusColor(product.status).withOpacity(0.25);
      });

      await saveProduct(product);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${product.name} $source successfully"),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() {
        scannedData = code;
        statusColor = Colors.white;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid product QR format"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> handleScan(String code) async {
    if (isProcessing) return;
    if (code == lastScannedCode) return;

    isProcessing = true;
    lastScannedCode = code;

    await processScannedCode(code, source: "scanned");

    await Future.delayed(const Duration(seconds: 2));
    isProcessing = false;
  }

Future<void> scanFromGallery() async {
  if (isPickingImage) return;

  setState(() {
    isPickingImage = true;
  });

  try {
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) {
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Gallery QR scan is not supported with your current mobile_scanner version yet.",
          ),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to open gallery: $e"),
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        isPickingImage = false;
      });
    }
  }
}
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: statusColor,
      appBar: AppBar(
        title: const Text("Freshlify Scanner"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: isPickingImage ? null : scanFromGallery,
            icon: const Icon(Icons.photo_library),
            tooltip: "Scan from Gallery",
          ),
          IconButton(
            onPressed: showAddProductDialog,
            icon: const Icon(Icons.add),
            tooltip: "Add Product",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: (BarcodeCapture capture) {
                    final List<Barcode> barcodes = capture.barcodes;

                    for (final barcode in barcodes) {
                      final String? code = barcode.rawValue;
                      if (code != null) {
                        handleScan(code);
                        break;
                      }
                    }
                  },
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    onPressed: isPickingImage ? null : scanFromGallery,
                    child: isPickingImage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black.withOpacity(0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Latest Scan",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        scannedData,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddProductDialog,
        icon: const Icon(Icons.add),
        label: const Text("Add Product"),
      ),
    );
  }
}   