# 파일·모듈별 책임

아래는 [사실]인 실제 책임과 [추론]인 유지보수 위험을 함께 기록한 표다. 문제는 08 문서의 ID로 추적한다. 전체 추적 파일은 evidence/source-inventory.json에 포함한다.

| 경로 | 역할 | 주요 입력 | 주요 출력 | 의존 대상 | 사용 위치 | 문제점 |
|---|---|---|---|---|---|---|
| README.md / design.md / plan.md / checklist.md | 범위·디자인 규약·계획·진행 증거 | 개발 결정 | 사용자/개발 기준 | docs | 인수·개발 | 시점과 목표/완료 표현 혼재 |
| app/page.tsx | 고정 데이터 웹 계산기·문진·JSON 미리보기 | 프로필·문진 | 수식·상태·명령 문자열 | React, lucide, lib | / | Mock fixture 내장, BLOCKED 표시 우선순위 차이 |
| app/layout.tsx | metadata·한국어 HTML·폰트·전역 CSS | children | 공통 문서 | next 호환 타입/font, CSS | 웹 root | 외부 폰트 해석은 빌드환경 영향 |
| app/globals.css | 데스크톱/모바일 배치·글자크기·포커스 | class/media query | 스타일 | page/layout | 웹 | 전체 접근성 실사용 검증 부족 |
| app/algorithm/vibration-algorithm.ts | 웹 평균·파일럿 계산·명령 preview | Profile·4건·SafetyAnswers | AlgorithmResult·JSON object | 없음 | page/test | ID 중복검사 없음,12항목 모두 필수 |
| app/algorithm/vibration-algorithm.test.mjs | 웹 기본 회귀5건 | 합성 측정 | node:test 결과 | 웹 엔진 | 수동 명령 | fixture JSON 직접 사용 아님, 경계검사 부족 |
| public/sw.js | network-first 앱 캐시 | GET request | 캐시/네트워크 Response | Cache API | page 등록 | 모든 GET 저장, 실패 시 HTML fallback, 캐시 크기 정책 없음 |
| public/manifest.webmanifest / favicon.svg | 설치 metadata·아이콘 | 정적 자원 | manifest/icon | 웹 | 브라우저 | 설치/오프라인 전체 QA 미실행 |
| package.json / package-lock.json | 웹 의존성·실행 스크립트 | npm 명령 | dev/build/lint | Node>=22.13 | 개발·빌드 | test/typecheck 스크립트 없음 |
| vite.config.ts / next.config.ts | Vinext·Cloudflare·Sites 플러그인과 개발설정 | hosting config·env | 빌드와 서버 | Vite plugins | npm scripts | beta 도구·로컬 상태, 업무 Worker와 분리 |
| .openai/hosting.json | 웹 Sites 식별·binding 선언 | project_id | 호스팅 연결 | Sites | vite | d1/r2 null, 실제 공개 상태 미확인 |
| tsconfig.json / next-env.d.ts | 웹·하위 TS 타입환경 | TS 소스 | 타입 진단 | tsc/Vinext | 타입검사 | 루트 include가 Worker까지 포함 |
| .oxlintrc.json / .oxfmtrc.json / .gitignore | lint/format/추적 제외 정책 | 소스·경로 | 진단/추적 범위 | oxlint/git | 개발 | /outputs와 실제 /output 불일치; 미추적 임시 폴더 |
| mobile-app/lib/main.dart | 앱 진입·ProviderScope·한국어·Material3 | 앱 시작 | VibeCareApp | Flutter/Riverpod | Android | 다른 플랫폼 준비 없음 |
| mobile-app/lib/screens/pilot_screen.dart | 로그인·대시보드·상세시트·CTA·lifecycle | PilotState·사용자 이벤트 | UI·controller 호출 | Riverpod/controller/models | main | 약1100줄 한 파일, Mock 상태 표현·문진·stop 실패 문제 |
| mobile-app/lib/controllers/pilot_controller.dart | DI·상태·로그인·재계산·허가·타이머 | repository/gateway·사용자명령 | PilotState | Dio/Riverpod/domain/infra | UI | 여러 비동기 흐름 집중, 고정 deviceId, 취소/복구 부족 |
| mobile-app/lib/models/models.dart | 프로필·BIA·vitals·규칙·결과 값 객체 | 생성자 인자 | typed values | Dart | domain/infra/UI | 생성자 제약 부족, safety 미확인 없음 |
| mobile-app/lib/algorithm/vibration_algorithm.dart | 최신 유효4개 선택·평균·보정 | 프로필·측정·문진·규칙 | AlgorithmResult | models, dart:math | controller/test/tool | enabled 미사용, 선택값 NaN 보호 부족 |
| mobile-app/lib/services/auth_repository.dart | Mock/Worker 로그인·메모리/보안토큰 저장 | 코드·PIN/토큰 | AuthSession | Dio/secure storage | controller | refresh를 읽는 API 없음, 데모 UI 기본값 |
| mobile-app/lib/services/fitrus_repository.dart | Mock snapshot / canonical HTTP 파싱 | 프로필·기기ID | MeasurementSnapshot | Dio/domain | controller | deviceId 인자 query에 미사용,3API 중 하나 실패하면 전체 실패 |
| mobile-app/lib/services/device_gateway.dart | 명령·허가·세션·장치 상태 인터페이스 | 명령 인자 | Future·Stream | domain | gateway/controller | BIA·진동기 ID 구분 없음 |
| mobile-app/lib/services/mock_device_gateway.dart | Mock 지연·연결·허가·시작·중지 | 결과·강도·허가 | 상태Stream·Mock session | dart:async | Mock provider | 허가 소비 이력 없음, ACK는 모사 |
| mobile-app/lib/services/backend_device_gateway.dart | Worker 연결·허가·시작·중지·결과 비교 | 로컬 결과·명령 | server session / status | Dio | URL 지정 provider | physical gateway 아님, error시 stop CTA 소멸 |
| mobile-app/test/vibration_algorithm_test.dart | 계산·차단·4건선택5건 | 합성 측정 | assertions | flutter_test/domain | flutter test | 전체 교차언어 parity 아님 |
| mobile-app/test/widget_test.dart | Mock UI5건 | 로그인·탭·작은화면 | assertions | flutter_test/main | flutter test | 문진 생략 경로를 통과시킴, 장애시험 없음 |
| mobile-app/tool/verify_algorithm.dart | 순수 Dart assert 검증 | 하드코딩 fixture | stdout | domain/dart:io | 수동 진단 | --enable-asserts 필요,JSON fixture 직접 읽지 않음 |
| mobile-app/pubspec.yaml / pubspec.lock / analysis_options.yaml | Dart 의존성·lint | Flutter tool | 해결된 패키지·진단 | SDK | pub/analyze/test | secure_storage9.2.4 고정, SBOM 없음 |
| mobile-app/android/app/build.gradle.kts | package·SDK·release signing | Flutter SDK/version | APK/AAB 설정 | Android Gradle | 빌드 | release debug signing |
| mobile-app/android/settings.gradle.kts / build.gradle.kts / gradle.properties / wrapper | 플러그인·Java·캐시·경로 설정 | local.properties·SDK | Android toolchain | AGP/Kotlin/Gradle | 빌드 | 로컬 SDK 의존,한글경로 우회 |
| mobile-app/android/app/src/main/AndroidManifest.xml / MainActivity.kt / res | Android 진입·인터넷권한·테마 | OS lifecycle | Flutter Activity | Flutter Android | APK | BLE 권한/통신 미구현 |
| mobile-app/android/app/src/debug, profile | 개발 manifest | 빌드모드 | 개발권한 설정 | Android | debug/profile | 실제 release 동작과 구분 필요 |
| backend-api/src/index.ts | 12개 HTTP 경로·인가·D1 SQL·세션 | HTTP/Bindings | JSON/DB writes | Hono/Zod/auth/algorithm/FitrusClient | Worker main | 책임 집중, I-01/03~09 |
| backend-api/src/auth.ts | PIN 해시·검증·서명 토큰 | PIN/salt/secret/claims | hash/token/claims/null | Web Crypto | 인증 routes | 계정 프로비저닝·revoke UI 없음 |
| backend-api/src/algorithm.ts | 서버 평균·보정·수동하향 검사 | CanonicalMeasurement[]·profile | RecommendationResult | 없음 | authorize/test | Flutter보다 검사 적음 |
| backend-api/src/fitrus-client.ts | 6경로 allowlist HTTP 프록시 | key·kind·payload·signal | object 또는 FitrusApiError | fetch | proxy route/test | runtime schema·timeout·retry 없음 |
| backend-api/migrations/0001_initial.sql | 참여자·PIN·BIA·허가·세션·이벤트·평가 | 빈DB | 기본7테이블·인덱스 | D1/SQLite | migrations | 값 상한·상태 제약 일부 부족 |
| backend-api/migrations/0002_measurements_and_rules.sql | raw/vitals/rules/set/recommendation 확장 | 0001 적용DB | 5테이블·열·초기규칙 | D1 | migrations | approved_by NULL인 활성규칙, optional null 계약 |
| backend-api/package*.json / tsconfig.json / vitest.config.ts | API 의존성·Node 단위시험 | npm/TS | test/typecheck | Hono/Zod/Vitest | 개발 | 실제 runtime과 테스트환경 다름 |
| backend-api/test/*.test.ts | 계산4·인증2·공급사client2 | 합성 데이터/fetch double | assertions | src | npm test | 라우트·D1·실네트워크 검사 없음 |
| backend-api/cloudflare-local-runtime.jsonc / .dev.vars.example / README.md | 현재 프로토타입 DB·env·secret명·운영안내 | 환경설정 | 로컬 런타임 설정 | Wrangler | 개발 | AWS 런타임·DB 어댑터 미구현 |
| shared-contracts/openapi.yaml | 공개 HTTP 계약 | 요청/응답 설계 | API 문서 | 실제로 import되지 않음 | 개발자 | 다수 본문·응답 schema 미기재 |
| shared-contracts/*schema.json / fitrus-endpoints.json | 데이터·규칙·명령·공급사 경로 명세 | DTO | 독립 계약 | runtime 연결 없음 | 개발자 | nullable/vitals/수치 차이 |
| shared-contracts/fixtures/pilot-0.3.0.json | 공통 예제와 기대값 | 연구용 합성값 | REVIEW·38/45 예제 | runtime 연결 없음 | 근거자료 | 현재 테스트가 직접 소비 안 함 |
| docs/architecture.md / system-design.md | 목표·구현 구조 서술 | 설계 | 다이어그램 | plan | 개발자 | 일부 계획을 현행처럼 표현 |
| docs/open-source-and-evidence.md / docs/evidence/*.md | 기술·연구근거·이전 검증 기록 | 문헌·기존 실행 | 근거/검증기록 | 외부 출처 | 인수자료 | 예전 결과와 이번 실행 구분 필요 |

## 중복·미사용·임시 구성

- [사실] 세 알고리즘 구현, SQL seed, fixture JSON에 계수가 반복된다. 공유 스키마를 자동 적용하는 import나 생성 스크립트는 없다.
- [사실] `AlgorithmRuleSet.enabled`는 Dart 계산에 사용되지 않는다. BackendDeviceGateway는 result의 전체 평균/경고를 비교하지 않고 시간·Hz·강도만 비교한다.
- [사실] refresh/event/feedback/FITRUS POST는 서버에 존재하지만 Flutter 호출이 없다. `device_sessions.completed_at`은 생성 이후 갱신 코드가 없다. `ENVIRONMENT`도 업무 분기에서 쓰이지 않는다.
- [사실] `hooks/`는 현재 비어 있다. `.next`, `.vinext`, dist, Flutter build는 생성물이다. 삭제하지 않았다.
- [추론] 화면을 기능별 파일로 분리하는 것보다 먼저 안전·세션 모델을 확정해야 한다. 구조만 분리하면 현재 잘못된 상태 전이도 그대로 여러 파일에 퍼질 수 있다.
