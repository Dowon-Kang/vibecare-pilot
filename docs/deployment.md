# VibeCare 배포 Runbook

문서 점검 기준일: 2026-10-06. 아래 원격 DB 상태 표는 2026-09-20의 확인 이력이며 현재 원격 상태를 재검증한 결과가 아니다.

이 문서는 현재 저장소를 기준으로 Supabase 데이터베이스, VibeCare 백엔드 API, Flutter Android 앱을 배포하는 순서를 설명한다. 현재 제품은 연구용 Mock 시뮬레이터이며 실제 진동기 명령은 배포 대상이 아니다.

## 1. 배포 상태 확인 이력

| 구성요소 | 상태 | 근거 |
|---|---|---|
| Supabase 프로젝트 | 완료 | `vibecare-pilot`, 서울 `ap-northeast-2`, `ACTIVE_HEALTHY` |
| 원격 DB schema | 완료 | 비공개 `vibecare` schema, `001_schema`, 활성 `pilot-0.9.0` 규칙 1건 |
| 원격 실사용 데이터 | 없음 | 참여자·측정·세션 행 0건 |
| 백엔드 코드 | 준비됨 | Node/Hono 진입점과 PostgreSQL adapter 구현 |
| 백엔드 호스팅 | 미완료 | 공개 HTTPS 주소, 운영 컨테이너와 배포 자동화 없음 |
| Flutter 내부 시연 APK | 빌드 가능 | API 주소를 `--dart-define`으로 주입 가능 |
| Flutter Web 공개 시연판 | 변경 준비 | `https://dowon-kang.github.io/vibecare-pilot/`, Supabase Auth·예약 및 분리된 샘플 시연 |
| Play Store 릴리스 | 미완료 | 현재 release build가 debug signing을 사용함 |
| 실제 진동기 | 배포 금지 | `DEVICE_MODE=mock`, `REAL_DEVICE_ENABLED=false` 유지 |

목표 구조:

```text
Flutter Android 앱
        │ HTTPS
        ▼
VibeCare Hono 백엔드 API
        │ TLS PostgreSQL 연결
        ▼
Supabase PostgreSQL / vibecare schema
```

Flutter 웹은 공개용 Supabase URL·publishable key로 Auth와 RLS가 적용된 예약·측정 보기만 사용한다. 기존 시뮬레이터 백엔드의 DB 연결 문자열, DB 비밀번호, FITRUS API 키와 인증 토큰 비밀값은 백엔드 호스팅 환경에만 저장한다.

## 2. 준비물

- Node.js 22와 npm
- Flutter 3.47.2 stable, Android SDK, JDK 17
- 공개 HTTPS를 제공하는 장기 실행 Node 호스트
- Supabase `vibecare-pilot` Dashboard 접근 권한
- Supabase DB 비밀번호
- 운영용 32자 이상 `AUTH_TOKEN_SECRET`
- 실제 연동 시에만 FITRUS API 키

비밀값을 문서, Git, APK, `--dart-define`, 빌드 로그에 기록하지 않는다.

## 3. Supabase 연결 준비

원격 schema는 이미 적용됐다. 기존 `001_schema`를 임의로 다시 실행하지 않는다. 새 DB 변경은 검토된 migration으로만 적용한다.

1. Supabase Dashboard에서 `vibecare-pilot`을 연다.
2. 상단 **Connect**를 누른다.
3. 장기 실행 백엔드가 IPv4 네트워크에 있으면 **Session pooler**를 선택한다.
4. 포트 `5432` 연결 문자열을 복사한다.
5. `[YOUR-PASSWORD]`만 실제 DB 비밀번호로 교체해 호스팅 서비스의 secret에 저장한다.

연결 문자열 예시 형식:

```text
postgresql://postgres.PROJECT_REF:DB_PASSWORD@SESSION_POOLER_HOST:5432/postgres
```

실제 연결 문자열은 저장소 파일에 저장하지 않는다. Supabase 연결 방식은 [공식 연결 문서](https://supabase.com/docs/guides/database/connecting-to-postgres)를 따른다.

## 4. 백엔드 환경변수

호스팅 서비스의 secret/environment 설정에 다음 값을 등록한다.

```env
DATABASE_URL=<Supabase Session pooler URI>
DATABASE_SCHEMA=vibecare
DATABASE_SSL=require
DATABASE_SSL_REJECT_UNAUTHORIZED=true
DATABASE_POOL_MAX=5

ENVIRONMENT=production
ALLOW_DEVELOPMENT_SEED=false
AUTH_TOKEN_SECRET=<32자 이상의 무작위 비밀값>

FITRUS_API_BASE_URL=https://api.thefitrus.com/fitrus-ml/measure
FITRUS_API_KEY=<승인된 운영 키>

DEVICE_MODE=mock
REAL_DEVICE_ENABLED=false
PORT=8787
```

`FITRUS_API_KEY`가 아직 없으면 FITRUS 실호출은 검증할 수 없다. 키가 없다는 이유로 임의 키나 사용자 데이터를 넣지 않는다.

## 5. 백엔드 배포

Mock 인계 검증은 운영 배포와 별도로 실행한다. 실제 PostgreSQL HTTP 재현 명령은 [백엔드 안내](../backend-api/README.md#실제-postgresql-http-통합-검사)를 따른다. 시험 DB는 loopback의 `vibecare_test`로 제한하고 관리형 DB의 운영 URI를 시험 변수에 넣지 않는다.

### 5.1 배포 전 품질 검사

저장소 루트에서 실행한다.

```powershell
Push-Location .\backend-api
npm ci
npm audit --omit=dev --audit-level=high
npm run typecheck
npm test -- --reporter=dot
Pop-Location
```

한 명령이라도 실패하면 배포하지 않는다.

### 5.2 현재 코드로 내부 시연 서버 실행

Node 호스트의 working directory를 `backend-api`로 설정한다.

```text
Install command: npm ci
Start command:   npm run dev:postgres
Health path:     /health
Readiness path:  /ready
```

`dev:postgres`라는 이름이지만 현재 Node/PostgreSQL 서버 진입점을 실행한다. 내부 시연에는 사용할 수 있다. 운영 배포 전에는 TypeScript 빌드 산출물과 고정 Node 이미지로 실행하는 `Dockerfile` 및 `start` script를 별도로 추가해야 한다.

### 5.3 AWS로 운영할 경우

후속 AWS 담당자는 기본안으로 다음 구성을 사용한다.

```text
ECR image
  → ECS Fargate service
  → Application Load Balancer
  → HTTPS domain
  → Supabase Session pooler
```

필수 작업:

1. 운영용 `Dockerfile`과 `npm start` 추가
2. 이미지를 ECR에 push
3. ECS task에 위 환경변수와 secret 주입
4. ALB HTTPS listener와 인증서 설정
5. `/health`와 `/ready` health check 구성
6. CloudWatch JSON 로그와 오류 경보 구성
7. `DEVICE_MODE=mock`, `REAL_DEVICE_ENABLED=false` 확인

구체적인 AWS 인수 조건은 [AWS 배포 인계](../deployment/aws/README.md)를 따른다.

## 6. 배포 직후 백엔드 검증

백엔드 주소를 `https://api.example.com`이라고 가정한다.

```powershell
Invoke-RestMethod https://api.example.com/health
Invoke-RestMethod https://api.example.com/ready
```

합격 기준:

- `/health`: HTTP 200
- `/ready`: HTTP 200이며 DB 준비 상태 정상
- DB 연결 실패 시 `/ready`: HTTP 503
- 로그에 DB 비밀번호, PIN, 토큰, FITRUS 원문이 없음
- 실제 진동기 호출이 발생하지 않음

## 7. Flutter 내부 시연 APK

영문 경로로 연결된 `V:` 드라이브를 사용한다면 다음처럼 실행한다.

```powershell
V:
cd V:\mobile-app
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --reporter compact
flutter build apk --release --no-pub `
  --dart-define=VIBECARE_API_BASE_URL=https://api.example.com
```

생성 파일:

```text
V:\mobile-app\build\app\outputs\flutter-apk\app-release.apk
```

연결된 Android 기기 또는 에뮬레이터에 설치한다.

```powershell
adb devices
adb install -r V:\mobile-app\build\app\outputs\flutter-apk\app-release.apk
```

공개 HTTPS 백엔드를 사용하는 APK에는 `10.0.2.2`를 넣지 않는다. `10.0.2.2`는 Android 에뮬레이터에서 개발 PC의 로컬 서버에 접근할 때만 사용한다.

### 7.1 공개 Web 시연판

다른 사람이 설치 없이 UI를 확인할 수 있도록 GitHub Pages에 Supabase Auth 화면과 별도의 샘플 시연 화면을 게시한다.

```text
https://dowon-kang.github.io/vibecare-pilot/
```

공개판은 `VIBECARE_SUPABASE_URL`과 공개용 `VIBECARE_SUPABASE_PUBLISHABLE_KEY`를 주입한다. `VIBECARE_API_BASE_URL`은 주입하지 않으므로 FITRUS API와 실제 장치에는 접근하지 않는다. `deployment/supabase/002_auth_participation.sql`을 적용하고 Supabase Auth의 허용 리디렉션 URL에 `https://dowon-kang.github.io/vibecare-pilot/`를 추가해야 이메일 가입 확인 후 Pages로 돌아온다. Web 산출물은 `/vibecare-pilot/` base href로 빌드해 GitHub Pages에 게시한다.

Auth 계정만 만들면 예약·출석은 바로 사용할 수 있다. 실제 측정 데이터는 관리자가 Supabase SQL Editor에서 확인된 `auth.users.id`와 기존 `vibecare.participants.id`를 `public.account_participants`에 연결한 뒤에만 보인다. 두 테이블에 실제 대상 기록이 없는 상태에서는 측정 화면이 빈 상태를 보여 준다. 샘플 시연 화면의 측정값은 이 연결과 무관하다.

### 7.2 CI 검사와 인계 산출물

`.github/workflows/ci.yml` 하나가 백엔드·PostgreSQL HTTP·Flutter·웹 빌드를 검사한다. 같은 실행에서 네 검사가 모두 성공하고 ref가 main일 때만 Pages에 배포한다. PR에서는 검증 산출물만 만들고 배포하지 않는다. 이전의 독립 `deploy-pages.yml`은 제거한다.

GitHub Actions에서 인계 대상 SHA와 실행 결과를 확인하고 다음 artifact를 받아 보관한다. CI artifact의 기본 보관기간은 14일이며, 기업 인수 자료는 별도의 승인된 보관 위치로 옮긴다.

- `handoff-verification-<SHA>`: 커밋·실행 링크·검사별 결과·외부 미검증 범위
- `postgres-http-evidence-<SHA>`: 실제 PostgreSQL/Node HTTP 시험 로그
- `vibecare-debug-apk-<SHA>`: 내부 시연용 APK와 `app-debug.apk.sha256`
- `github-pages`: 같은 커밋의 Pages 웹 산출물과 `SHA256SUMS.txt`

PR 검사 SHA는 GitHub가 만든 임시 병합 커밋일 수 있다. PR head와 검사 SHA를 구분하고, 최종 main 인계 판정은 병합 후 main SHA의 성공한 실행으로 한다. 성공한 실행이 없으면 검증 완료로 기록하지 않는다.

main 보호의 필수 검사는 `Backend typecheck and tests`, `PostgreSQL HTTP integration`, `Flutter format, analyze, tests and debug APK`, `Flutter web build`이다. GitHub의 실제 보호 설정은 API 또는 저장소 Settings에서 확인한다.

2026-10-06에는 위 네 검사와 strict, 관리자 우회 금지, PR 경유를 적용하고 API로 재조회했다. 필수 승인자 수는 0이다. 기업 리뷰 담당자와 실제 승인 절차는 인수 시 확정하며, 검사 성공만으로 기업 승인이나 운영 출시를 선언하지 않는다.

### 7.3 인수자가 확인할 범위와 운영 결정

현재 승인 범위는 Mock 연구 시연판이다. 다음 항목을 기존 체크리스트에 증거와 함께 기록한다.

1. 새 개발 환경에서 잠금 파일로 설치하고 합성 데이터의 로그인→측정→Mock 시작/중지→피드백 흐름을 재현한다.
2. 공개 웹은 별도 시험 Auth 계정 두 개로 각자의 예약·출석·연결 측정만 보이는지, 다른 계정의 조회/수정/소유권 변경이 거부되는지 확인한다. PIN 계정의 PostgreSQL 시험으로 대체하지 않는다.
3. 인계 대상이 Android를 포함하면 실제 기기의 알림 권한 거부·재부팅·배터리 제한과 접근성을 확인한다.
4. 기업 담당자가 인계 SHA·산출물·알려진 제한을 검토하고 인수 결과를 기록한다.

아래 값과 담당자는 사용자·기업이 결정한다. 확정 전에는 임의 수치로 합격 판정하거나 새 저장·삭제 정책을 적용하지 않는다.

| 결정 | 확정할 내용 | 현재 상태 |
|---|---|---|
| 인계 제품 | Mock 시연 / 실사용 운영 / 스토어 출시, 포함 플랫폼 | 이번 작업은 기존 Mock 시연 범위 |
| 성능·비용 | 예상 동시 사용자, p95 응답 시간, 허용 오류율, 월 비용 한도 | 담당자와 목표값 결정 필요 |
| 알림 | 페이지 종료 후 전달 필요 여부, 허용 지연 | 현재 웹은 열린 페이지에서만 안내 |
| 데이터 | 보존기간, 삭제 요청 처리, 접근자와 감사 기록 | 정책·담당자 결정 및 구현 필요 |
| 장애·복구 | 복구 시간, 허용 유실량, 백업 복구 시험, 경보 수신자 | 목표·담당자 결정 및 실환경 시험 필요 |
| 소유권·승인 | GitHub·호스팅·DB·배포 키 소유자, 인수 승인자 | 기업과 확정 필요 |

## 8. Play Store 배포 전 추가 작업

현재 [Android 빌드 설정](../mobile-app/android/app/build.gradle.kts)은 release build에 debug signing을 사용한다. 따라서 위 APK는 내부 시연용이며 Play Store 운영 배포본으로 판정하지 않는다.

Play Store 전에는 다음을 완료한다.

1. 업로드 keystore 생성 및 안전한 별도 보관
2. `key.properties`와 keystore를 Git에서 제외
3. release signing config 적용
4. `pubspec.yaml`의 version/versionCode 확정
5. 개인정보처리방침, 데이터 보존·삭제 정책과 스토어 Data safety 작성
6. release AAB 빌드 및 실제 Android 기기 회귀 테스트

```powershell
flutter build appbundle --release --no-pub `
  --dart-define=VIBECARE_API_BASE_URL=https://api.example.com
```

## 9. 보안·데이터 완료 조건

`anon`은 예약과 측정 보기를 읽지 못한다. `authenticated`는 본인의 예약과 관리자가 연결한 참가자의 측정 기록만 RLS를 통해 읽는다. 나머지 비공개 `vibecare` 테이블의 방어 심층화는 별도 작업이다. 운영 전 [Supabase RLS 문서](https://supabase.com/docs/guides/database/postgres/row-level-security)에 따라 다시 검사한다.

추가 완료 조건:

- 트리거 함수의 고정 `search_path`
- 필요한 외래키 index 검토
- 개인정보 보존기간·삭제 요청·접근 감사 정책
- DB 백업과 복구 시험
- FITRUS 타임아웃·비정형 오류 시험
- 실제 사용자 데이터를 넣기 전 승인된 개발/운영 환경 분리

## 10. 롤백

- Flutter: 직전 검증 APK/AAB 버전으로 재배포한다.
- 백엔드: 직전 이미지 태그로 ECS/호스팅 release를 되돌린다.
- DB: 운영 데이터를 삭제하거나 migration을 역실행하지 않는다. 먼저 쓰기를 중단하고 백업·영향 범위를 확인한 뒤 forward-fix migration을 우선한다.
- 장애 중에는 `/ready`를 503으로 유지하고 새 Mock 세션을 시작하지 않는다.

## 11. 최종 배포 체크리스트

- [ ] 백엔드 typecheck·test·production dependency audit 통과
- [ ] Supabase secret이 호스팅 환경에만 존재
- [ ] `/health` 200, `/ready` 200 확인
- [ ] DB 장애 시 `/ready` 503 확인
- [ ] Flutter APK가 공개 HTTPS API를 사용
- [ ] 로그인→측정 4건→추천→Mock 시작→중지→피드백 통과
- [ ] `DEVICE_MODE=mock`, `REAL_DEVICE_ENABLED=false`
- [ ] APK·Git·로그에서 비밀값 미검출
- [ ] RLS·함수·index Advisor 재검사
- [ ] 실제 진동기 동작이 없음을 확인

위 항목이 모두 끝나기 전에는 “운영 배포 완료”라고 표시하지 않는다.
### 참여 홈 공지 게시

Supabase Dashboard의 Table Editor에서 `public.announcements`에 제목과 본문을 입력하고 `is_published=true`로 저장한다. `published_at` 이전이나 `expires_at` 이후의 공지는 참가자 화면에 보이지 않는다. 웹앱은 로그인 사용자에게 최근 게시 공지 5건을 보여주며, 참가자 계정에는 게시·수정 권한이 없다. 데이터베이스 변경 내역은 `deployment/supabase/003_announcements.sql`에 기록한다.
### Supabase Auth 회원가입 이메일

`Authentication → Sign In / Providers`에서 신규 가입과 이메일 인증 설정을 확인한다. 현재 프로젝트에서는 둘 다 켜져 있다. 확인 메일을 조직 멤버가 아닌 참가자에게 보내려면 Supabase 기본 발신 제한을 해제하는 **사용자 소유 SMTP 제공자의 호스트·포트·계정·비밀키와 발신 주소**를 `Authentication → Emails → SMTP Settings`에 설정해야 한다. 비밀키를 Git이나 Flutter 웹 빌드에 넣지 않는다. [Supabase SMTP 안내](https://supabase.com/docs/guides/auth/auth-smtp)를 따른다.
