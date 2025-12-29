import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // เพิ่ม import สำหรับลบข้อมูล
import 'product_form_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> productData;
  final String docId;
  final bool isReadOnly; // เพิ่มตัวแปรสำหรับโหมดดูอย่างเดียว

  const ProductDetailScreen({
    super.key,
    required this.productData,
    required this.docId,
    this.isReadOnly = false, // ค่าเริ่มต้นคือแก้ไขได้
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _currentImageIndex = 0; 

  // --- Helper Functions ---

  String _getString(String key, {String suffix = ''}) {
    if (widget.productData[key] == null || widget.productData[key].toString().trim().isEmpty) {
      return '-';
    }
    return '${widget.productData[key]}$suffix';
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    DateTime dt;
    if (date.runtimeType.toString() == 'Timestamp') {
      dt = date.toDate();
    } else if (date is DateTime) {
      dt = date;
    } else {
      return '-';
    }
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  String _formatNumber(String key, {bool isCurrency = false, String suffix = ''}) {
    if (widget.productData[key] == null) return '-';
    
    double val;
    if (widget.productData[key] is int) {
      val = (widget.productData[key] as int).toDouble();
    } else if (widget.productData[key] is double) {
      val = widget.productData[key];
    } else if (widget.productData[key] is String) {
      val = double.tryParse(widget.productData[key]) ?? 0.0;
    } else {
      return '-';
    }

    final formatter = isCurrency ? NumberFormat('#,##0.00') : NumberFormat('#,##0.##');
    return '${formatter.format(val)}$suffix';
  }

  // ฟังก์ชันลบสินค้า (สำหรับโหมด ReadOnly)
  Future<void> _deleteProduct() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: Text('คุณต้องการลบรายการ "${widget.productData['name']}" ออกจากระบบถาวรใช่หรือไม่?'),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('ลบข้อมูล', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop(); // ปิด Dialog
                try {
                  await FirebaseFirestore.instance.collection('products').doc(widget.docId).delete();
                  if (mounted) {
                    Navigator.of(context).pop(); // ปิดหน้า Detail กลับไปหน้าก่อนหน้า
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ลบรายการเรียบร้อยแล้ว'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
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

  void _showFullGallery(BuildContext context, List<String> images, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            PageView.builder(
              itemCount: images.length,
              controller: PageController(initialPage: initialIndex),
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    images[index],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.white)),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "เลื่อนเพื่อดูรูปอื่น ๆ",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> images = [];
    if (widget.productData['images'] != null && widget.productData['images'] is List) {
      images = List<String>.from(widget.productData['images']);
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: CustomScrollView(
        slivers: [
          // 1. ส่วนหัวรูปภาพ
          SliverAppBar(
            expandedHeight: 350.0,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: images.isNotEmpty
                  ? Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _showFullGallery(context, images, index),
                              child: Image.network(
                                images[index],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.white)),
                              ),
                            );
                          },
                        ),
                        if (images.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black54, Colors.transparent],
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: images.asMap().entries.map((entry) {
                                return Container(
                                  width: 8.0,
                                  height: 8.0,
                                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentImageIndex == entry.key
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.4),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('ไม่มีรูปภาพสินค้า', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
            ),
            actions: [
              // เงื่อนไขการแสดงปุ่ม: ถ้า ReadOnly ให้แสดงปุ่มลบ ถ้าไม่ ให้แสดงปุ่มแก้ไข
              if (widget.isReadOnly)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.red,
                      radius: 20,
                      child: Icon(Icons.delete_forever, color: Colors.white, size: 24),
                    ),
                    tooltip: 'ลบสินค้านี้',
                    onPressed: _deleteProduct,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 18,
                      child: Icon(Icons.edit, color: Colors.blue, size: 20),
                    ),
                    tooltip: 'แก้ไขข้อมูล',
                    onPressed: () {
                      Map<String, dynamic> editData = Map.from(widget.productData);
                      editData['docId'] = widget.docId;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductFormScreen(initialData: editData),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),

          // 2. ส่วนเนื้อหา (แสดงเหมือนเดิม)
          SliverToBoxAdapter(
            child: Container(
              transform: Matrix4.translationValues(0.0, -20.0, 0.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- ส่วนหัว: ชื่อสินค้า ---
                  Center(
                    child: Container(
                      width: 50, height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  Text(
                    _getString('name'),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  
                  // แสดง SKU
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SKU: ${_getString('productId')}',
                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // --- [New Header Section] ราคา ---
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPriceBox(context, 'ราคาขายส่ง', _formatNumber('wholesalePrice', isCurrency: true)),
                        Container(width: 1, height: 40, color: Colors.grey.shade300), 
                        _buildPriceBox(context, 'ราคาขายปลีก', _formatNumber('retailPrice', isCurrency: true), isPrimary: true),
                        Container(width: 1, height: 40, color: Colors.grey.shade300), 
                        _buildPriceBox(context, 'ยอดซื้อขั้นต่ำ', _formatNumber('reorderPoint', suffix: ' ${_getString('unit')}')),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),

                  // --- [Highlight Section] ข้อมูลสำคัญ ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.stars_rounded, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('ข้อมูลสินค้าคงคลัง (Highlight)', 
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                          ],
                        ),
                        const Divider(height: 30),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHighlightItem(
                              context, 
                              icon: Icons.straighten, 
                              label: 'ขนาด (Size)', 
                              value: _getString('size'),
                            ),
                            _buildHighlightItem(
                              context, 
                              icon: Icons.inventory_2, 
                              label: 'จำนวนคงเหลือ', 
                              value: _formatNumber('stockQty'), 
                              unit: _getString('unit'),
                              isAccent: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHighlightItem(
                              context, 
                              icon: Icons.monitor_weight_outlined, 
                              label: 'น้ำหนักต่อชิ้น', 
                              value: _formatNumber('weight'), 
                              unit: 'กก.',
                            ),
                            _buildHighlightItem(
                              context, 
                              icon: Icons.scale_rounded, 
                              label: 'น้ำหนักรวมคงเหลือ', 
                              value: _formatNumber('totalCurrentWeight'), 
                              unit: 'กก.',
                              isAccent: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHighlightItem(
                              context, 
                              icon: Icons.location_on, 
                              label: 'ตำแหน่งจัดเก็บ', 
                              value: _getString('location'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  
                  // --- รายละเอียดอื่นๆ ---
                  _buildSectionHeader('1. ข้อมูลพื้นฐานทั่วไป', Icons.info_outline),
                  _buildDetailRow('ชื่อเรียกอื่น', _getString('alias')),
                  _buildDetailRow('หมวดหมู่', _getString('category')),
                  _buildDetailRow('แบรนด์', _getString('brand')),
                  _buildDetailRow('รุ่น (Model)', _getString('model')),
                  _buildDetailRow('คำค้นหา (Tags)', _getString('keywords')),
                  
                  const Divider(height: 32),

                  _buildSectionHeader('2. รายละเอียด & การตลาด', Icons.campaign_outlined),
                  _buildDescriptionBox(_getString('description')),
                  const SizedBox(height: 12),
                  _buildDetailRow('จุดเด่นสินค้า', _getString('sellingPoints')),
                  _buildDetailRow('กลุ่มเป้าหมาย', _getString('targetAudience')),
                  _buildDetailRow('มาตรฐาน/อย.', _getString('complianceNumber')),

                  const Divider(height: 32),

                  _buildSectionHeader('3. รายละเอียดคลังสินค้า', Icons.warehouse_outlined),
                  _buildDetailRow('จำนวนสินค้าแรกเข้า', _formatNumber('initialStock', suffix: ' ${_getString('unit')}')),
                  _buildDetailRow('น้ำหนักรวมสินค้าแรกเข้า', _formatNumber('totalInitialWeight', suffix: ' กก.')),
                  _buildDetailRow('สถานะสินค้า', _getString('status')),
                  _buildDetailRow('หน่วยนับ', _getString('unit')),
                  _buildDetailRow('Batch / Lot', _getString('batchNumber')),
                  _buildDetailRow('วันหมดอายุ', _formatDate(widget.productData['expiryDate'])),

                  const Divider(height: 32),

                  _buildSectionHeader('4. โครงสร้างราคา', Icons.attach_money),
                  _buildDetailRow('ราคาทุน', _formatNumber('costPrice', isCurrency: true)),
                  _buildDetailRow('ภาษี (VAT)', _formatNumber('vatRate', suffix: '%')),

                  const Divider(height: 32),

                  _buildSectionHeader('5. ข้อมูลกายภาพเพิ่มเติม', Icons.aspect_ratio),
                  _buildDetailRow('สี', _getString('color')),
                  _buildDetailRow('วัสดุ', _getString('material')),
                  _buildDetailRow('ขนาดกล่อง (กxยxส)', _getString('dimensions')),

                  const Divider(height: 32),

                  _buildSectionHeader('6. บันทึกระบบ', Icons.history),
                  _buildDetailRow('วันที่สร้างข้อมูล', _formatDate(widget.productData['createDate'])),
                  _buildDetailRow('แก้ไขล่าสุด', _formatDate(widget.productData['lastModified'])),
                  _buildDetailRow('ผู้แก้ไข', _getString('modifiedBy')),
                  _buildDetailRow('ประวัติสินค้าหมด', _formatDate(widget.productData['outOfStockDate'])),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets ย่อย ---

  Widget _buildPriceBox(BuildContext context, String label, String value, {bool isPrimary = false}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isPrimary ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: isPrimary ? Theme.of(context).colorScheme.primary : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightItem(BuildContext context, {
    required IconData icon, 
    required String label, 
    required String value, 
    String unit = '',
    bool isAccent = false,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAccent ? Theme.of(context).colorScheme.secondary.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: isAccent ? Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.3)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: isAccent ? Theme.of(context).colorScheme.secondary : Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$value $unit',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: isAccent ? Theme.of(context).colorScheme.secondary : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: value == '-' ? Colors.grey.shade400 : Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionBox(String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        description,
        style: TextStyle(
          color: description == '-' ? Colors.grey.shade400 : Colors.black87,
          fontSize: 15,
          height: 1.6,
        ),
      ),
    );
  }
}