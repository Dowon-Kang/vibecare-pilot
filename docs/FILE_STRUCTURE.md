# VibeCare Pilot 파일 구조

> 기준: Flutter 모바일 앱 + Cloudflare Worker API + 공통 계약 + 비교용 웹 화면
> 상태: `[구현]` 실행 코드 연결 완료 · `[부분]` 외부 명세/실장비 미연결 · `[문서]` 설계·검증 자료

```text
vibration-control-app/
│
├── app/                                      # 비교·시연용 Sites/Vinext 웹 앱
│   ├── page.tsx                              # [구현] 측정값·보정식·추천 명령 웹 화면
│   ├── layout.tsx                            # [구현] HTML 언어·메타데이터·공통 레이아웃
│   ├── globals.css                           # [구현] 반응형 레이아웃·접근성 스타일
│   └── lib/
│       ├── vibration-algorithm.ts            # [구현] 웹용 4건 평균·추천 알고리즘
│       └── vibration-algorithm.test.mjs      # [구현] 웹 알고리즘·공통 fixture 테스트
│
├── public/                                   # 웹/PWA 정적 파일
│   ├── favicon.svg                           # 웹 아이콘
│   ├── manifest.webmanifest                  # PWA 이름·색상·설치 설정
│   └── sw.js                                 # 서비스워커 캐시 처리
│
├── apps/
│   └── mobile/                               # 실제 Android 우선 Flutter 앱
│       ├── lib/
│       │   ├── main.dart                     # 앱 시작점, Riverpod·Material 3·한국어 설정
│       │   ├── application/
│       │   │   └── pilot_controller.dart     # 로그인→조회→계산→전송→시작→중지 흐름
│       │   ├── domain/                       # 외부 기술에 의존하지 않는 핵심 규칙
│       │   │   ├── models.dart               # 참여자·측정·추천·허가·장치 세션 모델
│       │   │   ├── vibration_algorithm.dart  # 최근 유효 4건 평균과 보정계수 계산
│       │   │   └── session_feedback.dart     # RPE·통증·어지럼 후속 강도 제한
│       │   ├── infrastructure/               # API·저장소·장치 연결 구현
│       │   │   ├── auth_repository.dart      # Mock/Worker PIN 로그인·토큰 저장
│       │   │   ├── authenticated_client.dart # 401 토큰 갱신·중복 refresh 방지
│       │   │   ├── fitrus_repository.dart    # Mock/Worker 측정값·규칙 조회
│       │   │   ├── feedback_repository.dart  # 사용 후 피드백 조회·저장
│       │   │   ├── device_gateway.dart       # connect/authorize/start/stop 공통 계약
│       │   │   ├── mock_device_gateway.dart  # [구현] 전송·실행·중지 시뮬레이터
│       │   │   └── server_device_gateway.dart# [부분] Worker 세션 연결, 물리 출력 아님
│       │   └── presentation/
│       │       ├── pilot_screen.dart          # 로그인·측정·강도조절·고정 CTA·중지
│       │       └── overview_card.dart         # 상태·추천값·보정식 요약 카드
│       ├── test/
│       │   ├── vibration_algorithm_test.dart # 4건 평균·38/45%·차단 검증
│       │   ├── widget_test.dart               # 로그인·전송·시작·중지·작은 화면
│       │   └── authenticated_client_test.dart # 동시 401·토큰 갱신
│       ├── tool/
│       │   ├── verify_algorithm.dart          # 알고리즘 수동 검증
│       │   └── verify_command.dart            # 장치 명령 JSON 수동 검증
│       ├── android/                           # Android Gradle·Manifest·앱 아이콘
│       │   └── app/src/main/kotlin/com/vibecare/pilot/
│       │       └── MainActivity.kt            # Android에서 Flutter를 여는 진입점
│       ├── pubspec.yaml                       # Flutter·Dio·Riverpod·보안저장소 의존성
│       ├── pubspec.lock                       # Flutter 패키지 버전 고정
│       └── analysis_options.yaml              # Dart 정적 분석 규칙
│
├── services/
│   └── api/                                  # Cloudflare Worker 백엔드·보안 경계
│       ├── src/
│       │   ├── index.ts                       # HTTP route·D1 조회·실행 허가 진입점
│       │   ├── auth.ts                        # PIN 해시·access/refresh token
│       │   ├── algorithm.ts                   # 서버측 평균·추천 재계산·강도 검증
│       │   ├── rule-schema.ts                 # 알고리즘 규칙 Zod 검증
│       │   ├── fitrus-client.ts               # [부분] FITRUS 6개 URL 서버 전용 호출
│       │   └── feedback.ts                    # RPE·통증·어지럼 후속 보정
│       ├── migrations/                        # Cloudflare D1 변경 이력
│       │   ├── 0001_initial.sql               # 참여자·PIN·BIA·허가·세션·이벤트
│       │   ├── 0002_measurements_and_rules.sql# 원본·vitals·규칙·4건세트·추천
│       │   ├── 0003_session_safety.sql        # 중복 실행·세션 안전성
│       │   └── 0004_feedback_adjustments.sql  # 다음 강도 상한·검토 상태
│       ├── test/
│       │   ├── algorithm.test.ts              # 서버 추천 알고리즘
│       │   ├── auth.test.ts                   # PIN·토큰 보안
│       │   ├── fitrus-client.test.ts          # 공급사 URL·키·오류 전달
│       │   └── routes.test.ts                 # 인증·추천·세션·피드백 route
│       ├── wrangler.jsonc                     # Worker·D1·FITRUS URL·Mock 장치 설정
│       ├── .dev.vars.example                  # 비밀값 이름 예시, 실제 키 저장 금지
│       ├── package.json                       # Hono·Zod·test/typecheck
│       ├── package-lock.json                  # API 패키지 버전 고정
│       ├── tsconfig.json                      # API TypeScript 설정
│       └── vitest.config.ts                   # API 테스트 설정
│
├── packages/
│   └── contracts/                             # Flutter·Worker·웹 공통 계약
│       ├── openapi.yaml                       # 인증·측정·추천·장치 HTTP API
│       ├── bia-measurement.schema.json        # 체성분 DTO와 단위
│       ├── vital-measurement.schema.json      # 혈압·심박·스트레스·체온 DTO
│       ├── algorithm-rule-set.schema.json     # 시간·Hz·강도·보정계수·버전
│       ├── device-command.schema.json         # 장치 실행 명령 형식
│       ├── fitrus-endpoints.json              # FITRUS 종류·공급사 URL 매핑
│       └── fixtures/
│           └── pilot-0.3.0.json               # 세 알고리즘 결과 일치용 입력
│
├── docs/                                      # 설계·근거·검증 문서
│   ├── FILE_STRUCTURE.md                      # 현재 문서: 파일 책임 지도
│   ├── architecture.md                        # 시스템·상태·실패 흐름
│   ├── system-design.md                       # 구현 기준·데이터 흐름
│   ├── QUALITY_UPGRADE.md                     # 보안·안전·품질 기준
│   ├── open-source-and-evidence.md            # 논문·오픈소스 근거·한계
│   ├── evidence/                              # 알고리즘·API·도구 검증 기록
│   └── project-analysis/                      # WHAT→HOW→구현 계획 상세 분석
│       ├── 00_EXECUTIVE_SUMMARY.md            # 한 문장 정의·핵심 판단
│       ├── 01_PROJECT_BRIEF.md                # 사용자·문제·범위
│       ├── 02_REQUIREMENTS.md                 # 기능·비기능 요구사항
│       ├── 03_ARCHITECTURE.md                 # 구조·데이터·신뢰 경계
│       ├── 04_COMPONENT_RESPONSIBILITIES.md   # 파일·모듈 책임
│       ├── 05_CONTRACTS.md                    # HTTP·DB·장치 계약
│       ├── 06_AI_AND_DATA.md                  # 규칙 알고리즘·데이터
│       ├── 07_CONSTRAINTS_AND_SECURITY.md     # 보안·외부 의존성
│       ├── 08_VERIFICATION.md                 # 테스트·증거·실패
│       ├── 09_DECISIONS_AND_QUESTIONS.md      # 결정·가정·질문
│       ├── 10_TASKS_AND_ROADMAP.md            # 다음 작업·완료 조건
│       └── 11_EASY_GUIDE.md                   # 비개발자용 쉬운 설명
│
├── .openai/
│   └── hosting.json                           # 기존 Sites 프로젝트 식별자
├── .gitignore                                 # 키·캐시·빌드·임시파일 제외
├── package.json                               # 루트 웹 dev/build/lint 명령
├── package-lock.json                          # 루트 웹 패키지 버전 고정
├── vite.config.ts                             # Vinext·Sites·Cloudflare 웹 빌드
├── next.config.ts                             # Next 호환 설정
├── tsconfig.json                              # 루트 웹 TypeScript 설정
├── README.md                                  # 목적·실행 방법·현재 한계
├── plan.md                                    # 구현 단계·완료 기준
├── checklist.md                               # 완료·부분·차단 항목·증거
└── design.md                                  # 고령자 모바일 UI/UX 규약
```

## 핵심 연결 흐름

```text
Flutter 화면
→ apps/mobile/lib/application/pilot_controller.dart
→ Repository 또는 DeviceGateway
→ services/api/src/index.ts
→ 인증 / FITRUS / 추천 알고리즘 / D1 / 장치 세션
→ 표준 JSON 응답
→ Flutter 상태 갱신과 화면 표시
```

```text
packages/contracts/fixtures/pilot-0.3.0.json
├── apps/mobile/lib/domain/vibration_algorithm.dart
├── services/api/src/algorithm.ts
└── app/lib/vibration-algorithm.ts

세 구현은 같은 입력에서 같은 추천 결과를 만들어야 한다.
```

## 현재 실제 연동 상태

| 영역 | 상태 | 의미 |
|---|---|---|
| Flutter 화면·알고리즘 | 구현 | Mock 로그인·측정·추천·전송·시작·중지 가능 |
| Worker 인증·추천·세션 | 구현 | 로컬 테스트 기준 route와 D1 흐름 존재 |
| FITRUS URL 호출 | 부분 | 서버 client 존재, 성공 응답·정규화 계약 미확정 |
| 실제 진동기 | 부분 | 공통 Gateway·서버 세션 존재, REST/BLE 명령 미확정 |
| PWM·가속도·진폭 | 미확정 | 장비 교정표와 물리 안전 상한 필요 |
| ML/AI 모델 | 없음 | 현재는 설명 가능한 규칙 기반 알고리즘 |

## Git에 포함하지 않는 폴더

```text
node_modules/                   # 설치한 Node 패키지
**/build/                       # Flutter·Android 빌드 결과
.next/ .vinext/ dist/           # 웹 빌드 결과
.wrangler/                      # Worker 로컬 상태
apps/mobile/.android/           # 로컬 AVD 설정
apps/mobile/.tmp/               # adb 임시 로그
output/ tmp/                    # PDF와 중간 생성물
.env* services/api/.dev.vars    # 실제 비밀키·환경값
```

## 이 저장소에 없는 구조

- FastAPI, `main.py`, `routes.py`, `predictor.py`, `requirements.txt` 없음
- 학습된 ML 모델과 `models/*.pkl` 없음
- Dockerfile과 AWS ECR/ECS 배포 workflow 없음
- 실제 BLE GATT 또는 진동기 REST 명령 구현 없음

현재 프로젝트는 **Python AI 예측 서버**가 아니라 **Flutter 앱과 Cloudflare Worker로 구성된 규칙 기반 진동 추천 연구 프로토타입**이다.
