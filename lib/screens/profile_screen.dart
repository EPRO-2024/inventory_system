import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_form_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ถ้ายังไม่ล็อกอิน ให้ไปหน้า Login
    if (user == null) {
      return const LoginScreen();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('โปรไฟล์สมาชิก', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'ออกจากระบบ',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pop(); // ปิดหน้า Profile กลับไป Home (ซึ่งจะเด้งไป Login)
              }
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          // ดึงข้อมูล
          Map<String, dynamic> data = {};
          if (snapshot.data != null && snapshot.data!.exists) {
            data = snapshot.data!.data() as Map<String, dynamic>;
          }

          // เตรียมข้อมูล
          String displayName = data['displayName'] ?? user.displayName ?? 'ไม่ระบุชื่อ';
          String email = data['email'] ?? user.email ?? '-';
          String? photoUrl = data['photoUrl'];

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 30),
                // ส่วนหัวแสดงรูปและชื่อ
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4), // ขอบสีขาว
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null 
                              ? const Icon(Icons.person, size: 60, color: Colors.grey) 
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(email, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // ส่วนข้อมูลรายละเอียด
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildInfoTile(Icons.phone, 'เบอร์โทรศัพท์', data['phoneNumber'] ?? '-'),
                      _buildInfoTile(Icons.home, 'ที่อยู่', data['address'] ?? '-'),
                      _buildInfoTile(Icons.calendar_today, 'วันที่สมัคร', _formatDate(data['createdAt'])),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // ปุ่มแก้ไข
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileFormScreen(initialData: data),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('แก้ไขข้อมูลส่วนตัว'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blueAccent,
                        elevation: 0,
                        side: const BorderSide(color: Colors.blueAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blueAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '-';
    if (timestamp is Timestamp) {
      DateTime dt = timestamp.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return '-';
  }
}