# VibeCare Flutter Pilot

Android 우선 참여자 앱이다. 현재 구현은 Mock PIN 로그인, 최근 유효 BIA 4건 선택, 체성분 전체 원본·평균, 표시 전용 생체신호, 연령·성별·체지방 PILOT 보정, 안전 문진, Mock 기기 세션·카운트다운·즉시 중지를 포함한다.

실제 REST/BLE 출력은 공급사의 명령·ACK·중지 명세와 물리 출력 교정표가 검증될 때까지 컴파일 타임 플래그와 서버 허가 양쪽에서 비활성화한다.

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

이 PC에서는 C: 공간 부족과 Windows 한글 임시경로 문제를 피하기 위해 `docs/evidence/toolchain-status.md`의 환경변수로 빌드한다.
