# 검증 결과·추적표·문제 목록

## 기준점과 실행 범위

[사실] 분석 기준 HEAD=`987926cae3f60cfbcd48d66d89d0726a89674fe7` (`Build mobile-first VibeCare pilot flow`). 이전 커밋 제목은 `Build VibeCare vibration calculator experience`. 추적 파일88개. 시작 시 추적 소스 변경은 없었고 끝에도 `git diff --exit-code`가 통과했다. 신규 산출물은 docs/project-analysis 아래다.

이번 실행은2026-09-07 로컬 환경에서 진행했다. 의존성이 이미 설치되어 있어 재설치하지 않았다. 앱 코드를 수정하지 않았으며 실사용자/실키/운영DB/공급사API/물리장비를 테스트에 사용하지 않았다.

## 명령과 결과

| 작업 디렉터리 | 실행 명령 | 결과·해석 |
|---|---|---|
| 저장소 | `git status --short`, `git ls-files`, `git log -5 --format="%h %s"`, `git rev-parse HEAD` |88개 추적파일과 두 커밋 조사; 기존 미추적 산출물 보존 |
| 상위 작업 폴더 | `rg --files`에 프로젝트/지침/manifest 필터 | 일부 LibreOffice 임시폴더 접근 거부. 이후 주 저장소로 조사 한정 |
| 저장소 | `node --version` | v22.19.0 |
| 저장소 / worker | `npm ls --depth=0` | 둘 다 종료0; 선언 외 extraneous 패키지 다수. 깨끗한 npm ci 재현은 미검증 |
| 저장소 | `npm run lint` | 실패: no-base-to-string2건. backend-api/src/index.ts:120, backend-api/test/fitrus-client.test.ts:9 |
| 저장소 | `node --test app/algorithm/vibration-algorithm.test.mjs` | 처음 sandbox spawn EPERM. 자식 프로세스 실행 허용 후5/5 통과 |
| 저장소 | `.\node_modules\.bin\tsc.cmd --noEmit --incremental false` | 종료0,진단없음. 소스 typecheck 통과 |
| worker | `npm test` | 처음 esbuild spawn EPERM. 실행 허용 후3파일8/8 통과(계산4,인증2,FITRUS2) |
| worker | `npm run typecheck` | 종료0,진단없음 |
| 저장소 | `npm run build` | 종료0, Vinext5단계 빌드 성공. route `/`가 Unknown으로 표시되는 정적 분류 안내, 플러그인 시간 안내 존재 |
| E:\vibecare-pilot\apps\mobile | TEMP/TMP 지정 후 `E:\flutter-sdk\bin\cache\dart-sdk\bin\dart.exe analyze` | No issues found |
| 같은 경로 | `E:\flutter-sdk\bin\flutter.bat test --no-pub` |10/10 통과. 도메인5·위젯5,320×568 포함 |
| 저장소 | `npm run dev -- --host 127.0.0.1 --port 5187` | 기존 localhost:3000 서버/PID 발견으로 종료1. 기존 서버를 중단하지 않음 |
| 저장소 | `Invoke-WebRequest http://localhost:3000 -TimeoutSec 30` |200, 응답길이40274, VibeCare 문자열 확인. 최초 결과 가공은 PowerShell 제한모드 PSCustomObject 오류, 단순출력으로 재확인 |
| 저장소 | `node docs/project-analysis/evidence/probe-backend-api.mjs` | 종료0. 실제 Hono+메모리SQLite 검사8묶음. 정상 인증/잠금/조회/stop/feedback과 결함 재현. 운영D1 시험 아님 |
| 저장소 | `node docs/project-analysis/evidence/probe-cloudflare-runtime.mjs` | 최종 종료0, `{pbkdf2Iterations:120000,ok:true}`. Worker용 Miniflare5 converter 사용 |
| 저장소 | `python docs/project-analysis/evidence/probe-contracts.py` | schema4개 문법·fixture rule·BIA4건 통과. API형 null BIA/vital 응답은 각각 거부 재현 |
| 저장소 | `git diff --exit-code` | 추적 소스·설정·테스트 변경 없음 |

workerd 검사 준비 중 웹용 Miniflare4의 지원날짜가2026-05-22까지여서 Worker 날짜2026-09-03으로 시작하지 못했다. 이후 업무 Worker의 설치된 Miniflare5 alpha로 바꿨고 API 형태 차이를 로컬 타입선언의 `convertV4MiniflareOptions`로 해결했다. 이는 검사 도구 준비 과정이며 현재 업무 Worker의 PIN 인증 실패로 기록하지 않는다.

## 검증하지 않은 항목

- [확인 필요] 새 환경 npm ci/pub get/Android SDK 설치. 기존 설치의 성공과 clean install은 다르다.
- [확인 필요] 이번 Android APK/AAB 재빌드·에뮬레이터/물리기기 실행. 기존 toolchain-status와 파일 존재/크기는 확인했으나 현재 소스 바이너리라고 검증하지 않았다. release APK는2026-09-06 생성51046200bytes로 후속 소스보다 오래될 수 있다.
- [확인 필요] 전체 Worker를 실제 workerd+D1에서 로그인→정규화→추천→세션→피드백 E2E. 이번 SQL 어댑터는 D1 concurrency/제한을 모사하지 않는다.
- [확인 필요] 브라우저 클릭/200% 확대/키보드·TalkBack/오프라인·ACK 장애·물리 긴급정지.
- [확인 필요] 취약점 DB 감사, 공급사 성공응답·rate limit·SLA·운영secret·TLS·backups·restore·rollback.

## 요구사항 추적표

상태는 요청받은 다섯 값만 쓴다. “확인 완료”는 해당 명시 범위이며 제품 전체 완료를 의미하지 않는다.

| 요구사항 ID | 요구사항 | 구현 파일 | 테스트 | 검증 결과 | 상태 | 남은 문제 |
|---|---|---|---|---|---|---|
| FR-001 | PIN 인증·잠금 | auth.ts,index.ts,auth_repository.dart | Worker auth2+격리routes | 정상인증/5회잠금 재현 | 부분 확인 | 실제D1·앱 오류표시·발급 |
| FR-002 | 토큰 생명주기 | auth/refresh,SessionStore | auth2+격리refresh | API갱신200;앱 미연결 | 부분 확인 | 자동갱신·revoke |
| FR-003 | 최신 유효4건 | fitrus_repository,algorithm,index | Dart선택+격리조회 |20불량 뒤 유효4건 가려짐 | 부분 확인 | I-08,I-09 |
| FR-004 | 평균·정합성 | 세엔진 | 기본계산+격리모순입력 | 정상예제 통과,서버모순 READY | 부분 확인 | I-03,I-10,I-16 |
| FR-005 | 명시 문진 | SafetyDraft/SafetyCheck/UI | 기존위젯+정적검토 | Flutter 무문진 시작 | 부분 확인 | I-02,I-14 |
| FR-006 | 기본 파일럿수식 | 세엔진 | 웹5/Worker계산4/Dart5 중계산 | 선택예제38/45·BMI검토 통과 | 확인 완료 | 임상성능·전체경계 parity 별도 |
| FR-007 | 수동하향 | updateIntensity/applyRequestedIntensity | Worker/위젯 | 감소·복원·범위거절 통과 | 확인 완료 | 실HTTP E2E |
| FR-008 | 서버허가 | authorize/BackendDeviceGateway | 격리routes·정적 |60초 허가코드,정상201 | 부분 확인 | I-03,I-04,profile drift |
| FR-009 | 세션·멱등성 | sessions/MockGateway | 위젯·격리routes | 정상작동,정보반환·중복결함 | 부분 확인 | I-01,I-06 |
| FR-010 | 중지·완료·장애 | stopSession/gateway/stop | 위젯·격리stop | 정상중지통과,실패UI결함 | 부분 확인 | I-05,I-07 |
| FR-011 | 사후평가 | feedback route | 격리upsert | API200,앱없음 | 부분 확인 | 앱기능·이력보존 |
| FR-012 | FITRUS정규화 | proxy/client | fetch double2 | 원본프록시만 | 부분 확인 | 정규화 부분 미구현 |
| FR-013 | vitals표시 | _VitalsList,/vitals | 위젯상세·schema검사 | 표시가능,계약불일치 | 부분 확인 | I-10·공급사단위 |
| FR-014 | 승인규칙·중단 | loadRuleSet/migration | 격리disabled | 전체비활성시 허가201 | 부분 확인 | I-04 |
| FR-015 | 실장비·교정 | real501 분기 | 정적검토 | 실행 adapter없음 | 미구현 | 공급사·장비명세 |
| FR-016 | 웹 비교·접근성 | page/css/sw | 웹단위·빌드·HTTP | 렌더응답만 확인 | 부분 확인 | 브라우저흐름·I-14/I-18 |

## 문제 목록

Critical=보안·데이터손실·실행불가, High=핵심동작 오류, Medium=유지보수·확장, Low=정리·일관성. 위험 영향은 코드에 근거한 추론이며 발생 사실과 구분한다.

### I-01 · Critical · 다른 참여자의 세션 정보 반환

- **근거 [사실]**: `backend-api/src/index.ts` POST /v1/device-sessions의 기존키 조회는 idempotency_key만 조건으로 사용하고 소유자·authorization/device 비교 전에 응답한다. 격리 검사 cross-participant-idempotency에서 B가 A의 command.participantId를200으로 받았다.
- **영향 [추론]**: 키를 알고 있거나 유출된 경우 타인의 세션ID·추천강도·참여자/기기 식별자가 노출된다. 임의의 모든 세션 열람이 가능하거나 stop 인가도 우회된다는 뜻은 아니다. stop은 타인404를 확인했다.
- **재현**: A로 세션 생성 후 B access token으로 같은 키와 임의 authorizationId/deviceId POST. `node docs/project-analysis/evidence/probe-backend-api.mjs`.
- **권장**: 소유자 범위 내 멱등 조회, 동일 요청 fingerprint 확인, 다른 사용자/다른 본문 충돌 거절. DB unique 정책·회귀 테스트 동시 정비.

### I-02 · High · Flutter 안전문진 생략 가능

- **근거 [사실]**: models.dart SafetyCheck 기본false, PilotController.login에서 기본값 적용, _SafetySettings는 체크박스, _PrimaryActionBar는 문진완료 여부 미검사. 위젯의 전송/시작 시험은 문진을 하지 않는다. design.md §4와 충돌.
- **영향 [추론]**: 증상 미확인 참여자가 정상으로 표시된다. 현재 물리출력은 없으나 파일럿 절차의 안전 확인 실패.
- **재현**: Mock 로그인→설정 미열람→장치로 보내기→진동 시작.
- **권장**: 미확인/예/아니요 모델, 모든 응답·작성시간·작성자 확인, 로그인/새 세션 초기화, 서버계약에 완료 증거 포함.

### I-03 · High · 서버 안전 재계산의 검증 누락

- **근거 [사실]**: Worker algorithm.ts는 유한양수·품질·ID검사만 하고 Flutter/웹의 BMI·체지방 일관성 검사 없음. fatMass1kg/weight45kg/bodyFat25%가 READY 재현.
- **영향 [추론]**: 변조/불량 DB 입력에서 서버 안전 경계가 앱보다 느슨하다. 기본 예제 parity는 이를 잡지 못한다.
- **재현**: probe-backend-api의 inconsistent-body-fat-server. BMI만20으로 올려 불일치 입력도 동일 경로 검토.
- **권장**: 동일 canonical 검증·단위/범위·profile validation을 서버와 Dart에 적용, 경계값·모순값 공통 fixture.

### I-04 · High · 전체 규칙 중단이 작동하지 않음

- **근거 [사실]**: loadRuleSet은 활성행 없으면 defaultRuleSet(enabled:true) 반환. JSON enabled·approved_by를 검증하지 않음. Dart 엔진도 enabled 미사용. SQL enabled를 전부0으로 바꾼 격리DB에서 허가201 재현.
- **영향 [추론]**: 운영자가 모든 규칙을 끄면 중지될 것으로 기대할 때 허가가 계속됨.
- **재현**: probe-backend-api all-rules-disabled.
- **권장**: 미설정/비활성 상태에서 거부, Mock fixture fallback과 서버 운영분리, 룰 구조·상호범위·승인 검증.

### I-05 · High · 중지 실패 후 중지 버튼과 추적 상실

- **근거 [사실/정적]**: PilotController.stopSession은 먼저 timer 취소. BackendDeviceGateway.stop 실패는 error emit. isRunning은 deviceState==running만 검사. CTA는 session 존재와 관계없이 isRunning=false면 전송으로 돌아가고 sendToDevice는 session이 남아 조용히 return. logout은 stop 실패도 state clear.
- **영향 [추론]**: 원격 세션 잔류 시 사용자가 재중지를 요청할 정상 경로를 잃음. 실물 동작은 시험하지 않음.
- **재현 제안**: BackendDeviceGateway /stop 네트워크 오류 주입, stop CTA 유지·session 보존 여부 검사. 현재 스위트에 이 시험 없음.
- **권장**: stopping/stopFailed와 activeSession을 분리, 재중지 CTA 유지, 서버조회·watchdog·미확인정지 처리, stop실패시 로그아웃 정책 정의.

### I-06 · High · 같은 기기에 여러 활성 세션

- **근거 [사실]**: DB unique는 authorization_id/idempotency_key만 있다. 별도허가2개로 같은 기기에 RUNNING2개 생성 재현.
- **영향 [추론]**: 재시도·여러클라이언트에서 기기별 실행 독점 불보장. 현재 가짜ACK/DB상태 문제이며 미래 물리경로에도 전달될 위험.
- **재현**: probe-backend-api two-active-sessions-one-device.
- **권장**: 장비 registry·활성lease·원자적 획득/해제, 허가소비 race를409로 매핑, 동시 요청 시험.

### I-07 · High · 세션 완료가 서버 상태에 반영되지 않음

- **근거 [사실]**: /events의 COMPLETED는 이벤트 insert만, session RUNNING 유지 재현. /stop은 reason=completed도 STOPPED; completed_at 갱신 없음. 서버 타이머도 없음.
- **영향 [추론]**: 실제 완료·중단·통신단절을 이력에서 구별하기 어렵고 앱 종료 후 RUNNING 잔류.
- **재현**: 시작 후 COMPLETED 이벤트→DB status 확인. probe-backend-api에 포함.
- **권장**: 허용 상태 전이·종료시간·종료사유 일원화, 서버 watchdog·상태조회, 피드백 연결.

### I-08 · High · 최신 불량20건이 유효 과거4건을 가림

- **근거 [사실]**: measurement-set/current는 LIMIT20 후 JS filter; authorize의 currentRows는 SQL filter 후 LIMIT4. 유효4건 앞에 불량20건을 삽입하면 조회 selected=[] 재현.
- **영향 [추론]**: 유효 자료가 있어도 앱은 실행불가, 조회와 허가의 세트 선택이 불일치.
- **재현**: probe-backend-api twenty-invalid-new-records.
- **권장**: 동일 선택 함수를 정의하고 유효 조회와 원본 history pagination 분리. 같은 시각 tie-breaker 포함.

### I-09 · High · 기기ID 및 프로필 원천 불일치

- **근거 [사실/정적]**: BackendFitrusRepository.loadSnapshot(deviceId)는 query를 보내지 않음. PilotController.deviceId는 FITRUS-PLUS-01 고정. updateProfile은 로컬만 바꾸고 authorize는 D1 프로필을 사용한다.
- **영향 [추론]**: 다른 최신BIA기기 자료 선택 후 고정ID 허가409. 나이/성별 편집 뒤 서버추천과 충돌 가능. BIA와 진동기 ID 분리도 불가능.
- **재현 제안**: 고정ID 외 기기의 최신4건을 넣고 로그인→전송; 서버 프로필72세여성에서 앱만남성 변경→전송. 실제 HTTP Flutter E2E는 미실행.
- **권장**: sourceBiaDeviceId/targetDeviceId 분리, 조회쿼리일치, server profile을 읽기전용 또는 승인저장 API로 변경.

### I-10 · Medium · 공개 데이터계약과 응답 불일치

- **근거 [사실]**: BIA nullable 선택값·vital participantId 누락·fatMass0 기준이 schema와 다름. probe-contracts에서 실제 응답형식의 합성데이터 거부 확인.
- **영향 [추론]**: strict client/DTO 생성 도입 시 기존응답 실패, 새 공급사 연동 시 drift.
- **재현**: `python docs/project-analysis/evidence/probe-contracts.py`.
- **권장**: null/생략 정책·단위·수치범위·완전한 OpenAPI response schema를 정하고 양방향 계약시험.

### I-11 · High · 앱 인증 갱신·오류 복구 부재

- **근거 [사실/정적]**: refresh token을 저장하지만 읽거나 /refresh를 호출하는 코드 없음. access는900초; 일반 Dio error는 일반안내. server logout/revoke 없음.
- **영향 [추론]**:15분 이후 조회·허가·중지가401일 수 있고 중지실패 I-05로 이어질 수 있음.
- **재현 제안**: 만료 access를 주입해 조회·stop 실행; 자동refresh 호출 없음 확인.
- **권장**: 단일진행 refresh interceptor·만료복구·서버폐기/재로그인·중지 우선정책, 실패시 의미있는 안내.

### I-12 · High · 실제 데이터 유입·피드백 흐름 미완성

- **근거 [사실]**: FITRUS raw만 insert. BIA/vitals/participant 생성 API 없음. session-feedback은 앱 호출 없음.
- **영향 [추론]**: 빈 D1으로는 참여자 로그인/실측추천을 재현할 수 없고 사용자평가가 수집되지 않음.
- **재현**: 빈 migration DB 테이블·호출부 조사. API POST 후 normalized:false 반환 구조.
- **권장**: 공급사 계약 후 정규화와 참가자 provision, 테스트 seed, feedback UI. 계약 없이 임의 공급사 필드 해석 금지.

### I-13 · Medium · release/배포 재현성 부족

- **근거 [사실]**: D1 ID placeholder, release debug서명, 환경별설정·CI 없음. 기존APK는 후속수정 이전 생성. npm ls extraneous 다수.
- **영향 [추론]**: 로컬설치 의존·잘못된환경·오래된APK 배포 가능.
- **재현**: cloudflare-local-runtime.jsonc, Android buildTypes.release, 산출물시각, npm ls 비교.
- **권장**: clean CI·SBOM·staging/prod·서명secret·commit/build metadata·롤백 시험.

### I-14 · Medium · Mock/실제 및 위험 표시 혼동

- **근거 [사실]**: Flutter 로그인에만 Mock 안내, dashboard는 API데이터4건수신·전송완료 표현. gateway.connect는 health만 검사. 웹은 calculation(safeAnswers) 추천을 표시하고 미응답시REVIEW를우선한다.
- **영향 [추론]**: 실제 공급사동기화·물리전송으로 오해하거나 위험응답이 덜 명확하게 보일 수 있음.
- **재현**: Mock로그인 뒤dashboard; 웹 한문항위험+다른문항미응답의 상태 계산. 브라우저 시각 재현은미실행.
- **권장**: 데이터source/장치mode 지속표시, 허가와전송의 용어구분, 위험상태우선·미리보기정책일치.

### I-15 · Medium · 외부 호출·데이터 관리 정책 부족

- **근거 [사실]**: FITRUS timeout/retry·payload상한·canonical validation·retention없음. snapshot은vitals오류도전체실패. 공통500만 반환.
- **영향 [추론]**: 무한대기성지연·비용/저장증가·장애전파·복구곤란.
- **재현 제안**: fetch지연/429/nonJSON/잘못된units 주입, large payload 제한 확인.
- **권장**: 공급사합의 timeout·크기제한·오류계약·선택데이터부분성공, 보관/삭제·백업정책.

### I-16 · Medium · 엔진3개·규칙/fixture 중복

- **근거 [사실]**: JSONfixture를 기존테스트가 직접읽지 않음. 웹은 중복ID를 거부하지 않고 optional7개도 필수로 취급. Dart optional NaN은 평균 반올림에서 예외 가능; enabled무시.
- **영향 [추론]**: 같은버전이라도 데이터·오류조건에 따라 서로 다른 승인 결과.
- **재현 제안**: 공통fixture에 duplicateID/null/NaN/disabled/소수Hz/경계BMI 추가하여세엔진비교.
- **권장**: canonical fixture 직접소비, 언어별adapter·차이허용목록 명시, 규칙 단일배포원천.

### I-17 · Low · 린트와 진행 문서 불일치

- **근거 [사실]**: lint2오류. 체크리스트의 Flutter규칙동기화·서버필드비교미완료 표시와 이미존재하는 코드, 옛 system-design 검증대기표 사이 차이.
- **영향 [추론]**: 인수자에게 현재작업범위가 불명확하고 CI기준이흐려짐.
- **재현**: npm run lint, 관련문서와 BackendDeviceGateway/BackendFitrusRepository 대조.
- **권장**: typed DB row·fetch input 처리, 완료범위에실행일/명령/commit연결. 문서업데이트는별도수정에서수행.

### I-18 · Medium · 웹 캐시·글자확대 검증 부족

- **근거 [사실/정적]**: sw.js는 모든GET을 저장하고 실패시`/`로fallback, 캐시expiry/상한없음. .large-text는 부모font-size만바꾸고 다수하위글자는rem고정.
- **영향 [추론]**: 미래API연결시 응답종류오염·민감캐시 위험, 큰글자버튼효과 제한 가능. 현재 웹이 실건강API를캐시한다는 증거는없음.
- **재현 제안**: 오프라인JS/JSON응답형태, 큰글자전후computed font-size·200%확대검사.
- **권장**: 앱쉘allowlist·응답종류별fallback·버전/만료, 글자크기기준과시각시험.

## 완료 판정

| 완료 조건 | 현재 판정 |
|---|---|
| 핵심 사용자 흐름 정상 | Mock 정상경로만 부분 확인 |
| 기능별 수용기준 충족 | 문진·인가·규칙중단·세션복구 불충족 |
| 필수 테스트 통과 | 기존23개통과, 필수E2E/장애/계약회귀 부재 |
| Critical/High 해결 | 미해결 |
| API/데이터 문서화 | 이번문서로복원, 원래schema와runtime불일치는미해결 |
| 설치·실행·배포 재현 | 기존로컬빌드/테스트만확인, clean/운영미검증 |
| 알려진 제약 기록 | 이번문서에기록 |
| 실행결과와 설명 일치 | 이번문서는범위구분, 이전문서일부차이남음 |

**[사실] 종합 판정: Mock 프로토타입 인수 분석은 완료했으나 운영·실기기 제품 완료 조건은 충족하지 않는다.**
