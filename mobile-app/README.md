# VibeCare Flutter Pilot

Android 우선 참여자 앱이다. 현재 구현은 Mock PIN 로그인, 최근 유효 BIA 4건 선택, 체성분 전체 원본·평균, 표시 전용 생체신호, ASM/SMM 근육지수 해석, 안전 문진, Mock 기기 세션·카운트다운·즉시 중지를 포함한다.

`pilot-0.6.0`은 근육지수 등급에 따라 연구용 Mock preset을 선택한다. 연령·성별·체지방을 강도에 곱하는 보정은 사용하지 않으며 관련 계수는 모두 `1.0`이다. 성별은 근육지수 경계 선택에만 사용하고, 나이는 코호트 범위 확인, 체지방은 데이터 일관성 검사와 향후 분석에 사용한다.

앱의 실행 모드는 현재 `DeviceExecutionMode.simulator`만 제공한다. 실제 REST/BLE 출력은 공급사의 명령·ACK·중지 명세와 물리 출력 교정표가 검증될 때까지 앱에 실제 장치 어댑터를 등록하지 않고, 서버에서도 실제 장치 허가를 차단한다.

## 실행

```powershell
flutter pub get
flutter test
flutter run
flutter run --dart-define=VIBECARE_API_BASE_URL=https://api.example.invalid
```

API base URL을 생략하면 Mock repository와 데모 계정 `USER-001 / 123456`을 사용한다. URL을 지정하면 PIN, 규칙, 측정세트, 생체신호는 백엔드 API를 사용하고 FITRUS 키는 앱에 포함하지 않는다.

현재 Android 설정:

- package ID: `com.vibecare.pilot`
- minSdk: 24
- target/compile SDK: 36
- Java: 17 bytecode, Android Studio JBR 21

개발자별 SDK 위치나 임시경로는 저장소 문서에 고정하지 않는다. 로컬 도구체인은 Flutter·Android SDK 안내에 따라 환경변수로 구성한다.

## 검증 기준

- 기준 커밋 `13a16c0`
- [GitHub Actions run 34443151436](https://github.com/Dowon-Kang/vibecare-pilot/actions/runs/34443151436)
- Flutter format·analyze·전체 테스트·debug APK 빌드 통과

이는 Mock 앱의 코드 품질 검증이며 FITRUS 실응답, 물리 진동기 또는 임상 안전성 검증이 아니다.
