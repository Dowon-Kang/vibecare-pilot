# 개선 작업·운영 절차·완료 조건

아래는 [추론]에 해당하는 제안이다. 실제 코드 수정·배포·장비 실행은 이번 분석에서 수행하지 않았다. 시간·비용 추정치나 미확정 외부 계약을 임의로 채우지 않았다.

## 우선순위와 독립 작업 분해

| 작업 | 목표 | 수정 가능 범위 | 수정 금지 범위 | 선행 작업 | 산출물 | 검증·완료 조건 | 충돌/독립성 |
|---|---|---|---|---|---|---|---|
| T-01 최우선 | I-01 멱등권한누락차단 | services/api/src/index.ts 세션경로·services/api/test 신규route시험 | Flutter·규칙계수·운영DB | 없음 | 소유자/요청결합검사·회귀시험 | 다른참여자·다른본문충돌거절;동일요청재시도같은세션 | T-03/04도index.ts수정하므로직렬 |
| T-02 최우선 | I-02 명시문진게이트 | Flutter models/controller/screen/test | Worker·계수·DB | design문진규약유지확인, 현규약대로구현가능 | 미확인상태·3문항UI·차단시험 | 미응답명령0건,위험BLOCKED,재로그인/세션갱신문진초기화 | T-01과독립;T-05/07은Flutter파일충돌 |
| T-03 우선 | I-03/04 검증·규칙중단일치 | worker algorithm/index·tests;Dart domain/tests;lib·fixtures | 기기실출력·임상계수임의변경 | T-01종료,T-02모델계약고정 | canonical검증·disabled거절·공통fixture | 모든엔진경계결과합의,활성룰없음허가0건 | 여러엔진소유범위라T-02/04동시금지 |
| T-04 우선 | I-06/07 서버세션상태정리 | services/api/index·신규migration·route시험·device계약 | 기존migration변경·물리출력 | T-01/03, source/target기기계약 | 기기lease·상태전이·종료이력·조회API | 기기별활성1개,중복/경쟁/완료일관성 | Worker변경과충돌,직렬 |
| T-05 우선 | I-05/11 중지·인증복구 | Flutter controller/gateway/auth/UI/tests | 계수·Worker비승인API | T-02/04계약·T-03모델안정 | stopFailed·재중지·refresh·세션복원 | 오류후중지CTA유지,만료·background·재시작검증 | Flutter개편과직렬 |
| T-06 계약 | FITRUS 정규화구현 | fitrus-client·새adapter·contracts·services/api/test·새migration | 공급사미확정필드가정·실키fixture | 공급사성공계약·단위·품질정의 | 비식별fixture·ingest·canonical검증 | 실예제4건이schema통과,중복/오류/본인권한시험 | index.ts연결은T-04후;사전명세수집은독립 |
| T-07 제품 | 프로필/기기/피드백완성 | Flutter repos/controller/screen·Worker신규API·contracts | 임상기준·기존데이터삭제 | T-04/05/06·역할/기기정책확정 | 프로필원천·source/targetID·평가UI | 로그인→실정규화→추천→Mock→평가E2E | Worker/Flutter양쪽충돌,기능별직렬 |
| T-08 운영 | clean빌드·서명·환경·CI | 별도CI/도구·새env설정·Android signing·운영문서 | secret커밋·프로덕션임의배포 | 목표환경·담당자,SDK확정 | 빌드/배포런북·SBOM·서명·artifact해시 | clean설치/빌드/회귀·stagingrestore성공 | 앱소스변경과대체로독립,의존성업데이트는별도합의 |
| T-09 검증 | 실기기계약·교정·ACK검증 | 새Device adapter·계약시험·교정자료 | 명세없는실출력활성화 | 공급사명세,T-04~07안정,안전승인 | 장비별교정·timeout/stop·제한시험결과 | 물리중지·연결해제·최대출력기준통과 | 선행결과의존,독립작업아님 |
| T-10 정리 | I-14/17/18 웹표현·접근성·캐시·문서 | app/page.tsx·globals.css·public/sw.js·기존문서 | Flutter/Worker계수·호스팅identity | Mock/미리보기표현합의,T-03웹모델안정 | 상태표시·캐시정책·검증기록 | 위험우선·큰글자·키보드·오프라인검사 | T-03과파일충돌;안정후T-08과독립 |

동일 index.ts 또는 PilotController를 수정하는 작업을 독립이라고 분류하지 않았다. T-06의 공급사자료 수집, T-08의 환경정의, 사용성 시험설계는 핵심코드수정과 별도로 준비할 수 있다. 이번에는 하위 에이전트나 별도 작업을 실행하지 않았다.

## 단계별 완료 게이트

1. **Mock 내부검토**: I-01~05·기본계약수정, 명시문진, 기존/회귀시험통과, Mock표현명료. 코드가있다는이유만으로완료하지않음.
2. **서버 연결 파일럿**: clean설치·participant provision·정규화·D1·HTTP E2E·refresh·피드백·삭제/백업·장애시험. 실장비는여전히별도.
3. **제한된 실장비 시험**: 장비·교정·ACK·통신단절정지·기기별lease·안전책임자확인. 계수효능을기술시험으로대체하지않음.
4. **운영 릴리스**: Critical/High0건 또는범위축소로해소증명, 승인수용시험,서명·환경·관측·복원/롤백,알려진제약기록.

## 반복 가능한 로컬 절차

명령은 PowerShell 기준이다. 표시된경로는이번PC의실제경로다. 새PC에서는루트/SDK를설치위치로치환한다. `[기존 구현]` 명령과 `[제안/미검증]` 운영절차를구분한다. 명령을문서에적었다고실행됐다는뜻은아니다.

### 개발 환경과 의존성

```powershell
Set-Location 'E:\산학협력\vibration-control-app'
git status --short
node --version
npm ci
Set-Location worker
npm ci
Set-Location ..\apps\mobile
& E:\flutter-sdk\bin\flutter.bat --version
& E:\flutter-sdk\bin\flutter.bat doctor -v
& E:\flutter-sdk\bin\flutter.bat pub get
```

[기존 구현] 각lockfile이존재한다. [미검증] 이번에는기존node_modules/pub cache를사용했다. `npm ci`는node_modules를재구성하므로현재열린개발작업에서무심코실행하지말고새checkout/CI에서먼저검증한다. Android SDK와Java를설정하지않은환경에는doctor결과에따른설치가필요하다.

### 환경변수와 Mock 앱

```powershell
Set-Location 'E:\산학협력\vibration-control-app\apps\mobile'
$env:GRADLE_USER_HOME='E:\산학협력\.gradle-cache'
$env:TEMP='E:\codex-flutter-temp'
$env:TMP='E:\codex-flutter-temp'
& E:\flutter-sdk\bin\flutter.bat run
```

API URL을생략하면Mock다. 해당TEMP폴더와E:\vibecare-pilot junction은이PC에이미존재했다. 다른PC에이경로가있다고가정하지않는다. 현재Mock계정은로그인UI에명시돼있고운영PIN이아니다.

서버연결개발(실제staging HTTPS URL로설정해야함):

```powershell
& E:\flutter-sdk\bin\flutter.bat run --dart-define=VIBECARE_API_BASE_URL=https://api.example.invalid
```

위URL은저장소와같은의도적placeholder로실행가능한서버가아니다. 제공된staging주소로교체해야한다. 현재클라이언트는localhostHTTP/cleartext정책을별도로설정하지않으므로장치에서PC localhost로연결되는것을가정하지않는다.

### 웹·Worker 실행

```powershell
Set-Location 'E:\산학협력\vibration-control-app'
npm run dev
# 다른 터미널에서 응답 확인
Invoke-WebRequest http://localhost:3000 -TimeoutSec 30
```

```powershell
Set-Location 'E:\산학협력\vibration-control-app\worker'
# .dev.vars가 없는 새 개발환경에서만 템플릿 복사
if (-not (Test-Path -LiteralPath '.dev.vars')) {
    Copy-Item -LiteralPath '.dev.vars.example' -Destination '.dev.vars'
}
npm run dev
```

실행전 `.dev.vars`의 AUTH_TOKEN_SECRET을개발전용무작위32자이상으로직접설정한다. FITRUS실호출이필요없으면실키를넣지않는다. 템플릿값을운영secret으로사용하면안된다. 디바이스모드는현재wrangler설정의mock를유지한다. Worker dev 실행은이번분석에서전체앱으로재검증하지않았다.

### 테스트·타입·빌드

```powershell
Set-Location 'E:\산학협력\vibration-control-app'
node --test app/lib/vibration-algorithm.test.mjs
.\node_modules\.bin\tsc.cmd --noEmit --incremental false
npm run lint
npm run build
Set-Location worker
npm test
npm run typecheck
```

```powershell
Set-Location 'E:\vibecare-pilot\apps\mobile'
$env:TEMP='E:\codex-flutter-temp'
$env:TMP='E:\codex-flutter-temp'
& E:\flutter-sdk\bin\cache\dart-sdk\bin\dart.exe analyze
& E:\flutter-sdk\bin\flutter.bat test --no-pub
& E:\flutter-sdk\bin\dart.bat --enable-asserts tool\verify_algorithm.dart
```

```powershell
# Android 빌드: 이번에는 재실행하지 않았고 기존절차에서 복원
$env:GRADLE_USER_HOME='E:\산학협력\.gradle-cache'
& E:\flutter-sdk\bin\flutter.bat build apk --debug
& E:\flutter-sdk\bin\flutter.bat build apk --release
& E:\flutter-sdk\bin\flutter.bat build appbundle --release
```

현재release도debug서명이다. 위명령성공은운영서명·스토어준비완료를의미하지않는다. `dart --enable-asserts`는assert생략을방지한다.

분석전용재현:

```powershell
Set-Location 'E:\산학협력\vibration-control-app'
node docs/project-analysis/evidence/probe-worker.mjs
node docs/project-analysis/evidence/probe-workerd.mjs
python docs/project-analysis/evidence/probe-contracts.py
```

Python검사는jsonschema4.25.1을사용했다. 이패키지는프로젝트배포의존성에없으므로재현환경에서별도준비해야한다. Node검사는설치된typescript/Hono/Zod/Miniflare를활용한다. Workerprobe통과는결함이존재함을재현한경우도포함한다.

### DB 초기화

```powershell
Set-Location 'E:\산학협력\vibration-control-app\worker'
npx wrangler d1 migrations apply vibecare-dev --local
npx wrangler d1 execute vibecare-dev --local --command "SELECT name FROM sqlite_master WHERE type='table';"
```

[기존 문서 절차/이번 실제D1 미실행] 기존DB를지우지않는migration적용명령이다. 빈DB에12개업무테이블과규칙seed만생기며참여자·PIN·BIA는생기지않는다. 그래서현저장소만으로서버로그인까지자동초기화하는완전한명령은없다. T-06/07에서`hashPin`을사용하는검증된개발seed/provision도구가필요하다. 임의평문PIN을SQL에넣어대체하지않는다.

### 배포 준비와 실행

[제안/미검증] 업무Worker는실제D1 ID·독립staging설정·secrets·백업·서명/권한검증이준비돼야한다. 다음은운영담당자용명령형태이며현재placeholder환경에그대로실행하는완료절차가아니다.

```powershell
Set-Location 'E:\산학협력\vibration-control-app\worker'
npx wrangler whoami
npx wrangler d1 list
npx wrangler secret put AUTH_TOKEN_SECRET
npx wrangler secret put FITRUS_API_KEY
# 정확한 환경과 DB ID, 백업 및 migration 검토가 끝난 뒤에만 실행
npx wrangler d1 migrations apply vibecare-dev --remote
npx wrangler deploy
```

명령의vibecare-dev는현재설정이름이다. prod/staging을새로구성하면정확한이름과`--env`를사용해야한다. 현재env별블록은없다. 실제secret값은터미널프롬프트/플랫폼secret관리로주입하고스크립트·문서·Git에적지않는다.

웹Sites배포는별도hosting.json기존프로젝트를유지하며Sites버전저장/배포절차로진행해야한다. 웹빌드와업무Worker배포를한명령으로묶는현스크립트는없다. 이번에는배포나공유설정을바꾸지않았다.

### 로그·장애 대응

```powershell
Set-Location 'E:\산학협력\vibration-control-app\worker'
npx wrangler tail
npx wrangler d1 execute vibecare-dev --local --command "SELECT status,COUNT(*) AS count FROM device_sessions GROUP BY status;"
npx wrangler d1 execute vibecare-dev --local --command "SELECT version,enabled,active_from FROM algorithm_rule_sets;"
```

`tail`은배포계정/권한이필요하며이번미실행이다. 조회예시는개인정보본문을출력하지않는로컬상태집계다. 운영조회는필요권한과환경을확인해전환한다.

1. 증상을 인증/조회/허가/시작/중지 중 어느단계인지기록하고실장비가있다면제조사독립정지절차를우선한다.
2. health200만으로DB·FITRUS·장치정상이라고판단하지않는다. 요청시간·세션ID·오류코드를확인하되PIN/key/raw건강데이터는공유로그에서제외한다.
3. 현재규칙전체disabled는중지장치가아니다(I-04). 미해결상태에서이를운영긴급중단으로믿지않는다. 실제출력adapter는현재없다.
4. 서버와앱세션불일치가있으면중복시작보다상태재조회를우선할수있도록T-04/05를구현한다. 현API에는전용session GET이없다.
5. 데이터수정·복원은원본보존과승인된운영절차에따라실시한다. 현재자동복구명령은없다.

### 롤백

```powershell
Set-Location 'E:\산학협력\vibration-control-app\worker'
npx wrangler deployments list
npx wrangler versions list
# 정상 버전과 DB 호환성을 확인한 운영자가 입력. 이번에는 실행하지 않음
$verifiedVersionId = Read-Host '확인된 정상 Worker version ID'
npx wrangler rollback $verifiedVersionId
```

[제안] 실제 정상 버전과 DB 호환성 확인 후 플랫폼 도구로 롤백한다. Worker 버전 롤백은 D1 schema/데이터를 자동 복구하지 않는다. 현재 down migration·백업검증·restore 런북이 없으므로 DB 롤백을 재현 가능하다고 주장할 수 없다. 앱은 동일 서명 체계·배포경로·호환 API를 확인한 이전 정상 artifact가 필요하다. 기존 debug 서명 APK를 운영 롤백 기준으로 가정하지 않는다.

## 자동화 후보

- `verify.ps1` 또는CI: 웹test/type/lint/build→Worker test/type→Flutter analyze/test. 실행환경이안정된뒤추가하며현재lint실패를먼저해소한다.
- 공통fixture generator/contract CI: 세엔진결과·nullable DTO·OpenAPI를같은입력으로검사. 단순기대값복제시험을피한다.
- 깨끗한D1 test harness: migrations→합성participant/PIN/BIA→정상/인가/경쟁/오류→폐기. 운영binding을사용하지않는다.
- release pipeline: SBOM·라이선스/취약점검사·production signing·commit해시·artifact해시·staging E2E·승인후배포.
- 인수점검용Skill은위절차와책임자가고정된뒤후보로만검토한다. 이번에는Skill/자동화/CI를신설하지않았다.
