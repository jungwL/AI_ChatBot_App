import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:aitest/screens/login_screen.dart'; // 로그인 화면 import

void main() async {
  // .env 파일 로드를 보장
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const GenerativeAiApp());
}

class GenerativeAiApp extends StatelessWidget {
  const GenerativeAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '국립중앙박물관 챗봇',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // 앱의 첫 화면을 LoginScreen으로 설정
      home: const LoginScreen(),
    );
  }
}