import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  final Stream<User?>? authStateChanges;

  const InventoryApp({super.key, this.authStateChanges});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          secondary: const Color(0xFF10B981),
          surface: const Color(0xFFF8FAFC),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.kanitTextTheme(),
        // ... (Theme อื่นๆ เหมือนเดิม)
      ),
      
      // [จุดสำคัญ] ตรวจสอบสถานะล็อกอินที่นี่
      home: StreamBuilder<User?>(
        stream: authStateChanges ?? FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. ระหว่างรอตรวจสอบสถานะ (เช่น กำลังโหลด)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          // 2. ถ้ามีข้อมูล User (ล็อกอินอยู่) -> ไปหน้า Home
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          
          // 3. ถ้าไม่มี (ยังไม่ล็อกอิน) -> ไปหน้า Login
          return const LoginScreen();
        },
      ),
    );
  }
}