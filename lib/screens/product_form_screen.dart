import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData; // รับข้อมูลเริ่มต้นกรณี Import หรือ Edit

  const ProductFormScreen({super.key, this.initialData});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // เก็บข้อมูลตัวเลือกสำหรับ Autocomplete ของแต่ละฟิลด์
  final Map<String, List<String>> _autocompleteOptions = {};

  final Map<String, dynamic> _formData = {};

  // --- ส่วนจัดการรูปภาพ ---
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _newImages = []; 
  List<String> _existingImageUrls = []; 
  
  // --- ตัวแปรสำหรับการคำนวณน้ำหนักรวมแบบ Real-time ---
  double _weightPerUnit = 0.0;
  double _initialStock = 0.0;
  double _stockQty = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchAllExistingData();

    if (widget.initialData != null) {
      _formData.addAll(widget.initialData!);
      
      if (_formData['expiryDate'] is Timestamp) {
        _formData['expiryDate'] = (_formData['expiryDate'] as Timestamp).toDate();
      }
      if (_formData['createDate'] is Timestamp) {
        _formData['createDate'] = (_formData['createDate'] as Timestamp).toDate();
      }
      
      // โหลดรูปภาพเดิม
      var rawImages = widget.initialData!['images'];
      if (rawImages != null && rawImages is List) {
        _existingImageUrls = rawImages.map((e) => e.toString()).toList();
      } else {
        _existingImageUrls = [];
      }

      // โหลดค่าตัวเลขเพื่อใช้คำนวณ
      _weightPerUnit = _parseNumber(_formData['weight']);
      _initialStock = _parseNumber(_formData['initialStock']);
      _stockQty = _parseNumber(_formData['stockQty']);

    } else {
      _formData['status'] = 'มีสินค้า';
      _formData['createDate'] = DateTime.now();
      _formData['productId'] = const Uuid().v4().substring(0, 8).toUpperCase();
    }
  }

  // Helper แปลงค่าเป็น double
  double _parseNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _fetchAllExistingData() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('products').get();
      
      final targetFields = [
        'name', 'productId', 'alias', 'category', 'brand', 'model', 
        'description', 'keywords', 'location', 'unit', 'batchNumber',
        'color', 'material', 'size', 'sellingPoints', 'targetAudience', 'complianceNumber'
      ];

      final Map<String, Set<String>> tempOptions = {
        for (var field in targetFields) field: {}
      };

      for (var doc in snapshot.docs) {
        final data = doc.data();
        for (var field in targetFields) {
          if (data[field] != null && data[field].toString().isNotEmpty) {
            tempOptions[field]!.add(data[field].toString());
          }
        }
      }

      if (mounted) {
        setState(() {
          tempOptions.forEach((key, value) {
            _autocompleteOptions[key] = value.toList();
          });
        });
      }
    } catch (e) {
      debugPrint('Error fetching existing data: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(imageQuality: 70);

      if (pickedFiles.isNotEmpty) {
        setState(() {
          int currentTotal = _existingImageUrls.length + _newImages.length;
          int remainingSlots = 10 - currentTotal;
          
          if (remainingSlots > 0) {
             if (pickedFiles.length > remainingSlots) {
                _newImages.addAll(pickedFiles.take(remainingSlots));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('เลือกเพิ่มได้สูงสุดไม่เกิน 10 รูป')),
                );
             } else {
                _newImages.addAll(pickedFiles);
             }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ครบ 10 รูปแล้ว ไม่สามารถเพิ่มได้อีก')),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  Future<List<String>> _uploadImages(String productId) async {
    List<String> uploadedUrls = [];

    for (var xFile in _newImages) {
      try {
        final File file = File(xFile.path);
        if (!file.existsSync()) continue;

        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${xFile.name}';
        final Reference ref = FirebaseStorage.instance
            .ref()
            .child('products')
            .child(productId)
            .child(fileName);

        final UploadTask uploadTask = ref.putFile(file);
        final TaskSnapshot snapshot = await uploadTask;
        
        if (snapshot.state == TaskState.success) {
           final String url = await snapshot.ref.getDownloadURL();
           uploadedUrls.add(url);
        }
      } catch (e) {
        debugPrint('Error uploading image ${xFile.name}: $e');
      }
    }
    return uploadedUrls;
  }
  
  void _showImagePopup(dynamic imageSource, {bool isNetwork = false}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isNetwork 
                  ? Image.network(imageSource as String, fit: BoxFit.contain)
                  : Image.file(File((imageSource as XFile).path), fit: BoxFit.contain),
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

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      _formData['lastModified'] = DateTime.now();
      _formData['modifiedBy'] = 'Admin';

      // --- Logic: คำนวณน้ำหนักรวมก่อนบันทึก ---
      // คำนวณอีกครั้งเพื่อความชัวร์ (เผื่อค่าใน _formData อัปเดตล่าสุด)
      double weight = _parseNumber(_formData['weight']);
      double initStock = _parseNumber(_formData['initialStock']);
      double stock = _parseNumber(_formData['stockQty']);

      _formData['totalInitialWeight'] = weight * initStock;
      _formData['totalCurrentWeight'] = weight * stock;
      // ----------------------------------------

      if (stock <= 0) {
        _formData['outOfStockDate'] = DateTime.now();
        _formData['status'] = 'สินค้าหมด';
      } else {
        _formData['outOfStockDate'] = null;
        if (_formData['status'] == 'สินค้าหมด') {
          _formData['status'] = 'มีสินค้า';
        }
      }
      
      String productId = _formData['productId'] ?? 'unknown';
      
      List<String> newUploadedUrls = await _uploadImages(productId);
      
      List<String> finalImageUrls = [];
      if (_existingImageUrls.isNotEmpty) finalImageUrls.addAll(_existingImageUrls);
      if (newUploadedUrls.isNotEmpty) finalImageUrls.addAll(newUploadedUrls);
      
      _formData['images'] = finalImageUrls;
      
      if (_formData.containsKey('docId')) {
        String docId = _formData['docId'];
        Map<String, dynamic> updateData = Map.from(_formData);
        updateData.remove('docId'); 
        await FirebaseFirestore.instance.collection('products').doc(docId).update(updateData);
      } else {
        await FirebaseFirestore.instance.collection('products').add(_formData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกข้อมูลสำเร็จ'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // คำนวณค่าเพื่อแสดงผล
    double totalInitWeight = _initialStock * _weightPerUnit;
    double totalCurrWeight = _stockQty * _weightPerUnit;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialData != null ? 'แก้ไขข้อมูลสินค้า' : 'บันทึกข้อมูลสินค้า'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded),
            onPressed: _saveProduct,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle('1. ข้อมูลพื้นฐาน (Basic Info)', Icons.info),
                  _buildCard([
                    _buildAutocompleteTextField('รหัสสินค้า (SKU)', 'productId', required: true),
                    _buildImageUploadSection(),
                    const SizedBox(height: 20),
                    _buildAutocompleteTextField('ชื่อสินค้า', 'name', required: true),
                    _buildRowFields([
                      _buildAutocompleteTextField('ชื่อย่อ/ชื่ออื่น', 'alias'),
                      _buildAutocompleteTextField('หมวดหมู่', 'category'),
                    ]),
                    _buildRowFields([
                      _buildAutocompleteTextField('แบรนด์', 'brand'),
                      _buildAutocompleteTextField('รุ่น (Model)', 'model'),
                    ]),
                    _buildAutocompleteTextField('คำอธิบายสินค้า', 'description', maxLines: 3),
                    _buildAutocompleteTextField('Keywords', 'keywords'),
                  ]),

                  _buildSectionTitle('2. ราคาและการขาย (Pricing)', Icons.attach_money),
                  _buildCard([
                    _buildRowFields([
                      _buildTextField('ราคาทุน', 'costPrice', isNumber: true),
                      _buildTextField('ราคาขายปลีก', 'retailPrice', isNumber: true),
                    ]),
                    _buildRowFields([
                      _buildTextField('ราคาขายส่ง', 'wholesalePrice', isNumber: true),
                      _buildTextField('ภาษี (%)', 'vatRate', isNumber: true),
                    ]),
                  ]),

                  _buildSectionTitle('3. สต็อก (Inventory)', Icons.inventory_2),
                  _buildCard([
                    _buildRowFields([
                      _buildTextField(
                        'จำนวนสินค้าแรกเข้า', 
                        'initialStock', 
                        isNumber: true,
                        onChanged: (val) {
                          setState(() {
                            _initialStock = _parseNumber(val);
                          });
                        }
                      ),
                      _buildTextField(
                        'จำนวนคงเหลือ', 
                        'stockQty', 
                        isNumber: true,
                        onChanged: (val) {
                          setState(() {
                            _stockQty = _parseNumber(val);
                          });
                        }
                      ),
                    ]),
                    // --- ส่วนแสดงผลน้ำหนักรวม (คำนวณอัตโนมัติ) ---
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('น้ำหนักสินค้ารวม (แรกเข้า):', style: TextStyle(color: Colors.blue.shade900)),
                              Text('${NumberFormat('#,##0.##').format(totalInitWeight)} กก.', 
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('น้ำหนักสินค้าคงเหลือรวม:', style: TextStyle(color: Colors.green.shade900)),
                              Text('${NumberFormat('#,##0.##').format(totalCurrWeight)} กก.', 
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // -------------------------------------------
                    _buildRowFields([
                      _buildTextField('จุดสั่งซื้อขั้นต่ำ', 'reorderPoint', isNumber: true),
                      _buildDropdown('สถานะสินค้า', 'status', ['มีสินค้า', 'สินค้าหมด', 'เลิกผลิต']),
                    ]),
                    _buildRowFields([
                      _buildAutocompleteTextField('ตำแหน่งจัดเก็บ', 'location'),
                      _buildAutocompleteTextField('หน่วยนับ', 'unit'),
                    ]),
                    _buildRowFields([
                      _buildAutocompleteTextField('Batch / Lot', 'batchNumber'),
                      _buildDatePicker('วันหมดอายุ', 'expiryDate'),
                    ]),
                  ]),

                  _buildSectionTitle('4. กายภาพ (Physical)', Icons.straighten),
                  _buildCard([
                    _buildRowFields([
                      _buildTextField(
                        'น้ำหนักต่อชิ้น (กก.)', 
                        'weight', 
                        isNumber: true,
                        onChanged: (val) {
                          setState(() {
                            _weightPerUnit = _parseNumber(val);
                          });
                        }
                      ),
                      _buildTextField('ขนาด (กxยxส)', 'dimensions'),
                    ]),
                    _buildRowFields([
                      _buildAutocompleteTextField('สี', 'color'),
                      _buildAutocompleteTextField('วัสดุ', 'material'),
                    ]),
                    _buildAutocompleteTextField('ขนาดไซซ์ (S/M/L)', 'size'),
                  ]),
                  
                  _buildSectionTitle('5. การตลาด & 6. มาตรฐาน', Icons.campaign),
                  _buildCard([
                     _buildAutocompleteTextField('จุดเด่นสินค้า', 'sellingPoints'),
                     _buildAutocompleteTextField('กลุ่มเป้าหมาย', 'targetAudience'),
                     _buildAutocompleteTextField('เลข อย./มอก.', 'complianceNumber'),
                  ]),

                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _saveProduct,
                    icon: const Icon(Icons.check_circle),
                    label: Text(widget.initialData != null ? 'อัปเดตข้อมูล' : 'บันทึกข้อมูลสินค้า', style: const TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // --- Widgets ---

  Widget _buildImageUploadSection() {
    int currentCount = _existingImageUrls.length + _newImages.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('รูปภาพสินค้า ($currentCount/10)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            if (currentCount < 10)
              TextButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('เพิ่มรูป'),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary),
              ),
          ],
        ),
        
        Container(
          height: currentCount > 0 ? 200 : 100,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: currentCount == 0 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('ยังไม่มีรูปภาพ', style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  ..._existingImageUrls.asMap().entries.map((entry) {
                    int idx = entry.key;
                    String url = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(url, width: 50, height: 50, fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                        title: Text('รูปภาพเดิม ${idx + 1}', style: const TextStyle(fontSize: 14)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _existingImageUrls.removeAt(idx);
                            });
                          },
                        ),
                        onTap: () => _showImagePopup(url, isNetwork: true),
                      ),
                    );
                  }),
                  
                  ..._newImages.asMap().entries.map((entry) {
                    int idx = entry.key;
                    XFile file = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(File(file.path), width: 50, height: 50, fit: BoxFit.cover),
                        ),
                        title: Text(file.name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                        subtitle: Text('${(File(file.path).lengthSync() / 1024).toStringAsFixed(1)} KB'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _newImages.removeAt(idx);
                            });
                          },
                        ),
                        onTap: () => _showImagePopup(file, isNetwork: false),
                      ),
                    );
                  }),
                ],
              ),
        ),
      ],
    );
  }

  Widget _buildAutocompleteTextField(String label, String key, {bool required = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') {
                return const Iterable<String>.empty();
              }
              final options = _autocompleteOptions[key] ?? [];
              return options.where((String option) {
                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) {
              _formData[key] = selection;
            },
            fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
              if (textEditingController.text.isEmpty && _formData[key] != null && _formData[key].toString().isNotEmpty) {
                textEditingController.text = _formData[key].toString();
              }

              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                maxLines: maxLines,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: 'พิมพ์เพื่อเลือกหรือใส่ข้อมูลใหม่',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  isDense: true,
                  suffixIcon: (_autocompleteOptions[key]?.isNotEmpty ?? false) 
                      ? const Icon(Icons.arrow_drop_down, color: Colors.grey)
                      : null,
                ),
                validator: required ? (val) => val == null || val.isEmpty ? 'กรุณาระบุข้อมูล' : null : null,
                onSaved: (val) {
                  _formData[key] = val;
                },
                onChanged: (val) {
                  _formData[key] = val;
                },
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4.0,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: constraints.maxWidth,
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String option = options.elementAt(index);
                        return InkWell(
                          onTap: () {
                            onSelected(option);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                            child: Text(option),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        }
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10, left: 4),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildRowFields(List<Widget> children) {
    return Row(
      children: children.asMap().entries.map((entry) {
        int idx = entry.key;
        Widget widget = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: idx == 0 ? 0 : 8.0),
            child: widget,
          ),
        );
      }).toList(),
    );
  }

  // [ปรับปรุง] เพิ่ม onChanged เพื่อรองรับการคำนวณสด
  Widget _buildTextField(String label, String key, {bool required = false, bool isNumber = false, int maxLines = 1, Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: _formData[key]?.toString(),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: required ? 'จำเป็นต้องระบุ' : null,
          isDense: true,
        ),
        validator: required ? (val) => val == null || val.isEmpty ? 'กรุณาระบุข้อมูล' : null : null,
        // เรียกใช้ฟังก์ชัน onChanged ถ้ามีส่งมา (สำหรับคำนวณ)
        onChanged: (val) {
          if (onChanged != null) onChanged(val);
        },
        onSaved: (val) {
          if (val != null) {
            _formData[key] = isNumber ? (double.tryParse(val) ?? 0) : val;
          }
        },
      ),
    );
  }

  Widget _buildDropdown(String label, String key, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: _formData[key],
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: (val) => setState(() => _formData[key] = val),
        decoration: InputDecoration(labelText: label),
        onSaved: (val) => _formData[key] = val,
      ),
    );
  }

  Widget _buildDatePicker(String label, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          DateTime? date = await showDatePicker(
            context: context,
            initialDate: _formData[key] ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (date != null) {
            setState(() => _formData[key] = date);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Text(
            _formData[key] != null 
                ? DateFormat('dd/MM/yyyy').format(_formData[key]) 
                : 'เลือกวันที่',
          ),
        ),
      ),
    );
  }
}