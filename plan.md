# VibeCare 제품 구현 계획

## PWA 화면 재구성 기준 (2026-09-06)

### 현재 문제 진단

- 현재 화면은 입력, 평균, 문진, 결과가 긴 세로 문서처럼 이어져 915px 화면에서도 결과가 첫 화면 밖으로 밀린다.
- 알고리즘의 핵심인 `기본 강도 × 연령 × 성별 × 체지방` 관계가 접힌 상세영역에 있어 입력을 바꿨을 때 무엇이 달라졌는지 즉시 알기 어렵다.
- 모바일 앱으로 이식할 기준 화면이라기보다 관리용 웹 폼에 가깝다.
- 데이터 검토와 안전 확인은 필요하지만 모든 정보의 시각적 중요도가 비슷해 최종 판단이 약하다.

### 재구성 목표

첫 화면을 **실시간 진동 설정 계산기**로 만든다. 사용자는 스크롤하지 않고 다음 내용을 함께 확인해야 한다.

1. 계산에 사용되는 프로필과 최근 4건 평균
2. 기본 강도 50%와 적용된 세 가지 보정계수
3. 최종 시간·주파수·강도
4. 현재 안전 상태와 Mock/실기기 연결 상태

### 화면 구조

```text
앱 바: VibeCare / 참여자 / Mock 상태 / 글자 크기

┌ 실시간 계산 영역 ─────────────────┬ 결과 영역 ─────────┐
│ 기본 50% × 연령 × 성별 × 체지방    │ 최종 강도 38%       │
│ 나이·성별·키 입력                   │ 5분 / 20Hz           │
└───────────────────────────────────┴ 안전 상태·실행 버튼 ┘

┌ 최근 4건 평균·원본 ───────────────┬ 오늘 안전 문진 ─────┐
│ 체중 / 체지방 / 골격근 / BMI       │ 통증 / 어지럼 / 보류 │
└───────────────────────────────────┴────────────────────┘
```

모바일에서는 결과를 계산식 바로 다음에 배치하고 실행 버튼을 화면 하단에서 쉽게 찾을 수 있게 한다.

### 동작 규약

- 입력값 변경은 별도 계산 버튼 없이 즉시 결과 미리보기에 반영한다.
- 안전 문진 전에도 알고리즘 계산값은 보여주되 `실행 허가 아님`을 표시한다.
- 안전 문진 미완료, 위험 응답, 데이터 검증 실패에서는 명령 생성이 비활성화된다.
- Mock 명령은 외부 전송이나 실제 진동으로 표현하지 않는다.
- 프로필 또는 문진 변경 시 기존 Mock 명령을 폐기한다.
- 원본 데이터와 상세 보정 근거는 펼침 영역으로 제공한다.

### 디자인 벤치마크 적용

- Apple Health 차트 지침: 핵심 결론을 먼저 요약하고 데이터 상세는 점진적으로 공개한다.  
  https://developer.apple.com/design/human-interface-guidelines/charting-data
- Android Health Connect: 연결과 데이터 사용 상태를 일관되고 투명하게 표시한다.  
  https://developer.android.com/health-and-fitness/health-connect/ui/guidelines
- NHS Design System: 카드 수를 제한하고 summary list, fieldset, radios, warning 패턴을 사용한다.  
  https://service-manual.nhs.uk/design-system/components
- GOV.UK Check answers: 실행 전 입력과 결과를 한 묶음으로 재확인한다.  
  https://design-system.service.gov.uk/patterns/check-answers/
- 고령 사용자 기준: 본문 17px 이상, 48px 이상 터치영역, 색상 외 텍스트 상태, 200% 확대 대응.

### 완료 조건

- [x] 915px 첫 화면에 계산식과 최종 강도가 동시에 보인다.
- [x] 72세 여성, 체지방률 평균 18.9%는 `50 × 0.90 × 0.95 × 0.90 = 38%`로 표시된다.
- [x] 나이 또는 성별 변경 시 수식과 결과가 즉시 갱신된다.
- [x] 미응답 문진은 `확인 전`, 위험 응답은 `사용 중지`, 모두 아니요는 `사용 가능`이다.
- [x] Mock와 실기기 미연결 상태가 첫 화면에 표시된다.
- [x] 390px 모바일과 915px 데스크톱에서 가로 스크롤이 없다.
- [x] 프로덕션 빌드, 화면 소스 lint, 알고리즘 테스트 5건, 브라우저 상호작용 검증을 통과한다.
- [ ] 전체 저장소 lint의 기존 공용 UI·백엔드 오류를 별도 정리한다.

---

## Flutter 전환 실행 계획

## 구현 기준선 (2026-09-06)

- Flutter에는 Mock 로그인, 최근 유효 체성분 4건 선택, 전체 체성분 원본·평균, 표시 전용 생체신호, 안전 문진, 추천식, Mock 실행·카운트다운·즉시 중지가 연결되어 있다.
- 백엔드 API에는 PIN 인증·잠금, 토큰 검증, 최신 측정 세트, 표시 전용 생체신호, FITRUS 서버 프록시, 서버 추천 재계산, 1회성 실행 허가, Mock 세션·이벤트·중지·피드백 API가 구현되어 있다.
- `shared-contracts/openapi.yaml`을 앱과 서버 사이의 단일 공개 계약으로 사용한다.
- FITRUS 실제 정규화와 실제 진동 출력은 각각 공급사 요청·응답 예제와 진동기 통신·교정 명세를 확보하기 전까지 차단한다.
- Android 내부 시험용 release APK와 AAB까지 빌드했지만 현재 debug 키 서명이므로 배포용 signing 구성과 실제 Android 기기 검증은 남아 있다.

## 1. 목표와 성공 기준

VibeCare의 주 클라이언트를 기존 React PWA에서 Android 우선 Flutter 앱으로 전환한다. 기존 PWA는 알고리즘 결과와 UI 비교를 위한 기준 구현으로 보존한다.

성공 조건은 다음과 같다.

- Android API 24 이상에서 실행된다.
- 참여자는 발급된 참여자 코드와 6자리 PIN으로 로그인한다.
- 동일 참여자·동일 BIA 기기의 최근 유효 측정값 4건을 골라 항목별 산술평균을 계산한다.
- 연령·성별·체지방 보정과 안전 게이트를 적용하고 `READY`, `REVIEW`, `BLOCKED` 상태를 표시한다.
- 참여자 앱은 `READY` 상태와 서버 실행 허가가 있을 때만 실제 기기 명령을 보낼 수 있다.
- 실행 중 연결 상태, 남은 시간, 현재 출력과 즉시 중지 버튼을 표시한다.
- ACK 미수신, 연결 해제, 중복 명령, 앱 백그라운드 전환 시 안전하게 실행을 중지한다.

## 2. 저장소와 기술 구조

현재 저장소 안에 다음 구성을 추가한다.

```text
vibration-control-app/
├─ app/                 # Sites/Vinext 웹 비교 화면과 웹 알고리즘
├─ public/              # 웹 정적 리소스
├─ mobile-app/          # Android 우선 Flutter 앱
├─ backend-api/         # HTTP API·알고리즘·현재 D1 기반 저장 흐름
├─ shared-contracts/    # 공급사 독립 OpenAPI·JSON Schema·fixture
├─ deployment/aws/      # AWS 담당자용 환경변수·전환·검증 계약
├─ docs/                # 시스템·운영·검증 문서
├─ plan.md
└─ checklist.md
```

Flutter 앱은 Material 3, Riverpod, Dio, flutter_secure_storage를 사용한다. 도메인 알고리즘은 Flutter UI나 통신 패키지에 의존하지 않는 순수 Dart 모듈로 유지한다.

선정한 GitHub 오픈소스와 라이선스, 논문의 적용 한계, VibeCare 고유 접근은 `docs/open-source-and-evidence.md`에서 추적한다. BLE는 BSD-3-Clause인 `flutter_reactive_ble`를 우선 후보로 두되 명세 확정 전에는 의존성과 권한을 활성화하지 않는다.

기기 통신은 아래 공통 인터페이스 뒤에 둔다.

```dart
abstract interface class DeviceGateway {
  Stream<DeviceStatus> get statusStream;
  Future<void> connect(DeviceProfile profile);
  Future<DeviceAuthorization> authorize(Recommendation recommendation);
  Future<DeviceSession> start(DeviceAuthorization authorization);
  Future<void> stop(String sessionId, StopReason reason);
  Future<void> dispose();
}
```

- `MockDeviceGateway`: 개발·심사·데모용. 실제 출력 없음.
- `RestDeviceGateway`: 기기 또는 공급사 HTTPS API용.
- `BleDeviceGateway`: Android BLE GATT 제어용.
- 공급사 명세가 확정되기 전에는 Mock만 활성화한다.

## 3. 앱 화면과 사용자 흐름

참여자가 직접 사용하는 단일 세로 흐름을 유지한다.

1. 참여자 코드와 PIN 로그인
2. 사용자 나이·성별·키 확인
3. 최근 유효 BIA 4건의 모든 원본값과 항목별 평균 확인
4. 현재 통증·어지럼·사용 보류 문진
5. 추천 시간·주파수·강도와 보정계수 확인
6. `READY`일 때만 기기 연결 및 실행
7. 실행 중 남은 시간과 즉시 중지
8. 종료 후 RPE·통증·어지럼·불편감 기록

기본 화면에는 원본 4건의 전체 항목, 전체 평균, 혈압·심박·스트레스·체온, 추천 시간·Hz·강도를 세로 카드로 표시한다. 원본 한 건의 세부항목과 보정 사유는 펼침 영역에 두되 모든 값에 접근 가능해야 한다. `REVIEW`와 `BLOCKED`에는 우회 버튼을 제공하지 않는다.

## 4. 알고리즘

기준 구현은 TypeScript `pilot-0.3.0`이며 같은 버전으로 Dart에 이식한다.

```text
추천강도 = clamp(
  기본강도 50%
  × 연령계수
  × 성별계수
  × 체지방계수,
  20%, 70%
)
```

| 규칙 | 동작 | 근거 상태 |
|---|---:|---|
| 기본값 | 5분·20Hz·50% | 간접 근거 기반 연구 시작값 |
| 70세 이상 | ×0.90 | PILOT |
| 여성 | ×0.95 | PILOT |
| 남성 | ×1.00 | PILOT 기준군 |
| 여성 체지방 20~35% 밖 | ×0.90 | PILOT |
| 남성 체지방 10~28% 밖 | ×0.90 | PILOT |
| 평균 BMI 18.5 미만 | REVIEW | 안전 검토 |
| 통증·어지럼·사용 보류 | BLOCKED | 안전 게이트 |

PILOT 규칙은 앱에 고정된 임상값으로 취급하지 않는다. 서버의 `AlgorithmRuleSet`에 버전, 적용일, 활성화 여부, 변경 사유를 저장하고 앱은 승인된 규칙만 사용한다. 오프라인 캐시 규칙으로 미리보기는 가능하지만 실제 전송은 최신 규칙 검증과 서버 허가가 필요하다.

Flutter 로컬 계산은 즉각적인 화면 피드백용이다. 실제 기기 실행 전 백엔드 API가 측정 ID 4건과 안전 응답으로 평균 및 추천을 다시 계산한다. 두 결과가 다르면 실행을 거부하고 규칙을 다시 동기화한다.

### 4.1 VibeCare 단계형 접근

1. 4건의 사용자·기기·ID·필수값·품질을 검증한다.
2. 항목별 평균과 변동성(표준편차·범위)을 계산한다.
3. 급성 통증·어지럼·사용보류를 보정보다 먼저 차단한다.
4. 설명 가능한 PILOT 계수를 순서대로 적용하고 모든 중간값을 남긴다.
5. 공급사 교정표로 `%`를 진폭·가속도 한계와 대조한다.
6. 서버의 1회성 허가와 ACK 감시 아래 실행한다.
7. 사후 RPE·증상·중단 데이터를 수집해 사전 정의된 통계계획으로 계수를 재평가한다.

논문은 연구 시작 범위와 측정 원칙의 근거로 사용하고, 논문에 없는 고정 감산율을 임상 근거로 포장하지 않는다. 후속 계수 추정은 반복측정을 고려한 혼합효과 또는 베이지안 계층모형을 우선하며 안전 게이트는 모델과 분리한다.

## 5. 백엔드와 데이터 흐름

```text
BIA 공급 API
→ 백엔드 인증·스키마·중복 검사
→ 데이터 저장소에 원본 및 정규화 값 저장
→ Flutter에 동일인·동일 기기의 최근 유효 측정 4건 전달
→ Flutter 로컬 미리 계산
→ 백엔드 authoritative 재계산
→ 1회성 실행 허가 발급
→ REST 또는 BLE 기기 명령
→ ACK·상태·중지·사후반응 저장
```

핵심 테이블은 `participants`, `pin_credentials`, `bia_measurements`, `aggregation_sets`, `algorithm_rule_sets`, `recommendations`, `device_profiles`, `device_sessions`, `command_events`, `session_feedback`이다.

### 5.1 FITRUS 공급 API

공급사 기준 URL은 `https://api.thefitrus.com/fitrus-ml/measure`이며 `/bp`, `/hr`, `/stress`, `/bodytemp`, `/bodyfat`, `/stress2`를 사용한다. 모두 POST 전용이고 `x-api-key`가 필요하므로 Flutter가 직접 호출하지 않는다. 백엔드의 `FitrusClient`만 키를 비밀값으로 받아 호출하고, 응답 원본과 표준 DTO를 분리해 저장한다.

`bodyfat`은 4회 평균의 주 입력이다. 혈압·심박·체온·스트레스·스트레스2는 1차 버전에서 표시하고 저장만 하며 추천이나 차단에 사용하지 않는다. 연구책임자가 별도 임계값과 근거를 승인한 다음 규칙 버전에서만 안전 게이트 보조 입력으로 승격한다.

참여자 PIN은 원문으로 저장하지 않고 강한 단방향 해시로 저장한다. 로그인 5회 실패 시 참여자 코드와 클라이언트를 15분 잠그며, 성공 시 짧은 access token과 회전 가능한 refresh token을 발급한다. 토큰은 Flutter secure storage에 저장한다.

## 6. 공개 API

- `POST /v1/auth/pin` — 참여자 코드와 PIN 인증
- `POST /v1/auth/refresh` — access token 갱신
- `GET /v1/algorithm-rules/current` — 현재 승인된 규칙 반환
- `POST /v1/fitrus/measurements/{kind}` — 서버에서 FITRUS 측정 API 대행 및 원본 보존
- `GET /v1/participants/me/measurement-set/current` — 본인의 최신 유효 BIA 4건 반환
- `GET /v1/participants/me/vitals` — 본인의 표시 전용 생체신호 반환
- `POST /v1/recommendations/authorize` — 서버 재계산 후 1회성 실행 허가 발급
- `POST /v1/device-sessions` — 실제 또는 Mock 세션 시작
- `POST /v1/device-sessions/{id}/events` — ACK·상태·오류·중지 이벤트 기록
- `POST /v1/device-sessions/{id}/stop` — 세션 즉시 중지
- `POST /v1/session-feedback` — RPE·통증·어지럼·불편·중단 기록

모든 변경 요청은 `Idempotency-Key`, 참여자 토큰, 앱 버전, 알고리즘 버전을 포함한다. 실제 명령 허가는 짧은 만료시간, 단일 사용, 기기 ID 결합 조건을 갖는다.

## 7. 오류·안전 처리

- BIA가 4건이 아니거나 사용자·기기가 섞이면 `REVIEW`로 전환하고 실행하지 않는다.
- 원본 필수값 누락, 음수·0, 체지방량/체중 또는 BMI/키·체중 불일치는 실행하지 않는다.
- `REVIEW`, `BLOCKED`, 만료된 허가, 미검증 기기에는 실제 명령을 보내지 않는다.
- 명령 ACK가 공급사 명세의 제한시간 안에 오지 않으면 중지를 시도하고 실패 이벤트를 기록한다.
- 동일 `Idempotency-Key`는 기존 세션을 반환하며 새 출력을 시작하지 않는다.
- 앱이 백그라운드로 이동하면 기기 특성에 맞게 즉시 중지하거나 서버 감시모드로 전환한다. 공급사 명세 전에는 즉시 중지를 기본값으로 한다.

## 8. 릴리스 전략

1. Mock 기기 기반 내부 QA
2. 공급사 테스트 환경에서 BIA API 검증
3. 교정된 테스트 기기 1대로 제한된 실기기 검증
4. 내부 테스트 APK/AAB 배포
5. 소규모 참여자 파일럿
6. 로그·이상반응 검토 후 규칙 버전 승인

실제 출력 활성화 조건은 기기 API/BLE 명세, 진폭·가속도·Hz·강도 매핑, 중지 명령, ACK 정의, 타임아웃과 오류코드가 모두 제공되고 테스트를 통과하는 것이다.
