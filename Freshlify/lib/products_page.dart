import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'product_item.dart';
import 'notification_service.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<ProductItem> history = [];
  String selectedFilter = "All";
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? historyJson = prefs.getStringList('scan_history');

    if (historyJson != null) {
      setState(() {
        history = historyJson
            .map((item) => ProductItem.fromMap(jsonDecode(item)))
            .toList();
        history.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
      });
    } else {
      setState(() {
        history = [];
      });
    }
  }

  Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyJson =
        history.map((item) => jsonEncode(item.toMap())).toList();
    await prefs.setStringList('scan_history', historyJson);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scan_history');
    await NotificationService.cancelAllNotifications();

    setState(() {
      history = [];
      searchQuery = "";
      selectedFilter = "All";
    });
  }

  Future<void> cancelExpiryNotifications(ProductItem product) async {
    final int baseId = product.name.hashCode ^ product.expiryText.hashCode;
    await NotificationService.cancelNotification(baseId);
    await NotificationService.cancelNotification(baseId + 1);
  }

  Future<void> deleteItem(ProductItem item) async {
    setState(() {
      history.removeWhere(
        (historyItem) =>
            historyItem.name == item.name &&
            historyItem.expiryText == item.expiryText,
      );
    });

    await cancelExpiryNotifications(item);
    await saveHistory();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${item.name} removed")),
      );
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

      final DateTime oneDayBefore = expiryAtNineAm.subtract(
        const Duration(days: 1),
      );

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

  Future<void> showEditProductDialog(ProductItem item) async {
    final TextEditingController nameController =
        TextEditingController(text: item.name);

    DateTime selectedDate = DateTime.parse(item.expiryText);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Product"),
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
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
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
                        "Expiry: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final String newName = nameController.text.trim();

                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Product name cannot be empty"),
                        ),
                      );
                      return;
                    }

                    final updatedItem =
                        createManualProduct(newName, selectedDate);

                    await cancelExpiryNotifications(item);

                    setState(() {
                      final int index = history.indexWhere(
                        (historyItem) =>
                            historyItem.name == item.name &&
                            historyItem.expiryText == item.expiryText,
                      );

                      if (index != -1) {
                        history[index] = updatedItem;
                        history.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
                      }
                    });

                    await saveHistory();
                    await scheduleExpiryNotifications(updatedItem);

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("${updatedItem.name} updated")),
                      );
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color getStatusColor(String status) {
    if (status == "Expired") return Colors.red;
    if (status == "Expiring Soon") return Colors.orange;
    return Colors.green;
  }

  IconData getStatusIcon(String status) {
    if (status == "Expired") return Icons.cancel;
    if (status == "Expiring Soon") return Icons.warning;
    return Icons.check_circle;
  }

  String daysLeftText(int daysLeft) {
    if (daysLeft < 0) return "Expired";
    if (daysLeft == 0) return "Expires today";
    if (daysLeft == 1) return "1 day left";
    return "$daysLeft days left";
  }

  List<ProductItem> get filteredHistory {
    List<ProductItem> list;

    if (selectedFilter == "All") {
      list = history;
    } else {
      list = history.where((item) => item.status == selectedFilter).toList();
    }

    if (searchQuery.isEmpty) return list;

    return list.where((item) {
      return item.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }

  int get totalCount => history.length;
  int get freshCount => history.where((item) => item.status == "Fresh").length;
  int get soonCount =>
      history.where((item) => item.status == "Expiring Soon").length;
  int get expiredCount =>
      history.where((item) => item.status == "Expired").length;

  Widget buildFilterChip(String label) {
    final isSelected = selectedFilter == label;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            selectedFilter = label;
          });
        },
      ),
    );
  }

  Widget buildSummaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = filteredHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Products"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: history.isEmpty ? null : clearHistory,
            icon: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                buildSummaryCard(
                  "Total",
                  totalCount.toString(),
                  Colors.blue,
                  Icons.inventory_2,
                ),
                buildSummaryCard(
                  "Fresh",
                  freshCount.toString(),
                  Colors.green,
                  Icons.check_circle,
                ),
                buildSummaryCard(
                  "Soon",
                  soonCount.toString(),
                  Colors.orange,
                  Icons.warning,
                ),
                buildSummaryCard(
                  "Expired",
                  expiredCount.toString(),
                  Colors.red,
                  Icons.cancel,
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Search product...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  buildFilterChip("All"),
                  buildFilterChip("Fresh"),
                  buildFilterChip("Expiring Soon"),
                  buildFilterChip("Expired"),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          Expanded(
            child: visibleItems.isEmpty
                ? Center(
                    child: Text(
                      history.isEmpty
                          ? "No products yet"
                          : "No matching products found",
                      style: const TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: visibleItems.length,
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];

                      return Dismissible(
                        key: ValueKey("${item.name}-${item.expiryText}"),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          deleteItem(item);
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            onTap: () {
                              showEditProductDialog(item);
                            },
                            leading: Icon(
                              getStatusIcon(item.status),
                              color: getStatusColor(item.status),
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "Expiry: ${item.expiryText}\n${daysLeftText(item.daysLeft)}",
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.status,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: getStatusColor(item.status),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}