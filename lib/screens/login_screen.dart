import 'package:flutter/material.dart';
import 'chat.screen.dart'; // 챗 스크린 import
import 'package:aitest/services/local_auth_service.dart'; // 인증 서비스 import
import 'package:local_auth/local_auth.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LocalAuthService _authService = LocalAuthService();
  bool _isLoading = false;

  void _authenticateAndNavigate() async {
    setState(() {
      _isLoading = true;
    });

    final bool didAuthenticate = await _authService.authenticate();

    if (!mounted) return; // 비동기 작업 후 위젯이 사라졌는지 확인

    setState(() {
      _isLoading = false;
    });

    if (didAuthenticate) {
      // 인증 성공 시 ChatScreen으로 이동 (뒤로 가기 불가)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChatScreen()),
      );
    } else {
      // 인증 실패 시 스낵바 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인증에 실패했습니다. 다시 시도해주세요.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // 배경 이미지
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/national_museum.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.darken,
            ),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '국립중앙박물관 챗봇',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 40),
              if (_isLoading)
                CircularProgressIndicator(color: Colors.white,)
              else
                ElevatedButton.icon(
                  icon: Icon(Icons.fingerprint),
                  label: Text('생체 인증으로 로그인'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: TextStyle(fontSize: 18),
                  ),
                  onPressed: _authenticateAndNavigate,
                ),
            ],
          ),
        ),
      ),
    );
  }
}