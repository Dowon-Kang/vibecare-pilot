# 실제 진동기 연동 준비도

## 현재 결론

현재 저장소는 로컬 Mock과 서버 시뮬레이터만 실행한다. 물리 진동기에 명령을 보내거나 물리 ACK를 확인하는 코드는 없다. 따라서 현재 화면의 `RUNNING`은 **시뮬레이터 실행 상태**이며 실제 진동 발생의 증거가 아니다.

## 명세 없이 구현·검증한 안전 경계

- `DeviceGateway` 공통 수명주기: 연결 → 허가 → 시작/ACK → 실행 → 중지 확인 → 완료
- 허용되지 않은 상태 전이를 거부하는 공통 상태머신
- 일회성 실행 허가, 만료 시각, 대상 기기 일치 검사
- Idempotency-Key를 이용한 서버 세션 중복 방지
- ACK와 중지 확인 타임아웃
- ACK 없는 실행을 성공으로 표시하지 않음
- 활성 세션이 없는 잘못된 중지 요청 거부
- 실행 중 연결 해제 거부
- 백그라운드 이동 시 실행 세션 중지 요청 또는 미사용 허가 폐기·연결 해제

코드와 계약 근거:

- 앱 인터페이스·명령 모델: `mobile-app/lib/services/device_gateway.dart`
- 공통 상태 전이: `mobile-app/lib/services/device_state_machine.dart`
- 로컬 Mock: `mobile-app/lib/services/mock_device_gateway.dart`
- 서버 시뮬레이터 연결: `mobile-app/lib/services/backend_device_gateway.dart`
- 명령·이벤트 계약: `shared-contracts/device-command.schema.json`, `shared-contracts/device-event.schema.json`
- 서버 세션 라우트·저장: `backend-api/src/routes/session-routes.ts`, `backend-api/src/session-store.ts`
- 회귀 테스트: `mobile-app/test/device_gateway_state_test.dart`, `mobile-app/test/authenticated_client_test.dart`, `backend-api/test/routes.test.ts`

## 실제 어댑터 구현 전 필수 외부 입력

1. 통신 방식과 프레이밍: BLE GATT UUID/특성/MTU 또는 REST URL·인증·본문
2. 장치 식별·페어링·재연결 규칙
3. 시간·주파수·강도 값의 장치 단위, 범위, 분해능과 PWM/가속도 교정표
4. START·STOP 명령과 ACK/NACK payload, 오류 코드, 최대 응답 시간
5. 연결 유실 시 장치 자체 fail-safe와 watchdog 동작
6. 긴급정지의 물리 버튼 및 소프트웨어 우선순위
7. 펌웨어 버전 호환표와 테스트 전용 장비
8. 위험 분석, 시험 승인, 허용 출력 상한

## 실제 연결 완료 판정 기준

- 캡처된 실제 통신 trace로 명령 직렬화와 ACK 파싱을 재현한다.
- 잘못된 범위·만료 허가·중복 시작이 장치에 전달되지 않는다.
- ACK 타임아웃, 연결 유실, 앱 백그라운드, 중지 ACK 유실을 실기기에서 시험한다.
- 앱의 `RUNNING/COMPLETED`가 장치가 증명한 event와 일치한다.
- 시험 결과에 장치·펌웨어·앱·알고리즘 버전과 시각을 남긴다.

이 조건을 충족하기 전에는 `device-adapter` source 또는 실제 기기 실행 완료를 표시하지 않는다.
