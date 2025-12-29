import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const ProfileFormScreen({super.key, this.initialData});

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  final Map<String, dynamic> _formData = {};
  XFile? _imageFile; // เก็บไฟล์รูปที่เลือกใหม่

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _formData.addAll(widget.initialData!);
    }
  }

  // ฟังก์ชันเลือกรูปภาพ
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 70, // ลดขนาดภาพเพื่อให้อัปโหลดไว
      );
      if (pickedFile != null) {
        setState(() => _imageFile = pickedFile);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('ไม่พบผู้ใช้งาน กรุณาล็อกอินใหม่');

      // 1. ถ้ามีการเลือกรูปใหม่ ให้อัปโหลดรูปก่อน
      if (_imageFile != null) {
        final File file = File(_imageFile!.path);
        // ตั้งชื่อไฟล์เป็น UID ของ User เพื่อให้ทับไฟล์เดิมเสมอ (1 User มี 1 รูป)
        final ref = FirebaseStorage.instance
            .ref()
            .child('user_profiles')
            .child('${user.uid}.jpg');
            
        await ref.putFile(file);
        
        // ได้ URL มาแล้วเก็บไว้ใน _formData
        String photoUrl = await ref.getDownloadURL();
        _formData['photoUrl'] = photoUrl;
      }

      // 2. เตรียมข้อมูลอื่นๆ
      _formData['email'] = user.email; // อีเมลอัปเดตตาม Auth เสมอ
      _formData['lastUpdated'] = FieldValue.serverTimestamp();

      // 3. บันทึกลง Firestore (ใช้ SetOptions(merge: true) เพื่ออัปเดตเฉพาะฟิลด์ที่เปลี่ยน)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(_formData, SetOptions(merge: true));
      
      // อัปเดต Profile ใน Auth ด้วย (เพื่อให้รูปแสดงในหน้าอื่นๆ ได้ทันทีถ้าใช้ User object)
      if (_formData['displayName'] != null) {
        await user.updateDisplayName(_formData['displayName']);
      }
      if (_formData['photoUrl'] != null) {
        await user.updatePhotoURL(_formData['photoUrl']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อย'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // กลับไปหน้าแสดงผล
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
    // เตรียม ImageProvider สำหรับแสดงผล
    ImageProvider? imageProvider;
    if (_imageFile != null) {
      imageProvider = FileImage(File(_imageFile!.path)); // รูปที่เลือกใหม่จากเครื่อง
    } else if (_formData['photoUrl'] != null && _formData['photoUrl'].isNotEmpty) {
      imageProvider = NetworkImage(_formData['photoUrl']); // รูปเดิมจากเน็ต
    }

    return Scaffold(
      appBar: AppBar(title: const Text('แก้ไขข้อมูลโปรไฟล์')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ส่วนรูปโปรไฟล์
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: imageProvider,
                              child: imageProvider == null
                                  ? const Icon(Icons.person, size: 60, color: Colors.grey)
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ฟอร์มข้อมูล
                    TextFormField(
                      initialValue: _formData['displayName'],
                      decoration: InputDecoration(
                        labelText: 'ชื่อ-นามสกุล',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'กรุณาระบุชื่อ' : null,
                      onSaved: (val) => _formData['displayName'] = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _formData['phoneNumber'],
                      decoration: InputDecoration(
                        labelText: 'เบอร์โทรศัพท์',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.phone,
                      onSaved: (val) => _formData['phoneNumber'] = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _formData['address'],
                      decoration: InputDecoration(
                        labelText: 'ที่อยู่',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                      onSaved: (val) => _formData['address'] = val,
                    ),
                    
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saveProfile,
                        icon: const Icon(Icons.save),
                        label: const Text('บันทึกข้อมูล', style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}