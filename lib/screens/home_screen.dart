import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'inventory_list_screen.dart';
import 'receive_goods_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('ระบบจัดการคลังสินค้า', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        // ส่วนปุ่มโปรไฟล์มุมขวาบน
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              borderRadius: BorderRadius.circular(50),
              child: StreamBuilder<User?>(
                // ตรวจสอบการเปลี่ยนแปลงของ User (เช่น การล็อกอิน หรือ อัปเดตข้อมูล)
                stream: FirebaseAuth.instance.userChanges(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final user = snapshot.data!;
                    return CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      radius: 20,
                      // [แก้ไข] ถ้ามี photoURL ให้แสดงรูป, ถ้าไม่มีให้แสดงไอคอน
                      backgroundImage: user.photoURL != null 
                          ? NetworkImage(user.photoURL!) 
                          : null,
                      child: user.photoURL == null 
                          ? const Icon(Icons.person, color: Colors.white, size: 24)
                          : null,
                    );
                  }
                  
                  // สถานะยังไม่ล็อกอิน
                  return CircleAvatar(
                    backgroundColor: Colors.grey.shade300,
                    radius: 20,
                    child: const Icon(Icons.person, color: Colors.white, size: 24),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMenuButton(
                  context,
                  title: 'รับเข้าสินค้า',
                  subtitle: 'บันทึกรับเข้า หรือ ดึงจาก PO',
                  icon: Icons.input_rounded, 
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ReceiveGoodsScreen()),
                    );
                  },
                ),
                
                const SizedBox(height: 20),

                _buildMenuButton(
                  context,
                  title: 'ดูรายการสินค้าคงคลัง',
                  subtitle: 'ตารางแสดงชื่อ รุ่น จำนวน และที่เก็บ',
                  icon: Icons.table_chart_rounded,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const InventoryListScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 16),
          ],
        ),
      ),
    );
  }
}