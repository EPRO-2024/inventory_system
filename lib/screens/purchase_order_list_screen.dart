import 'package:flutter/material.dart';
import 'product_form_screen.dart';

class PurchaseOrderListScreen extends StatelessWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock Data จำลองรายการสั่งซื้อจากระบบอื่น
    final List<Map<String, dynamic>> mockOrders = [
      {
        'po_id': 'PO-2023-001',
        'supplier': 'ABC Supply Co., Ltd.',
        'items': [
          {
            'name': 'เสื้อยืด Cotton 100%',
            'brand': 'MyBrand',
            'category': 'เสื้อผ้า',
            'costPrice': 80,
            'retailPrice': 199,
            'stockQty': 500,
            'unit': 'ตัว',
            'status': 'มีสินค้า'
          }
        ]
      },
      {
        'po_id': 'PO-2023-002',
        'supplier': 'Gadget Wholesaler',
        'items': [
          {
            'name': 'หูฟังไร้สาย Pro',
            'brand': 'SoundX',
            'category': 'เครื่องใช้ไฟฟ้า',
            'costPrice': 450,
            'retailPrice': 1290,
            'stockQty': 100,
            'unit': 'ชิ้น',
            'description': 'หูฟังตัดเสียงรบกวน แบตอึด 20 ชม.',
            'status': 'มีสินค้า'
          }
        ]
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('เลือกรายการสั่งซื้อ (PO)')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mockOrders.length,
        itemBuilder: (context, index) {
          final order = mockOrders[index];
          final item = (order['items'] as List).first; // สมมติว่าดึงสินค้าตัวแรกมาแสดง

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.inventory, color: Colors.blue),
              ),
              title: Text(order['po_id'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${order['supplier']}\nสินค้า: ${item['name']} (${item['stockQty']} ${item['unit']})'),
              isThreeLine: true,
              trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
              onTap: () {
                // กดแล้วส่งข้อมูลไปหน้า Form เพื่อ Prefill
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductFormScreen(initialData: item),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}