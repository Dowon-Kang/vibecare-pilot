# 개발도구 검증 기록

확인일: 2026-09-07

> 아래 표는 2026-09-07에 한 개발 환경에서 얻은 **과거 이력**이다. 현재 커밋의 판정과 혼합하지 않는다. 현재 상태는 `.github/workflows/ci.yml`이 실행한 GitHub Actions 결과를 우선하며, APK/AAB 파일과 호스트별 SDK 경로는 저장소 계약이 아니다.

## 현재 커밋의 판정 기준

CI는 저장소에 고정된 Flutter 버전으로 포맷, 정적 분석, 테스트, debug APK 빌드를 순서대로 수행한다. 문서의 과거 성공 횟수보다 해당 커밋의 GitHub Actions 결과가 최신 증거다.

- 워크플로 정의: `.github/workflows/ci.yml`
- Flutter 계약: `mobile-app/pubspec.yaml`, `mobile-app/pubspec.lock`
- 백엔드 계약: `backend-api/package.json`, `backend-api/package-lock.json`
- 실패 시 완료로 표시하지 않으며, 성공한 실행의 커밋 SHA와 로그를 함께 확인한다.

## 2026-09-07 로컬 이력

| 항목 | 결과 | 증거 |
|---|---|---|
| Flutter | 3.47.2 stable | 로컬 SDK의 `flutter --version` |
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

## 당시 Windows 환경의 빌드 주의사항

- 시스템 드라이브 여유 공간이 부족한 환경에서는 Gradle 캐시를 여유 있는 보조 드라이브로 지정한다.
- Windows Flutter 테스트 도구가 비 ASCII 임시 경로에서 종료되는 환경에서는 `TEMP`와 `TMP`를 영문 전용 임시 경로로 지정한다.
- 프로젝트 자체의 한글 경로는 `android.overridePathCheck=true`로 허용한다.
- Android release AOT 단계는 한글 프로젝트 경로에서 실패하므로 빌드할 때만 같은 폴더를 가리키는 영문 junction을 사용했다. 소스와 산출물은 원래 프로젝트 폴더에 있다.
- `flutter_secure_storage`는 Android SDK 36 및 Windows 테스트 호스트와 호환되는 `9.2.4`로 잠갔다.
- 현재 release APK/AAB는 내부 시험을 위해 debug 키로 서명된다. 배포 전 별도 production keystore를 안전한 CI secret으로 구성해야 한다.

동일한 제약이 있는 Windows 호스트에서 사용할 수 있는 일반화된 형태:

```powershell
$env:GRADLE_USER_HOME='<writable-ascii-cache-path>'
$env:TEMP='<writable-ascii-temp-path>'
$env:TMP='<writable-ascii-temp-path>'
flutter test
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
```
