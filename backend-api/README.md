# VibeCare 백엔드 API

Flutter와 FITRUS·데이터베이스·기기 게이트웨이 사이의 보안 경계다. 공개 계약은 `../shared-contracts/openapi.yaml`을 따른다.

현재 요청 처리 코드는 D1 개발 런타임과 Node/PostgreSQL 런타임을 지원한다. `createApp()`과 `SqlDatabase` 포트 뒤에서 도메인·Route 코드를 공유한다. PostgreSQL 어댑터와 통합 스키마는 구현됐고, 현재 관리형 저장소 대상은 Supabase PostgreSQL이다.

`GET /health`는 프로세스 생존만, `GET /ready`는 안전 설정과 DB 연결 준비 상태를 확인한다. 모든 응답에는 `X-Request-Id`가 포함되고 요청 메타데이터는 JSON 한 줄 로그로 기록된다. PIN·토큰·요청 본문·FITRUS 원문은 로그에 남기지 않는다.

## 로컬 실행과 검증

### PostgreSQL 경로(공급자 중립)

Docker Desktop이 실행 중인 개발 PC에서 로컬 PostgreSQL을 시작한다.

```powershell
docker compose -f ../deployment/local/postgres/docker-compose.yml up -d
$env:DATABASE_URL='postgresql://vibecare:vibecare_dev_only@127.0.0.1:5433/vibecare'
$env:ENVIRONMENT='development'
$env:ALLOW_DEVELOPMENT_SEED='true'
$env:AUTH_TOKEN_SECRET='development-only-secret-at-least-32-characters'
$env:FITRUS_API_BASE_URL='https://api.thefitrus.com/fitrus-ml/measure'
$env:DEVICE_MODE='mock'
$env:REAL_DEVICE_ENABLED='false'
npm run db:migrate:postgres
npm run db:seed:postgres
npm run dev:postgres
```

개발 seed는 합성 데이터 `USER-001`/`123456`과 최근 BIA 4건만 만든다. 실사용 데이터나 운영 자격 증명이 아니다. Android 에뮬레이터는 다음처럼 PC의 서버를 사용한다.

```powershell
flutter run -d emulator-5554 --dart-define=VIBECARE_API_BASE_URL=http://10.0.2.2:8787
```

운영에서는 예제 비밀번호를 사용하지 않고 TLS와 배포 환경의 비밀 저장소를 통해 연결 문자열을 주입한다.

### Supabase PostgreSQL

Flutter는 Supabase DB에 직접 연결하지 않는다. 기존 경계를 유지한다.

```text
Flutter → VibeCare Hono API → Supabase PostgreSQL
```

Supabase Dashboard의 **Connect → Session pooler** 연결 문자열을 서버의 `DATABASE_URL`로만 주입한다. `.env.supabase.example`을 참고하되 비밀번호를 Git·APK·로그에 넣지 않는다. 장기 실행 Node 서버는 session pooler를 사용하고 TLS 인증서 검증을 유지한다. 애플리케이션 테이블은 Data API에 노출되는 `public`이 아니라 전용 `vibecare` 스키마에 생성하며, 서버 연결에만 `search_path=vibecare,public`을 적용한다. 스키마를 적용한 뒤 `npm run dev:postgres`로 같은 Node 진입점을 실행한다.

현재 앱은 자체 PIN 인증과 소유권 검사를 사용하므로 Supabase Auth·Data API를 Flutter에 추가하지 않는다. 공개 `anon` 키나 `service_role` 키도 Flutter에 넣지 않는다.

### Vercel Hono 배포

Vercel은 루트 [`server.ts`](./server.ts)를 Hono 진입점으로 자동 감지한다. 별도 `api/` Function이나 rewrite를 추가하지 않는다. 함수 지역은 Supabase 서울 리전과 가깝게 `icn1`로 고정하며, 서버리스 인스턴스별 연결 폭증을 줄이기 위해 `DATABASE_POOL_MAX=1`을 사용한다.

Vercel 프로젝트의 Root Directory를 `backend-api`로 지정하고 다음 값을 Preview·Production 환경변수로 등록한다. 실제 값은 Dashboard 또는 CLI의 비밀 입력을 사용하며 문서·Git에 기록하지 않는다.

```text
DATABASE_URL=<Supabase Connect의 서버 전용 pooler URI>
DATABASE_SCHEMA=vibecare
DATABASE_SSL=require
DATABASE_SSL_REJECT_UNAUTHORIZED=true
DATABASE_POOL_MAX=1
ENVIRONMENT=production
AUTH_TOKEN_SECRET=<32자 이상 임의 비밀값>
FITRUS_API_BASE_URL=https://api.thefitrus.com/fitrus-ml/measure
FITRUS_API_KEY=<서버 전용 FITRUS 키>
DEVICE_MODE=mock
REAL_DEVICE_ENABLED=false
ALLOWED_ORIGINS=<Flutter Web의 정확한 https origin>
APP_VERSION=<배포 버전>
```

배포 후 `GET /health`가 `200`, `GET /ready`가 `200`인지 순서대로 확인한다. `/health`만 성공하고 `/ready`가 `503`이면 서버는 살아 있으나 DB·비밀값·CORS·FITRUS 설정 중 하나가 준비되지 않은 상태다. 실제 장비 프로토콜 검증 전에는 `DEVICE_MODE=mock`, `REAL_DEVICE_ENABLED=false`를 바꾸지 않는다.

### D1 호환 개발 경로

Node.js와 npm이 준비된 PowerShell에서 이 폴더로 이동한 뒤 잠금 파일 그대로 의존성을 설치한다.

```powershell
cd backend-api
npm ci
Copy-Item .dev.vars.example .dev.vars
```

`.dev.vars`에는 개발 전용 FITRUS 키와 32자 이상의 임의 `AUTH_TOKEN_SECRET`을 넣는다. 예제 파일의 대체 문자열이나 실제 운영 비밀값을 커밋하지 않는다. FITRUS 호출을 검증하지 않는 경우에도 인증 서버를 실행하려면 유효한 길이의 개발용 `AUTH_TOKEN_SECRET`이 필요하다.

로컬 D1 스키마를 먼저 적용한다.

```powershell
npx wrangler d1 migrations apply vibecare-dev --local --config local-runtime.jsonc
```

현재 저장소에는 참여자·PIN 개발 seed가 없다. 따라서 migration만 적용한 새 DB에서는 `/health`와 `/ready`를 확인할 수 있지만 PIN 로그인부터 시작하는 백엔드 종단간 흐름은 자동 재현할 수 없다. 기존 데이터베이스나 승인된 별도 테스트 데이터가 없는 상태에서 문서가 임의 계정을 약속해서는 안 된다.

서버를 실행한다.

```powershell
npm run dev
```

Wrangler가 출력한 로컬 주소를 기준으로 `GET /health`는 프로세스 생존, `GET /ready`는 설정과 DB 준비 상태를 확인한다. 기본 Wrangler 포트를 사용하는 경우 예시는 `http://localhost:8787/health`와 `http://localhost:8787/ready`다. 포트가 출력값과 다르면 출력된 주소를 사용한다.

Android 에뮬레이터의 `localhost`는 개발 PC가 아니라 에뮬레이터 자신을 가리킨다. 기본 포트가 8787이라면 Flutter 앱의 백엔드 주소는 `http://10.0.2.2:8787`로 설정한다. 실제 Android 기기에서는 개발 PC의 동일 네트워크 IP와 방화벽 설정이 별도로 필요하다.

공개 HTTP 계약은 [`../shared-contracts/openapi.yaml`](../shared-contracts/openapi.yaml)에서 확인한다.

코드 변경 후 다음 검증을 실행한다.

```powershell
npm test
npm run typecheck
```

`DEVICE_MODE=mock`에서는 D1에 Mock 세션과 ACK를 남기지만 실제 장비로 전송하지 않는다. `real` 모드는 공급사 프로토콜이 구현되지 않았으므로 의도적으로 `501 DEVICE_PROTOCOL_NOT_CONFIGURED`를 반환한다.

FITRUS 요청은 `measure-api-guide.md`의 엔드포인트별 필드를 서버에서 검증한 뒤 전달한다.
`bodyFat` 응답은 상호 일관성 검사까지 통과하면 raw 원본과 `bia_measurements`에 함께 저장되고,
혈압·심박·스트레스·체온은 응답 계약을 통과하면 `vital_measurements`에 저장된다. 지원하지 않는
응답 구조와 `stress2.errorcode != 0`은 raw로만 남는다. 명세에 없는 단위와 근육량의 ASM/SMM
측정 근거는 서버가 추정하지 않는다.
