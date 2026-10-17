# VibeCare Pilot.

Mock 추천 계산의 현재 규칙은 [`pilot-0.9.1`](docs/algorithm/pilot-0.9.1-design.md)이다. 여성·70세 이상·체지방 범위 이탈 계수는 각각 0.95인 연구용 예시이며 실제 장치 출력에 쓰지 않는다. 웹 Pages의 Mock 시연 화면에는 반영되었고, 별도 운영 Backend API 및 데이터베이스 마이그레이션은 수행하지 않았다.

FITRUS 체성분 측정 이력을 저장·검증하고, 최신 API 골격근량의 근육지수를 낮음·중간·높음으로 분류해 확정된 부위별 시간·Hz·강도를 보여주는 Flutter 연구 프로토타입입니다.

> `pilot-0.9.1`은 의료 처방이 아닙니다. 물리 장치 실행은 모든 경로에서 `PROHIBITED`이며, 현재 허가는 Mock 시뮬레이션에만 발급됩니다.

## 공개 시연판

[VibeCare Web 시연판 열기](https://dowon-kang.github.io/vibecare-pilot/)

연결 모드의 예약·출석은 Supabase에 계정별로 저장하고, 샘플 시연 기록은 브라우저에 저장한다. 웹 예약 알림은 페이지가 열려 있을 때 표시한다.

공개 웹 화면은 Supabase Auth 이메일 계정으로 로그인해 본인 예약·출석과 연결된 측정 기록을 읽는다. 별도의 합성 시연 화면에서는 시연 대상을 선택한 뒤 `시연 시작`으로 추천 매핑을 체험한다. 참여자 코드와 PIN을 다시 입력하지 않는다. 실제 진동기에는 연결되지 않는다.

## 핵심 흐름

생활 돌보기의 실제 AI 연결 코드는 Supabase 인증 서버 함수와 OpenAI Responses API를 사용한다. 앱에서 매번 세 측정 수치와 목표의 전송에 동의하면 AI가 일반 음식·움직임 후보와 측정 해석 관점을 선택한다. 연구 등급으로 진단·처방을 만들지 않으며 제한이 미확인/존재하면 해당 후보를 보류한다. 샘플 생활 돌보기는 별도 동의 후 서버의 고정 합성값만 Gemini에 보내는 시연을 제공한다. 실제 사용자 정보는 Gemini에 전송하지 않는다. 무료 시연 한도는 공용 UTC 하루20회·분당3회다.

운영 활성화에는 서버 키 등록·측정 조회/요청 한도 RPC 적용·실제 공급자 합성 검증이 필요하다. 현재 완료/미완료는 [검증 체크리스트](checklist.md)를 확인한다. [서버 연결과 운영 순서](backend-api/README.md), [최신 데이터 전송 계약](docs/project-overview.md), [연결 구조](docs/architecture.md)에 경계를 기록한다.

생활관리 1차 확장 작업판은 연결 홈·샘플 홈의 **생활 습관 관리**에서 관심 습관 선택, 오늘의 실천·쉬기·취소, 최근 7일 돌아보기와 공식 일반 건강 안내를 제공한다. 계정별로 이 기기에 최근 90일을 저장하며 서버 동기화·담당자 공유·개인 처방은 제공하지 않는다. 기본 APK의 샘플 모드는 로그인 전 **샘플 홈·생활 습관 보기**로 접근한다. 자체 Backend 로그인 모드에는 생활 기록을 아직 연결하지 않았다. 공개 시연판의 배포 여부는 [검증 체크리스트](checklist.md)의 최신 생활관리 항목을 확인한다.

```text
로그인 → 최근 측정 4건의 출처·품질 확인
      → 평균·표본 SD·CV·범위 계산
      → 최신 골격근량의 근육지수 등급과 부위별 고정 설정 선택
      → 안전 문진 → Mock 후보 확인 → 시뮬레이션 시작/중지 → 피드백
```

근육량 정의가 `UNKNOWN`이거나 4건의 정의·방법·단위·획득 프로토콜이 맞지 않으면 층화와 후보 생성을 모두 거부합니다. ASM과 SMM은 사용자가 임의로 바꾸어 해석하지 않습니다.

## 폴더 구조

```text
mobile-app/        Flutter Android 앱과 앱 테스트
backend-api/       인증·FITRUS 프록시·서버 재계산·Mock 세션 API
shared-contracts/  OpenAPI, JSON Schema, 공통 fixture
deployment/aws/    AWS 배포 담당자를 위한 인계 조건
docs/              아키텍처, 알고리즘 근거, 검증 기록
```

## 실행

```powershell
Push-Location .\mobile-app
flutter pub get
flutter run
Pop-Location

Push-Location .\backend-api
npm ci
npm run typecheck
npm test
Pop-Location
```

백엔드 연결 앱은 `--dart-define=VIBECARE_API_BASE_URL=https://...`를 사용합니다. FITRUS 키는 앱이나 Git에 넣지 않고 백엔드 환경변수 `FITRUS_API_KEY`로만 주입합니다.

Supabase DB, 백엔드 API와 Android APK의 배포 순서는 [배포 Runbook](docs/deployment.md)을 따릅니다.

웹 Auth·예약 연결은 `VIBECARE_SUPABASE_URL`과 공개용 `VIBECARE_SUPABASE_PUBLISHABLE_KEY`를 빌드에 주입한다. DB 비밀번호와 service role 키는 웹 빌드에 넣지 않는다. 예약은 Auth 사용자별 RLS로 제한하고, 실제 측정 기록은 관리자가 `public.account_participants`에 계정을 연결한 경우에만 보인다.

## 구현 경계

- Backend algorithm: SMM 정의 검증, 최신 골격근량/키² 근육지수 등급, 6개 부위 고정값, 안전 차단 구현
- Baselines and coefficients: 프로젝트 제공값을 코드·서버 규칙·화면에서 추적하며 모두 `HYPOTHESIS_UNVALIDATED`로 표시
- Demographics: 성별과 키로 근육지수 연구 경계를 판정한다. `pilot-0.9.1`의 여성·70세 이상·체지방 범위 이탈 계수는 Mock 강도에만 적용하며 실제 진동량으로 해석하지 않는다.
- FITRUS: 공식 요청·응답 필드에 맞춘 서버 전용 프록시와 체성분·활력 자동 저장 경로가 구현됨. 단위·유효 범위·근육 산출법이 미확인인 값은 추정하지 않고 미지원 응답은 raw로 보존
- Device: 앱 내부 Mock과 서버 시뮬레이터만 구현. REST/BLE 물리 장치 어댑터는 없음
- Storage: Node/PostgreSQL adapter·migration·합성 seed 구현. AWS 운영 인프라와 운영 백엔드 배포는 미완료

테스트 통과는 코드 흐름의 재현성을 뜻하며 임상 효과나 물리 장치 안전을 증명하지 않습니다. 정량 결과와 원격 빌드 상태는 [검증 체크리스트](checklist.md)와 최신 GitHub Actions 실행을 함께 확인하세요.

자세한 내용은 [문서 안내](docs/README.md), [계획](plan.md), [검증 체크리스트](checklist.md)를 확인하세요.

## 기업 인계 기준

현재 인계 범위는 기존 기능을 유지하는 **Mock 연구 시연판의 재현·검증**이다. 운영 서비스·스토어 출시·FITRUS 실연동·실장비 검증의 완료 판정은 별도로 한다. 작업을 시작할 때 폴더·브랜치·커밋과 미커밋 변경을 확인한다.

`quality-gates`는 백엔드, 실제 로컬 PostgreSQL/Node HTTP, Flutter 검사·debug APK, 웹 빌드를 같은 커밋으로 검사한다. main의 검사 성공 뒤에만 같은 실행의 Pages 산출물을 배포한다. APK·PostgreSQL 시험 로그·검증 요약 artifact 이름에는 검사한 SHA가 들어간다. PR에서는 배포하지 않는다.

새 환경에서 재현하는 명령은 [백엔드 실행 안내](backend-api/README.md), 인수자가 확인할 범위와 운영 결정은 [배포 Runbook](docs/deployment.md)을 따른다. 실제 수행 결과는 [체크리스트](checklist.md)에 기록한다.

생활 돌보기 기본 안내에는 식사 8개·운동 6개가 포함되어 API 비용 없이 이용할 수 있습니다. 측정과 관심 항목으로 먼저 볼 일반 후보를 고르며 비교 조건이 확인되지 않은 측정 이력은 자동 비교하지 않습니다. 안내는 개인별 섭취량·운동량 처방이 아닙니다.

자동 추천 작업판에서는 로그인 계정의 최근 본인 측정을 안내 진입 시 자동 조회하고 관심 항목 선택 없이 후보를 고릅니다. 운영 적용/데이터 준비 및 검증 상태는 checklist.md의 최신 실제 측정 자동 추천 항목을 따릅니다.


외부 블루투스 앱을 연결할 개발자는 [측정 수신 연동 가이드](docs/external-measurement-integration.md)를 참고한다. 본인 인증·결과 전송 API·JSON Schema·TypeScript 어댑터를 준비했으며 외부 앱/기기 선정 전 운영 출처는 활성화하지 않는다.
