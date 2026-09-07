# 로컬 개발도구 및 빌드 검증

확인일: 2026-09-07

| 항목 | 결과 | 증거 |
|---|---|---|
| Flutter | 3.47.2 stable | `E:\flutter-sdk` |
| Dart | 3.13.2 | Flutter bundled SDK |
| Android SDK | 36.1.0, Platform 35/36, Build Tools 36 | `flutter doctor -v` |
| Android NDK | 28.2.13676358 재설치 완료 | `source.properties` 확인 및 APK 빌드 |
| Java | Android Studio JBR 21.0.8 | `flutter doctor -v` |
| Android 라이선스 | 모두 승인됨 | `flutter doctor -v` |
| Flutter 정적 분석 | 오류·경고 0 | `dart analyze` → `No issues found!` |
| Flutter 테스트 | 10/10 통과 | 알고리즘 5, 위젯 5 |
| Android debug APK | 성공 | `build/app/outputs/flutter-apk/app-debug.apk` |
| Android 에뮬레이터 | 성공 | Android 35 `VibeCare_Pixel_7_API35`, x86_64 APK 설치·실행 |
| 에뮬레이터 사용자 흐름 | 성공 | 로그인→장치 전송→진동 시작→카운트다운→중지 및 첫 화면 오버플로 없음 |
| Android release APK | 성공, 51,046,200 bytes | `build/app/outputs/flutter-apk/app-release.apk` |
| Android release AAB | 성공, 50,042,634 bytes | `build/app/outputs/bundle/release/app-release.aab` |
| APK manifest | package `com.vibecare.pilot`, minSdk 24, target/compile 36 | `aapt dump badging` |
| release APK SHA-256 | `0CBAA8D20703BEBF32F7F95C87D0A25560265D6E7F589BE7D746C92E45DD3BC0` | `Get-FileHash` |
| release AAB SHA-256 | `B60E26E07E377935A47CB57EE1F520E322F292CA8F0F204B44D521A66AAAD4FA` | `Get-FileHash` |

## 이 PC의 빌드 주의사항

- C: 드라이브 여유 공간이 없으므로 Gradle 캐시는 여유 있는 E: 경로를 사용한다.
- Windows Flutter 테스트 도구는 한글이 포함된 임시 경로에서 종료될 수 있으므로 `TEMP`와 `TMP`를 영문 경로로 지정한다.
- 프로젝트 자체의 한글 경로는 `android.overridePathCheck=true`로 허용한다.
- Android release AOT 단계는 한글 프로젝트 경로에서 실패하므로 빌드할 때만 같은 폴더를 가리키는 영문 junction을 사용했다. 소스와 산출물은 원래 프로젝트 폴더에 있다.
- `flutter_secure_storage`는 Android SDK 36 및 Windows 테스트 호스트와 호환되는 `9.2.4`로 잠갔다.
- 현재 release APK/AAB는 내부 시험을 위해 debug 키로 서명된다. 배포 전 별도 production keystore를 안전한 CI secret으로 구성해야 한다.

검증에 사용한 형태:

```powershell
$env:GRADLE_USER_HOME='E:\산학협력\.gradle-cache'
$env:TEMP='E:\codex-flutter-temp'
$env:TMP='E:\codex-flutter-temp'
E:\flutter-sdk\bin\flutter.bat test
E:\flutter-sdk\bin\flutter.bat build apk --debug
E:\flutter-sdk\bin\flutter.bat build apk --release
E:\flutter-sdk\bin\flutter.bat build appbundle --release
```
