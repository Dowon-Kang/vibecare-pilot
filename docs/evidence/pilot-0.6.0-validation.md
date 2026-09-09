# pilot-0.6.0 구현·검증 기록

검증일: 2026-09-09. 대상은 연구용 Mock이며 임상 효과·실제 장치 안전성 검증이 아니다.
설계와 문헌은 [설계 심사](../algorithm/pilot-0.6.0-design-review.md). 실제 장치는 사용자 확인상 발판형 전신진동 장치이나 모델/파형/교정표는 미확인.

## 결과

| 검사 | 명령과 작업 위치 | 결과 |
|---|---|---|
| 백엔드·웹 공유 경계 비교·HTTP | backend-api: `npm test` | 49/49 통과, 5 test files |
| 백엔드 타입 | backend-api: `npm run typecheck` | exit 0 |
| 웹 기존 알고리즘 회귀 | root: `node --experimental-strip-types --test app/algorithm/vibration-algorithm.test.mjs` | 8/8 통과 |
| Flutter 단위·HTTP·위젯 | mobile-app: `flutter test --no-pub` | 45/45 통과 |
| Flutter 정적 분석 | 기존 영문 junction `E:/vibecare-pilot/mobile-app`: `flutter analyze --no-pub` | No issues found, exit 0 |
| 웹 lint | root: `npm run lint` | 최종 문구 포함 exit 0 |
| 웹 production build | root: `npm run build` | 최종 문구 포함 exit 0; vinext 라우트 정적 분류 제한 안내만 있음 |
| Android debug APK | 영문 junction: `flutter build apk --debug --no-pub` | 성공, Gradle 218.1초, 161,896,866 bytes; Java source/target8 폐기 예정 경고만 있음 |
| 변경 공백 검사 | root: `git diff --check` | exit 0; CRLF 변환 안내만 있음 |

사용 SDK: `E:/flutter-sdk` Flutter 3.47.2, Dart 3.13.2. Android 빌드는 기존 `E:/산학협력/.gradle-cache`, 영문 TEMP/TMP `E:/codex-flutter-temp` 사용. 새 SDK/패키지 설치 없음. 기존 SDK의 도구 실행·빌드 캐시 쓰기만 허용하여 진행했다.

산출물: `mobile-app/build/app/outputs/flutter-apk/app-debug.apk`. 생성 성공을 확인했으며 이번 턴에는 에뮬레이터 설치·실행이나 실기기 연결을 하지 않았다. Debug APK 크기는 release 성능/크기 최적화 수치가 아니다.

APK SHA-256: `9F8ADFB5F41FE4AFA7A333E31D5A4EB5D89294E629003F187C35B8F581243B0F`.
공통 JSON 7파일 문법 검사, OpenAPI 3.1 YAML 파싱·응답 객체 형태 검사도 통과했다. 이는 OpenAPI 전체 적합성 검사나 JSON Schema 전수 conformance 검사를 대신하지 않는다. 설치된 PyYAML6.0.2로 검사했으며 추가 패키지를 설치하지 않았다.

## 검증이 증명하는 범위

- 공통 `shared-contracts/fixtures/pilot-0.6.0-boundaries.json` 20사례: 여성 5.75/6.75, 남성 8.50/10.75 바로 아래·같음·위, 반복값 등급 불안정, BMI18.5 경계, 69/70세, 60세 미만, 3건, 어지럼.
- backend `test/research.test.ts`: 웹과 서버의 수치·등급·상태·SD/CV/min/max·reasonCodes 비교. 두 구현이 순수 계산 모듈을 공유하므로 독립 임상 검증 아님.
- mobile `test/research_test.dart`: 동일 fixture의 등급·시간·Hz·%·실행 상태 기대값 검증. 모든 실수 입력에 대한 수학적 동일성 증명은 아님.
- backend `test/routes.test.ts`: real mode 허가 미발급, 이전 허가 후 불편 보고가 생기면 재사용 거절, 세션 멱등·피드백 충돌·규칙 변경 검증.
- mobile `test/authenticated_client_test.dart`: 앱/서버 버전·수치·mode 불일치 거절, 누락 규칙 거절, 네트워크 오류·receiveTimeout 주입·ACK 없는 응답에서 RUNNING 미표시, 같은 재시도 키 유지. **실제 RF/장치 ACK 지연을 측정한 테스트가 아니다.**
- mobile 위젯: 전송→시작→중지→피드백, 중지 실패 시 재시도 유지, 위험 문진 차단, 원본/수식 상세, 폭320/390 및 글자배율2.0.
- 교정 검사: 합성 정현파의 변위→peak/RMS, 상한·유효기간·부하·일치점·중복점 거절. 이것은 벤치 계약 검사이며 실제 교정/승인/장치 작동 아님.

## 바뀐 동작

1. v0.5의 표시용 반올림 때문에 경계를 넘는 결함을 수정. BMI 안전 비교도 원시 평균을 사용.
2. 70세 계수0.9 제거. 기존 fixture 여성45→50%, 남성27→30%; 해당 fixture는 저BMI REVIEW로 여전히 실행 불가.
3. 4건 미만은 평균/추천 없음. 등급 불안정은 REVIEW. READY는 시뮬레이터에만 적용.
4. 실제 모드는 실행 허가 발급 이전에 CALIBRATION_REQUIRED로 차단. 실장치 전송 허용은 항상false.
5. 강도 강함/RPE≥7은 상한10% 감산. 시간·주파수 강함/증상/중도중단은 보류. 약함은 자동 상승 없음.
6. 실제 시간·peak/RMS 입력 칸은 nullable 기록 계약이며 앱에서 추정값을 실측으로 채우지 않음. 현재 서버 출처는 participant_report로 기록.
7. 서버 규칙 fallback 제거, Mock 동시 시작·소모 허가 재사용 방지.

## 변경 파일 지도

| 책임 | 주요 파일 |
|---|---|
| 수학/버전 규격 | shared-contracts/muscle-research.ts; algorithm-rule-set.schema.json; research-execution.schema.json; fixtures/pilot-0.6.0*.json |
| 서버 권위/피드백 | backend-api/src/algorithm.ts; rule-schema.ts; feedback.ts; index.ts |
| 교정 계약 | backend-api/src/calibration.ts; shared-contracts/device-calibration.schema.json |
| DB 인수 | backend-api/migrations/0007_research_safety.sql |
| Flutter | mobile-app/lib/algorithm/vibration_algorithm.dart; models; services/fitrus_repository.dart; backend_device_gateway.dart; mock_device_gateway.dart; feedback_repository.dart; controllers/pilot_controller.dart |
| 근거 표시 | app/page.tsx; app/algorithm/vibration-algorithm.ts; mobile-app/lib/screens/overview_card.dart; pilot_screen.dart |
| 검사 | backend-api/test/research.test.ts; routes.test.ts; mobile-app/test/research_test.dart; authenticated_client_test.dart; widget_test.dart |

## 해결한 검증 실패

- 샌드박스의 esbuild spawn EPERM: 승인된 로컬 프로세스 실행으로 재검증 통과.
- 한글 경로 Flutter LSP 초기화 JSON 잘림: 기존 영문 junction으로 같은 소스 분석, 0문제 확인. 프로젝트 이동/삭제 없음.
- 상세 패널 설명 추가로 장치 정보가 ListView 화면 밖에 있음: 위젯 테스트가 상세 스크롤 후 실제 항목을 검증하도록 변경.
- 타입 검사 import .ts 정책/폐기된 z.number().finite 경고: noEmit 설정에 allowImportingTsExtensions, Zod4 기본 유한수 검사 사용. 오류를 무시하지 않고 lint 재검증.

## 미검증·미실행

FITRUS 운영 호출/정규화, 실제 사용자의 4건 측정, 실기기 진폭·가속도·전달률, 실제 네트워크 장애에서 물리 정지, 장치 watchdog, 재시작 후 활성 세션 복구, TalkBack 실기기, 임상 안전·효과, AWS 배포는 이번 결과에 포함하지 않는다. ACK 실패 시 앱이 오류를 표시하는 것과 장치가 물리적으로 정지하는 것은 다르다.

운영 DB migration 적용/배포/commit/push/실제 키 출력은 하지 않았다. 이전 변경을 보존했고 기존 v0.5 소스와 fixture는 이력으로 남겼다. Sites 스킬은 기존 웹 표면의 구조·의존성 보존과 로컬 build 검증에만 사용했으며 연구 작업을 외부 배포로 확대하지 않았다.
