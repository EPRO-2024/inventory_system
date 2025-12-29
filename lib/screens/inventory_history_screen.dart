import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'product_detail_screen.dart'; // Import หน้ารายละเอียด

class InventoryHistoryScreen extends StatefulWidget {
  const InventoryHistoryScreen({super.key});

  @override
  State<InventoryHistoryScreen> createState() => _InventoryHistoryScreenState();
}

class _InventoryHistoryScreenState extends State<InventoryHistoryScreen> {

  @override
  void initState() {
    super.initState();
    _autoCleanupOldData();
  }

  Future<void> _autoCleanupOldData() async {
    final DateTime cutoffDate = DateTime.now().subtract(const Duration(days: 1825)); // 5 ปี

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('outOfStockDate', isNull: false)
          .where('outOfStockDate', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ระบบได้ล้างข้อมูลเก่าเกิน 5 ปี จำนวน ${snapshot.docs.length} รายการ'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error cleaning up old data: $e");
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    if (date is Timestamp) {
      return DateFormat('dd/MM/yyyy HH:mm').format(date.toDate());
    }
    return '-';
  }

  Future<void> _deleteProduct(BuildContext context, String docId, String productName) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: Text('คุณต้องการลบรายการ "$productName" ออกจากระบบถาวรใช่หรือไม่?\n(ข้อมูลจะหายไปจากทุกหน้าจอ)'),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('ลบข้อมูล', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await FirebaseFirestore.instance.collection('products').doc(docId).delete();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ลบรายการเรียบร้อยแล้ว'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติสินค้าหมด (Out of Stock)'),
        backgroundColor: Colors.grey.shade100,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('ไม่พบข้อมูล'));

          final allDocs = snapshot.data!.docs;

          final outOfStockDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final qty = data['stockQty'] is int 
                ? (data['stockQty'] as int).toDouble() 
                : (data['stockQty'] as double? ?? 0.0);
            return qty <= 0;
          }).toList();

          if (outOfStockDocs.isEmpty) {
            return const Center(child: Text('ไม่มีรายการสินค้าหมด'));
          }

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.red.shade50),
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('รหัสสินค้า', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ชื่อสินค้า', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('วันที่นำเข้า', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('วันที่สินค้าหมด', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                  DataColumn(label: Text('จัดการ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                ],
                rows: outOfStockDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final docId = doc.id;
                  final name = data['name']?.toString() ?? '-';
                  
                  return DataRow(cells: [
                    DataCell(Text(data['productId']?.toString() ?? '-')),
                    // แก้ไขชื่อสินค้าให้กดได้
                    DataCell(
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetailScreen(
                                productData: data, 
                                docId: docId,
                                isReadOnly: true, // เปิดในโหมดดูอย่างเดียวและลบได้
                              ),
                            ),
                          );
                        },
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            name, 
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(_formatDate(data['createDate']))),
                    DataCell(Text(
                      _formatDate(data['outOfStockDate']),
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    )),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        tooltip: 'ลบรายการนี้ถาวร',
                        onPressed: () => _deleteProduct(context, docId, name),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}