# VibeCare 배포 Runbook

기준일: 2026-09-20

이 문서는 현재 저장소를 기준으로 Supabase 데이터베이스, VibeCare 백엔드 API, Flutter Android 앱을 배포하는 순서를 설명한다. 현재 제품은 연구용 Mock 시뮬레이터이며 실제 진동기 명령은 배포 대상이 아니다.

## 1. 현재 배포 상태

| 구성요소 | 상태 | 근거 |
|---|---|---|
| Supabase 프로젝트 | 완료 | `vibecare-pilot`, 서울 `ap-northeast-2`, `ACTIVE_HEALTHY` |
| 원격 DB schema | 완료 | 비공개 `vibecare` schema, `001_schema`, 활성 `pilot-0.9.0` 규칙 1건 |
| 원격 실사용 데이터 | 없음 | 참여자·측정·세션 행 0건 |
| 백엔드 코드 | 준비됨 | Node/Hono 진입점과 PostgreSQL adapter 구현 |
| 백엔드 호스팅 | 미완료 | 공개 HTTPS 주소, 운영 컨테이너와 배포 자동화 없음 |
| Flutter 내부 시연 APK | 빌드 가능 | API 주소를 `--dart-define`으로 주입 가능 |
| Flutter Web 공개 시연판 | 완료 | `https://dowon-kang.github.io/vibecare-pilot/`, 샘플·Mock 전용 |
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

Flutter가 Supabase에 직접 연결하지 않는다. DB 연결 문자열, DB 비밀번호, FITRUS API 키와 인증 토큰 비밀값은 백엔드 호스팅 환경에만 저장한다.

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

다른 사람이 설치 없이 UI를 확인할 수 있도록 GitHub Pages에 샘플·Mock 전용 Web 빌드를 게시한다.

```text
https://dowon-kang.github.io/vibecare-pilot/
```

공개판은 `VIBECARE_API_BASE_URL`을 주입하지 않는다. 따라서 Supabase 실사용 데이터, FITRUS API와 실제 장치에 접근하지 않는다. Web 산출물은 `/vibecare-pilot/` base href로 빌드해 별도 `gh-pages` 브랜치에 게시한다.

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

현재 `vibecare` schema에 대해 `anon`과 `authenticated`의 schema 사용권한과 참여자 조회권한이 없음을 확인했다. 하지만 Supabase Advisor는 14개 테이블의 RLS 비활성화를 경고했다. 운영 전에는 정책 설계 후 RLS를 방어 심층화로 활성화하고 [Supabase RLS 문서](https://supabase.com/docs/guides/database/postgres/row-level-security)에 따라 다시 검사한다.

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
