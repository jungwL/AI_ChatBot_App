import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart'; // Android 특정 옵션
import 'package:local_auth_ios/local_auth_ios.dart';       // iOS 특정 옵션

class LocalAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  // 생체 인증을 시도하는 기본 함수
  Future<bool> authenticate() async {
    try {
      // 1. 기기가 생체 인증을 지원하는지 확인
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        print("기기에서 생체 인증을 지원하지 않습니다.");
        // 지원 안 해도 (개발/테스트 중) 통과시키려면 true 반환
        // return true;
        return false;
      }

      // 2. 인증 시도
      return await _auth.authenticate(
        localizedReason: '챗봇 서비스에 접근하려면 인증이 필요합니다.',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: '생체 인증 필요',
            cancelButton: '취소',
          ),
          IOSAuthMessages(
            cancelButton: '취소',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true, // 앱이 백그라운드로 가도 인증 유지
          biometricOnly: false, // 생체 인증 외에 기기 암호(패턴,PIN)도 허용
        ),
      );
    } on PlatformException catch (e) {
      print("생체 인증 오류: $e");
      return false;
    }
  }
}