import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'product_form_screen.dart';
import 'inventory_history_screen.dart';
import 'product_detail_screen.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  String _searchQuery = '';
  bool _isGridView = false; // ตัวแปรสำหรับสลับโหมดการแสดงผล

  // ฟังก์ชันแสดง Popup ดูรูปขยาย
  void _showImagePopup(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black)]),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // Helper สำหรับแปลงค่าตัวเลข
  double _parseNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100, // พื้นหลังสีเทาอ่อนเพื่อให้ Card ดูเด่นขึ้น
      appBar: AppBar(
        title: const Text('รายการสินค้าคงคลัง', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          // ปุ่มสลับโหมดการแสดงผล (List <-> Grid)
          IconButton(
            tooltip: _isGridView ? 'เปลี่ยนเป็นแบบตาราง' : 'เปลี่ยนเป็นแบบการ์ด',
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. ส่วนช่องค้นหา
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'ค้นหาชื่อสินค้า...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const InventoryHistoryScreen()),
                    );
                  },
                  icon: const Icon(Icons.history, color: Colors.white),
                  label: const Text('สินค้าหมด', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          // 2. ส่วนแสดงรายการสินค้า
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('ไม่พบข้อมูลสินค้า'));
                }

                final allDocs = snapshot.data!.docs;
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  
                  final qty = _parseNumber(data['stockQty']);
                  if (qty <= 0) return false; // กรองสินค้าหมดออก

                  final name = data['name']?.toString().toLowerCase() ?? '';
                  final query = _searchQuery.toLowerCase();
                  return name.contains(query);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty 
                              ? 'สินค้าหมดทุกรายการ (กรุณาดูในเมนูประวัติ)' 
                              : 'ไม่พบสินค้า "$_searchQuery"', 
                          style: const TextStyle(color: Colors.grey)
                        ),
                      ],
                    ),
                  );
                }

                // เลือกแสดงผลตามโหมดที่เลือก
                return _isGridView 
                    ? _buildGridView(filteredDocs) 
                    : _buildListView(filteredDocs);
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget: แสดงผลแบบตาราง (List View เดิม) ---
  Widget _buildListView(List<DocumentSnapshot> docs) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.white),
          dataRowColor: WidgetStateProperty.all(Colors.white),
          dataRowMinHeight: 60,
          dataRowMaxHeight: 80, 
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('รหัสสินค้า', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ชื่อสินค้า', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ขนาด', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('จำนวน', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('น้ำหนัก/ชิ้น', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('น้ำหนักรวม', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ตำแหน่ง', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('รูปภาพ', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            Map<String, dynamic> formData = Map.from(data);
            formData['docId'] = doc.id; 

            String? firstImageUrl;
            if (data['images'] != null && (data['images'] as List).isNotEmpty) {
              firstImageUrl = (data['images'] as List).first.toString();
            }

            double stockQty = _parseNumber(data['stockQty']);
            double weightPerUnit = _parseNumber(data['weight']);
            double totalWeight = _parseNumber(data['totalCurrentWeight']);
            if (totalWeight == 0 && stockQty > 0 && weightPerUnit > 0) {
              totalWeight = stockQty * weightPerUnit;
            }

            final numFormat = NumberFormat('#,##0.##');

            return DataRow(cells: [
              DataCell(Text(data['productId']?.toString() ?? '-')),
              DataCell(
                InkWell(
                  onTap: () => _navigateToDetail(data, doc.id),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 150, 
                        child: Text(
                          data['name']?.toString() ?? '-', 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary, 
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
                        onPressed: () => _navigateToEdit(formData),
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(Text(data['size']?.toString() ?? '-')),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (stockQty < _parseNumber(data['reorderPoint'])) 
                      ? Colors.red.withOpacity(0.1) 
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  numFormat.format(stockQty),
                  style: TextStyle(
                    color: (stockQty < _parseNumber(data['reorderPoint'])) 
                        ? Colors.red 
                        : Colors.green.shade700,
                    fontWeight: FontWeight.bold
                  ),
                ),
              )),
              DataCell(Text('${numFormat.format(weightPerUnit)} กก.')),
              DataCell(Text('${numFormat.format(totalWeight)} กก.', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(data['location']?.toString() ?? '-'),
                ],
              )),
              DataCell(
                firstImageUrl != null 
                ? InkWell(
                    onTap: () => _showImagePopup(firstImageUrl!),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        image: DecorationImage(image: NetworkImage(firstImageUrl), fit: BoxFit.cover),
                        border: Border.all(color: Colors.grey.shade300)
                      ),
                    ),
                  )
                : const Text('-', style: TextStyle(color: Colors.grey)),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // --- Widget: แสดงผลแบบการ์ด Grid (แบบใหม่) ---
  Widget _buildGridView(List<DocumentSnapshot> docs) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 คอลัมน์
        childAspectRatio: 0.55, // สัดส่วนการ์ด (ปรับความสูงที่นี่)
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        
        // เตรียมข้อมูลแสดงผล
        List<String> images = [];
        if (data['images'] != null && (data['images'] as List).isNotEmpty) {
          images = List<String>.from(data['images']);
        }
        
        double stockQty = _parseNumber(data['stockQty']);
        double weightPerUnit = _parseNumber(data['weight']);
        double totalWeight = _parseNumber(data['totalCurrentWeight']);
        if (totalWeight == 0) totalWeight = stockQty * weightPerUnit;
        
        final numFormat = NumberFormat('#,##0.##');

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          color: Colors.white,
          child: InkWell(
            onTap: () => _navigateToDetail(data, doc.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. ส่วนรูปภาพสไลด์ (Carousel) สัดส่วน 1:1
                AspectRatio(
                  aspectRatio: 1,
                  child: images.isNotEmpty
                      ? PageView.builder(
                          itemCount: images.length,
                          itemBuilder: (context, imgIndex) {
                            return Image.network(
                              images[imgIndex],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey)),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Center(child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey)),
                        ),
                ),
                
                // 2. ส่วนข้อมูลสินค้า (Middle)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // รหัสสินค้า (SKU)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            data['productId']?.toString() ?? '-',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        // ชื่อสินค้า
                        Text(
                          data['name']?.toString() ?? 'ไม่มีชื่อ',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.2),
                        ),
                        const Spacer(), // ดันข้อมูลล่างสุดลงไป
                        
                        const Divider(height: 12),
                        
                        // รายละเอียด 3-7
                        _buildGridDetailRow(Icons.straighten, 'ขนาด:', data['size']?.toString() ?? '-'),
                        _buildGridDetailRow(Icons.inventory_2, 'คงเหลือ:', '${numFormat.format(stockQty)} ${data['unit'] ?? ''}', 
                            color: stockQty < _parseNumber(data['reorderPoint']) ? Colors.red : Colors.green),
                        _buildGridDetailRow(Icons.monitor_weight_outlined, 'ต่อชิ้น:', '${numFormat.format(weightPerUnit)} กก.'),
                        _buildGridDetailRow(Icons.scale, 'รวม:', '${numFormat.format(totalWeight)} กก.'),
                        _buildGridDetailRow(Icons.location_on, 'ที่เก็บ:', data['location']?.toString() ?? '-'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget ย่อยสำหรับแสดงแถวข้อมูลในการ์ด
  Widget _buildGridDetailRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(fontSize: 11, color: Colors.black87),
                children: [
                  TextSpan(text: '$label ', style: const TextStyle(color: Colors.grey)),
                  TextSpan(text: value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(Map<String, dynamic> data, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(productData: data, docId: id),
      ),
    );
  }

  void _navigateToEdit(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductFormScreen(initialData: data),
      ),
    );
  }
}