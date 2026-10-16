# VibeCare 검증 체크리스트

## 음식·운동 카드 개선 / AI 연결 보류 (2026-10-07)

기준 로컬 `4115032`, `health-management-20261006`, `E:\산학협력\vibecare-pages-update`. 이번 구현은 샘플 안내 UI 개선이며 실제 AI 연결 완료가 아니다. 자동 승인 검토가 구체적 건강정보/OpenAI 목적지 전송 승인 부재로 실제 호출 코드 추가를 거절했다. 승인·키/서버 위치 질문에 답변이 없어 API 구현을 보류했다. OpenAPI·Backend에 이번 턴에서 추가했던 미구현 계약/RED 테스트만 read-only diff 확인 후 복원했다. OpenAI·Gemini 키·외부 요청·DB 마이그레이션·새 의존성은 추가하지 않았다.

| 검사 | 실제 결과 |
| --- | --- |
| UI RED | FAIL 의도: `result advice separates actions from reasons and cautions`, 행동 제목이 없었음 |
| 첫 UI 시도 | FAIL: 색상 DecoratedBox가 nested ListTile 터치 효과를 가리는 assertion. Material 표면으로 수정 |
| 전체 Flutter | PASS **110/110**, `flutter test --no-pub --concurrency=1 --reporter expanded`, 62초. 이후 강화한 두 테스트도 개별 PASS |
| 펼침 조작 | PASS: 이유·주의사항 펼치기 전후 내용 구분, 공식 출처 버튼 접근 |
| 320px·글자 2배 | PASS: 이유 펼치기·출처 버튼까지 실제 hit-test 가능한 요소에 접근. 첫 보강 시도는 화면 밖 요소를 찾는 테스트 오류로 FAIL했고 hitTestable 조건 수정 후 PASS |
| 정적 분석 | PASS: `flutter analyze --no-pub`, No issues found (33.7초); format 대상3파일 변경0 |
| Android debug APK | PASS: `flutter build apk --debug --no-pub`, 125.6초. SHA256 `AA1250C332F295EA297A007BA337B207FB192741313A793C6D264DF928335EA3` |
| 웹 release | PASS: JavaScript 빌드 173.3초. 기존 secure-storage Wasm 비호환·Cupertino font·PWA 옵션 경고 유지; Wasm 검증 성공은 아님 |
| 실제 샘플 웹 | PASS: localhost8766 → 샘플 홈 → 샘플 실행 → 기본 로그인 → 프로필 완료 → 결과/AI 미연결 펼침 → 두 카드 → 이유·주의사항 → 공식 출처 복사 성공 피드백. 390×844·320×700 기본 글자 크기, browser error/warn0. 합성USER-001, 골격근12.5kg/체중42kg/체지방18.8%/비교+0.1kg, 안전 문진 미완료 상태. 실제 계정이나 외부 AI 요청을 사용하지 않음 |
| Backend 동의 RED | FAIL 의도: 신규 endpoint 부재로404, 기대400. 실제 AI 코드 승인이 보류되어 해당 테스트는 이번 턴 추가분만 제거. GREEN이나 실제 연결 증거로 사용하지 않음 |
| 미실행 | 실제 OpenAI 호출·응답 품질/비용·개인 추천·운영 활성화·Android 실기기·공개 배포·참가자 이해도 조사 NOT RUN. Backend는 최종 변경이 없어 추가 전체 검사 미실행 |

환경: 형식·전체 테스트를 시작하는 명령의 자동 승인 검토가 시간 초과되어 실행되지 않았고, 같은 로컬 검사 한 번 재시도 후 PASS. 빌드/테스트는 순차 실행했다. 완료된 이번 Gradle 데몬 PID40876만 종료해 웹 빌드 메모리를 확보했으며 PC 설정은 바꾸지 않았다. 사용자 기존 파일·22~24 캡처는 제외한다.

2026-10-07 웹 캡처: [미연결·음식 진입](docs/assets/ux-review-20261006/37-advice-entry-390x844.jpg), [두 카드](docs/assets/ux-review-20261006/38-advice-cards-390x844.jpg), [출처 복사 피드백](docs/assets/ux-review-20261006/39-advice-source-feedback-390x844.jpg), [320px 상세](docs/assets/ux-review-20261006/40-advice-details-320x700.jpg). Android 실기기 캡처나 사용자 피드백이 아니다. 글자 두 배는 위젯 검사에서 검증했다. 서버·브라우저 탭·임시 viewport는 완료 후 정리한다.

## 결과 AI 안내 샘플 미리보기 검증 (2026-10-06)

사용자 선택: **결과 화면·샘플 응답 먼저 구현하고 검증**. 기준은 로컬 `317c9605`이며 실제 AI 연결이나 공개 배포는 포함하지 않는다. 기존 결과 카드에 접이식 안내를 추가하고 파일·폴더·의존성을 늘리지 않았다.

| 검사 | 실제 결과 |
| --- | --- |
| RED → GREEN | 결과 화면의 `ai-wellness-preview` 부재로 의도한 FAIL 확인 후 해당 화면 테스트 PASS |
| 전체 Flutter 테스트 | PASS **109/109**, 단독 실행 103초 |
| 형식·정적 분석 | PASS: 59파일 변경 0, analyze No issues found (18.8초) |
| 내용·상태 검증 | PASS: AI 미연결·준비된 예시 표시, 안전 문진 미완료/증상/측정 검토 보류 시 운동 안내 보류, 안전 상태 변경 시 예시 제거, NaN 해석 보류, 320px·글자 2배, 같은 참여자·기기·측정 방법·프로토콜의 과거 기록만 비교 |
| Android 디버그 APK | PASS: assembleDebug 167.8초. SHA256 `4B189A018AFD62759247A7B9EC5CDFDF142CDA4576151979AB878AF34170F53A` |
| 웹 release | PASS: JavaScript 웹 빌드 216.8초. 기존 secure-storage Wasm dry-run 비호환·Cupertino font 및 PWA 옵션 경고는 남아 있으며 Wasm 검증 성공으로 취급하지 않음 |
| 실제 샘플 웹 화면 | PASS: localhost8766 → 샘플 홈 → 샘플 실행 → 기본 USER-001 로그인 → 프로필 확인 → 결과 → 안내 펼치기. 390×844·320×700, 기본 글자 크기, 브라우저 error/warn 0건. 골격근량12.5kg·체중42.0kg·체지방18.8%·비교+0.1kg, 안전 문진 미완료 상태의 운동 보류를 확인 |
| 미실행 범위 | 실제 AI 생성·외부 건강정보 전송·개인화된 음식/운동 처방·실제 계정/RLS·Android 실기기·공개 배포·사용자 이해도 연구 NOT RUN |

음식은 알레르기와 식사 제한을 확인하지 않아 개인 식단 추천을 보류하고 일반 식품군 예시를 표시한다. 운동도 연구 등급에서 강도·시간·횟수를 도출하지 않는다. 측정값 해석은 동일 측정 기록의 수치 요약과 비교이며 전체 건강상태나 질병 진단이 아니다. 기존 연구 알고리즘·API·Mock/실제 구분·물리 안전 차단은 변경하지 않았다.

캡처: [미연결 표시](docs/assets/ux-review-20261006/33-ai-preview-entry-390x844.jpg), [해석·음식](docs/assets/ux-review-20261006/34-ai-preview-analysis-food-390x844.jpg), [운동 보류](docs/assets/ux-review-20261006/35-ai-preview-exercise-hold-390x844.jpg), [320px](docs/assets/ux-review-20261006/36-ai-preview-320x700.jpg). 모두 합성 시연 데이터이며 Android 실기기 증거가 아니다. 글자 2배는 위젯 테스트로 확인했다. 웹 빌드 중 PC 페이징 메모리 부족으로 보조 확인 명령 실행이 실패했고 이번 APK 빌드가 생성한 완료 후 Gradle PID31828만 종료했다. 웹 빌드는 이어서 성공했다. 테스트·APK·웹 빌드는 순차 실행했으며 PC 메모리 설정은 바꾸지 않았다.

## 건강관리 1차 확장 검증 (2026-10-06)

대상: 기존 연구 참여자·고령 사용자. 작업 폴더 `E:\산학협력\vibecare-pages-update`, 브랜치 `health-management-20261006`. 검사한 앱은 fetch 확인 main `61b1cb064b16564e002a17ed6d4b0cecb0f8f7fb`에 생활관리 변경을 적용한 작업 트리다. 아래 결과는 이번 로컬 작업판이며 기존 공개 Pages의 배포 성공을 이번 변경의 배포로 대체하지 않는다.

| 검사 | 실제 결과·명령 |
| --- | --- |
| RED 홈 진입 | FAIL 재현: `sample home offers everyday health management`, 생활관리 문구 0개. `standalone sample app can reach the health management home`, 기본 APK 샘플 홈 접근 문구 0개 |
| RED Auth 오류 | FAIL 재현: `auth refresh stream failure clears access and remains recoverable`, 처리되지 않은 `offline refresh` 예외 |
| 삭제 실패 피드백 | FAIL 재현: 하단에서 삭제 실패 시 상단 안내가 화면 밖에 있어 확인 불가. 화면 알림을 추가한 뒤 기록 유지·재시도 PASS |
| 형식 | PASS: `dart format --output=none --set-exit-if-changed lib test`, 59개 파일 변경 0 |
| 정적 분석 | PASS: `flutter analyze --no-pub`, No issues found |
| 최종 전체 Flutter | PASS: `flutter test --no-pub --concurrency=1 --reporter expanded`, **103/103**, 98초 |
| 핵심 저장·화면 | PASS: 관심 습관·실천/쉬기/취소·다른 날짜 보존·샘플/두 계정 저장 키 분리·계정별 삭제·90일 실제 저장 정리·손상/버전 미지원 기록 보존·실패 복구·늦은 응답/계정 변경·Auth 스트림 오류 차단·자정 날짜 변경·320px/글자 2배 |
| Android debug APK | PASS: `flutter build apk --debug --no-pub`, assembleDebug 180.9초. SHA256 `F814C936EEB87BF2E5192CD5FDFD6C86CA6914E44F626CF8A93F05C5A0CC5D60` |
| 웹 release | PASS: `flutter build web --release --base-href / --pwa-strategy=none --no-pub` + CI와 같은 공개 Supabase URL/publishable 설정, 204.6초. 기존 secure-storage의 Wasm dry-run 및 Cupertino font 경고는 남으며 JS 웹 빌드는 성공 |
| 실제 로컬 웹 | PASS: `http://127.0.0.1:8766/`, 연결 로그인 화면 → 샘플 홈 → 선택 → 실천 저장 → 홈 복귀/재진입 유지 → 쉬기 → 기록 취소 → WHO 안내 펼침/주소 복사 → 삭제 확인/취소. 390×844 및 320×700, 기본 글자 크기. 브라우저 error/warn 로그 0개. 실제 계정/측정 정보는 입력·조회하지 않음 |
| 미실행 | NOT RUN: 새 브랜치의 원격 CI/공개 배포, 실제 Auth 두 계정과 RLS, Android 설치·실기기·스크린리더 전체 동선, 고령 사용자의 이해도 시험, 전문가의 개인별 건강 콘텐츠 검토, 서버 생활 기록 동기화·백업·복구 |

환경 이력: 웹 빌드와 전체 검사를 동시에 실행한 시도는 로컬 PC의 메모리/PowerShell·Dart native 오류로 FAIL/중단됐다. 단일 전체 시험과 직렬 빌드로 위 PASS를 다시 확인했다. APK 완료 후 Gradle 데몬 정상 종료 명령은 가상 메모리 부족으로 FAIL했고, 이번 빌드가 생성한 Java PID 32324만 종료했다. 사용자 PC의 메모리 설정은 바꾸지 않았다. 로컬 시각 검사 서버·임시 X: 경로는 완료 후 정리한다.

캡처: [홈](docs/assets/ux-review-20261006/25-health-home-390x844.jpg), [빈 상태](docs/assets/ux-review-20261006/26-health-empty-390x844.jpg), [실천과 7일](docs/assets/ux-review-20261006/27-health-done-390x844.jpg), [쉬기](docs/assets/ux-review-20261006/28-health-rest-390x844.jpg), [공식 안내](docs/assets/ux-review-20261006/29-health-guide-390x844.jpg), [삭제 확인](docs/assets/ux-review-20261006/30-health-delete-confirm-390x844.jpg), [320px 안내](docs/assets/ux-review-20261006/31-health-guide-320x700.jpg), [320px 오늘 기록](docs/assets/ux-review-20261006/32-health-today-320x700.jpg). 모두 로컬 작업판·샘플 공간·사용자가 조작한 시험 입력이며 실제 참여자의 건강 기록이 아니다. 글자 2배는 위젯 검사이며 웹 캡처나 Android 실기기 증거로 간주하지 않는다.

운영 전 결정: 이 기기에만 저장하는 1차 범위와 90일 보관 기본값을 수용할지, 계정 서버 동기화를 먼저 도입할지 결정한다. 동기화 도입 시 동의·보존/삭제·백업·소유권/RLS·두 실제 계정 검증이 필요하다. 다중 탭의 동시 수정 병합은 현재 지원하지 않는다. 기존 측정 알고리즘·API·예약과 `PROHIBITED`/`SIMULATOR_ONLY`/`realDeviceSendAllowed=false`는 변경하지 않았다.

## `pilot-0.9.1` 연구용 계수

- [x] `0.95 × 0.95 × 0.95 = 0.857375` Mock 강도 계산, 기존 버전 분리, SQLite 규칙 마이그레이션
- [x] Backend API 단위·라우트 테스트 및 Flutter 계수·화면 테스트로 수치 확인
- [ ] PostgreSQL 실환경 마이그레이션과 배포 검증
- [ ] 임상 및 기기별 보정 근거 검증 (현재 실제 장치 실행 금지)

문서 점검 기준일: 2026-10-06. 과거 검사 결과는 당시 커밋·환경의 이력이며 현재 인계 버전의 통과 증거로 대체하지 않는다.
상태: [x] 코드와 검증 증거 있음 · [~] 일부 구현 · [ ] 미구현/외부 차단

## A. 저장소 품질 게이트

- [x] 공개 문서 진입점: `docs/README.md`
- [x] GitHub Actions 구성: 백엔드 typecheck/test, Flutter format/analyze/test/debug APK build
- [x] 실제 PostgreSQL/Node HTTP 시험과 같은 커밋의 검사·APK·웹 산출물 기록 구성
- [x] 독립 Pages 배포 workflow 제거, main의 백엔드·PostgreSQL·Flutter·웹 성공 뒤 같은 실행에서 배포하도록 연결
- [x] 실제 환경값 제외: `.env*`, `.dev.vars`, `*.local.txt`, 로컬 상태·빌드 산출물 ignore
- [x] 패키지 버전 잠금: 백엔드 `package-lock.json`, Flutter `pubspec.lock`
- [x] AWS 인계 범위와 미구현 항목 분리
- [x] `pilot-0.7.0` 구현 커밋 `2d15e9f`의 원격 `quality-gates` 통과: [run 34459978932](https://github.com/Dowon-Kang/vibecare-pilot/actions/runs/34459978932)
- [x] main branch protection: PR 경유·최신 main 기준·백엔드/PostgreSQL HTTP/Flutter/웹 네 검사 필수, 관리자 우회 금지 (2026-10-06 API 적용·재조회)

## B. 정량 검증 이력 (2026-09-21)

| 검사 | 마지막 결과 | 합격 기준 |
|---|---:|---:|
| 백엔드 전체 Vitest | 81/81 통과 (2026-09-21, 근육지수 경계의 반올림 전 판정 회귀검사 포함) | 실패 0 |
| Flutter 전체 테스트 | 57/57 통과 (2026-09-21, 동일 경계 판정·측정 추세 그래프·320px·글자 2배 포함) | 실패 0 |
| 백엔드 TypeScript | 통과 | 오류 0 |
| Flutter format/analyze | V: 영문 경로에서 format·analyze 통과 (2026-09-21) | 오류 0 |
| Flutter debug APK | V: 영문 경로 로컬 debug APK 빌드 통과 (2026-09-21) | 빌드 실패 0 |
| API 계약 | OpenAPI·핵심 JSON Schema 유지 | 참조 오류 0 |

수치는 실행한 자동 검사 기준이며 임상 안전성 수치가 아니다.
2026-09-19에는 골격근량 기준 변경 후 백엔드·Flutter 전체 테스트와 debug APK를 다시 검증했다.

### 2026-10-06 인계 검증 작업

기준: GitHub main `69307b9015f420803a132048ee98031c322d3cc1`를 fetch로 확인한 뒤 `handoff-verification-20261006`에서 작업했다. 로컬 결과는 해당 기준에 이번 변경을 적용한 작업 트리의 결과다. 확정 SHA의 결과는 GitHub Actions 실행·artifact로 판정한다.

| 검사 | 현재 실제 결과 |
|---|---|
| RED: 동시 PIN 오입력 | FAIL 재현: 5개 요청 모두 401, 잠금 누락 |
| RED: FITRUS 응답 본문 지연 | FAIL 재현: 1초 시험 제한 초과, 본문 deadline 누락 |
| GREEN: 관련 회귀검사 | PASS: `npm test -- test/routes.test.ts test/fitrus-client.test.ts --reporter=dot --silent`, 26/26 |
| 백엔드 전체 | PASS: `npm test -- --reporter=dot --silent`, 86/86 |
| TypeScript | PASS: `npm run typecheck` |
| 운영 의존성 high 기준 | PASS: `npm audit --omit=dev --audit-level=high`; moderate 경고 1건은 남음 |
| Flutter format | PASS: `dart format --output=none --set-exit-if-changed lib test`, 55개 파일 변경 0 |
| Flutter analyze | 첫 한글 경로 실행 FAIL: LSP JSON 수신 종료. 같은 폴더의 임시 영문 `X:` 경로에서 `flutter analyze --no-pub` PASS; `dart analyze .`도 PASS |
| Flutter 전체 | 최초 86 PASS / 1 FAIL: 출석 시험의 화면 밖 tap. 버튼 노출 후 hitTestable tap으로 보완해 `flutter test --no-pub --reporter expanded` 87/87 PASS |
| 로컬 debug APK | FAIL: `flutter build apk --debug --no-pub`, JVM native memory 부족으로 Gradle daemon 종료. CI Android 결과는 별도 확인 |
| 로컬 웹 release | PASS: CI와 같은 공개 Supabase 설정의 `flutter build web --release --base-href /vibecare-pilot/ --pwa-strategy=none --no-pub`, 174.8초. Wasm dry-run 경고는 있으나 JS 웹 빌드는 성공 |
| 로컬 PostgreSQL HTTP | NOT RUN: Docker 엔진 시작 시도 후에도 named pipe를 사용할 수 없음 |
| CI PostgreSQL HTTP | 실제 결과는 같은 SHA의 Actions 실행과 `postgres-http-evidence-<SHA>` artifact에서 확인; SQLite 결과로 대체하지 않음 |
| 실환경·인수 | NOT RUN: 실제 Supabase 두 Auth 계정, FITRUS, Android 기기·접근성, 운영 백업/복구, 기업 인수 확인 |

GitHub 설정: 작업 시작 시 main protection은 없고 적용된 rules는 빈 목록이었다. 네 필수 검사·strict·enforce_admins·PR 경유를 적용하고 API로 재조회했다. 승인자 수는 0으로 두며, 별도 기업 리뷰 담당자를 임의로 지정하지 않았다. Draft PR과 기업의 인수 확인은 별도로 진행한다.

다른 작업 트리의 변경 보존: `E:\산학협력\vibration-control-app`의 Android 알림·장치 상태 시험은 최신판에 반영돼 있고, 합성 날짜·알림 helper·freshness 시험도 반영돼 있다. 예약·화면 변경은 최신판에서 확대·수정됐으므로 오래된 파일로 덮어쓰지 않는다. FITRUS 본문 timeout 수정은 이번 브랜치에 다시 RED/GREEN으로 반영했다. 미적용 `docs/supabase-rls-proposal.sql`은 검토용으로 원래 폴더에 보존하고 원격 DB에 적용하지 않았다. `E:\industry-cooperation\vibration-control-app`의 별도 UI 변경과 이 작업 트리의 미추적 `docs/architecture-map.md`도 보존한다.

## C. 데이터와 FITRUS

- [x] FITRUS API 키는 백엔드 환경변수만 사용
- [x] 공급 API 종류: bodyfat, bp, hr, stress, stress2, bodytemp
- [x] 공급 원본과 앱 표준 DTO의 책임 분리
- [x] FITRUS 서버 전용 client와 HTTP 상태 기반 오류 전달
- [x] 공식 요청 형식·인증 헤더·성공 응답 fixture 및 비정형 오류 본문 처리
- [ ] bodyfat 근육 필드가 ASM인지 SMM인지, 산출법·단위·방법 근거 확인 후 `applicableMethods` 등록
- [x] 명세상 체성분·활력 응답 검증, 표준 이력 저장과 `normalized:true`
- [ ] 공급사 실장치 응답 fixture로 계약 테스트 재확인
- [ ] 호출 제한·타임아웃·개발/운영 endpoint 확인
- [ ] 개인정보 보존기간·삭제·접근 감사 정책

## D. 측정과 알고리즘

- [x] REQ-SIMPLE-01: 계산 근거 4단계 설명·연구 상세 접기, 새 단위6/위젯1 및 전체45/45 통과
- [ ] REQ-SIMPLE-01 정적 분석 재확인: LSP 초기 메시지 오류/직접 분석 무응답, 통과로 판정하지 않음

근거·역학 확장:

- [x] REQ-MECH-01~03 멀티에이전트 근거/반례 설계: `docs/algorithm/exa-results/muscle-wbv-causal-design-2026-09-15.md`
- [x] `vibration-mechanics.ts` 순수 계산, 새28시험 및 전체141/141, typecheck 통과
- [x] 독립 검토 수치 오류2건 수정·회귀/재검토, 반응모델과 정책 평가 분리
- [ ] 실제 장치 교정·반응 데이터·사람 단위 외부검증 및 정책 효과 검증

DSPy 후속:

- [x] REQ-DSPY-01~03 근거·평가·누출 방지 설계: `docs/algorithm/exa-results/dspy-smm-2026-09-15.md`
- [ ] 사람 이중 검토 골드셋, 고정 evaluator, DSPy/GEPA 실제 실행 및 잠금 평가
- [ ] 실측 반응 모델 검증 (DSPy 문헌 해석 점수와 별개)

2026-09-15 SMM 주파수 연구 묶음 (기존 앱과 분리):

- [x] REQ-SMM-01~04 수식·근거·가설·입력 계약: `docs/algorithm/smm-frequency-design.md`
- [x] 고정/계단/선형/smoothstep 순수 함수: `backend-api/src/smm-frequency.ts`
- [x] 읽기 전용 인증 API와 실행 허가 금지: `backend-api/src/routes/research-routes.ts`
- [x] 수치 격자·경계·정규화·소유권·보류: 전체 113/113, 새 단위 29·라우트 12; 위 설계 문서에 명령·수치 기록
- [ ] Flutter 새 연구 모델 연결 및 소수 Hz 표시/계약 검증
- [ ] 실측 반응 자료 기반 효과 비교 (소프트웨어 시험으로 대체 불가)

- [x] 동일 참여자·동일 장치·정확히 네 건 검사
- [x] 중복·결측·비유한수·단위/정의 혼합·BMI/체지방 모순 차단
- [x] 평균·표본 SD·CV·최솟값·최댓값 계산
- [x] ASM/ASMI와 SMM/SMMI 분리, 상호 변환 금지
- [x] 현재/과거 통증·어지럼·사용보류 실패 폐쇄
- [x] `UNKNOWN`·ASM/SMM 기준 불일치·방법/단위/프로토콜 혼합 시 층화·인가 차단
- [x] 공급사가 확인한 ASM/SMM 정의만 앱에서 활성화하고 임의 재해석 차단
- [x] 최신 골격근량/키²의 낮음·중간·높음과 6개 부위 고정 시간·Hz·강도 구현(`pilot-0.9.0`)
- [x] 근육지수 등급은 반올림 전 원값으로 비교하고 표시·응답값만 소수 둘째 자리로 반올림
- [x] Flutter·백엔드 Case A~E와 6개 부위 계산 검증
- [~] 앱·백엔드 핵심 결과 parity; 공개 계약 전체 자동 parity는 미완료
- [x] 모든 결과 `physicalExecution=PROHIBITED`, 모든 Mock 명령 `SIMULATOR_ONLY`
- [ ] FITRUS 정의 동등성 검증
- [ ] 신뢰된 정책·이력 Repository와 안전보류 해제 감사
- [ ] 근육량→특정 시간·Hz·물리량의 전향 검증
- [ ] 근육지수 연구 경계와 확정 고정값의 임상·기기 검증

## E. Flutter 사용자 흐름

- [x] GitHub Pages 공개 Web 시연판 배포, HTTPS·HTTP 200·한글 렌더링 확인; 샘플 데이터와 Mock 전용
- [x] 로그인 직후 프로필 하단에 통증·어지럼·사용 보류·연구용 시뮬레이션 주의사항 표시
- [x] Mock 로그인에서 낮음·중간·높음 페르소나 선택 및 나이·성별·키 프로필 설문 자동 입력
- [x] 최신 API 골격근량의 낮음·중간·높음 등급과 DB 직전 기록 대비 변화 표시
- [x] 부위별 설정 화면에서 인체 부위와 골격근량 등급별 고정 시간·Hz·강도 표시
- [x] 프로필→골격근량→장치 설정 진행 상태와 비활성 행동의 이유 표시
- [x] 장치 화면의 중복 고정 설정 카드 제거, 추천 카드로 단일화
- [x] 측정 입력·네 건 평균은 내부 계산 및 프로필/측정 시트에 유지하고 메인에는 추천 결과만 우선 표시
- [x] Stepper 없이 인체 부위 선택 → 즉시 설정 결과 → 실행 CTA 맥락 연결
- [x] 공통 ThemeData·디자인 토큰과 균형 잡힌 곡선형 인체·실제 부위 shape 강조 적용
- [x] 정규화 인체 좌표와 분리된 visual/touch 영역, 48dp 부위 선택칩 6개 전체 노출
- [x] 추천값과 중복되는 `설정 계산됨` READY 상태 배지 제거
- [x] 추천값 3열 비교, 추천 출력 강조, 프로필·측정 정보 분리로 중첩 카드·정보 밀도 축소
- [x] `내 정보`와 `측정 기록` 탭 분리, 성별·나이·키 우선 표시와 최신 상태 요약
- [x] 최근 4회 원본을 긴 카드 대신 골격근량·체지방·체중 비교 행으로 표시하고 전체 지표는 별도 상세 화면 제공
- [x] 강도 확인·수동 하향·자동값 복귀
- [x] 장치로 보내기→Mock 시작→실행 상태→중지
- [x] 사용 후 RPE·통증·어지럼·시간/Hz/강도 체감 수집
- [x] 320px 작은 화면·글자 2배·하단 CTA 위젯 검사
- [x] 로딩·API 오류·전송 실패·중복 실행·중지 실패 상태
- [ ] FITRUS 실데이터 화면 검증
- [x] 연구 상태·가설 라벨·4건 SD/CV/범위와 이유 코드 표시
- [ ] 실제 Android 기기 접근성 재검증
- [ ] 앱 종료·재시작 후 진행 세션 복구

## F. 백엔드와 AWS

- [x] PIN 잠금·access/refresh token·동시 refresh 검사
- [x] 측정 소유권·규칙 버전·서버 재계산·멱등키 검사
- [x] Mock 세션·ACK·중지·피드백 감사 흐름
- [x] 실제 장치 모드는 의도적으로 차단
- [x] Hono Web Fetch API와 공급사 중립 `SqlDatabase` 포트
- [x] 공급자 중립 PostgreSQL adapter·Node 런타임·통합 schema·합성 seed 구현
- [x] DB 포트 loopback 제한, 개발 seed 명시 플래그+loopback 제한, schema version 기동 검사
- [x] Supabase Data API와 분리된 `vibecare` schema·서버 전용 search path·TLS 검증 설정
- [~] Supabase `vibecare-pilot`(서울) 생성 및 비공개 `vibecare` schema remote migration 완료; `anon`/`authenticated` schema·table 권한 없음 확인, RLS 방어 심층화·성능 index·실제 HTTP 통합은 미완료
- [ ] ECS/Lambda 선택, HTTPS, CORS, IAM, Secrets Manager/SSM
- [ ] 운영 migration·백업·롤백·CloudWatch 경보
- [ ] 부하·장애·보안 시험과 보존기간 적용

## G. 실제 진동기

- [x] `DeviceGateway` 공통 인터페이스와 Mock 구현
- [ ] REST/BLE 명령과 응답 명세
- [ ] 시간·Hz·UI %와 변위·peak/RMS 가속도 매핑
- [ ] 장치·펌웨어·하중·자세·발 위치별 3축 교정
- [ ] ACK 제한시간·watchdog·통신단절·긴급중지
- [ ] 벤치 시험과 독립 공학 검토
- [ ] 사람 대상 연구 승인과 유해사건 절차

## H. 배포 가능 판정

현재 판정: **GitHub 소스 공개 및 Mock 개발 가능 / AWS 운영·FITRUS 실연동·실장비 사용 불가**.

운영 완료는 C~G의 미완료 항목이 해결되고, GitHub 품질 게이트·AWS 배포 시험·실기기 검증·독립 연구 검토가 모두 통과했을 때만 선언한다.
## 2026-10-01 웹 시연 확장 확인

- [x] 고정된 합성 측정 날짜 제거 및 회귀 테스트
- [x] 예약·출석·미참여 달력·참여율과 측정 전 증가 항목
- [~] Android 로컬 알림 컴파일 확인, 실기기 알림 미검증. 웹은 앱 실행 중 메시지
- [x] Supabase Auth 기반 예약·출석 저장과 사용자별 RLS migration 적용; 익명 접근 권한 없음 확인
- [ ] Auth 리디렉션 URL 허용, 첫 계정 생성·로그인·예약 종단간 확인, GitHub Pages 배포 확인
- [ ] 실제 측정 데이터와 Auth 계정 관리자 연결 후 개인 기록 표시 확인
## 2026-10-01 주간 참여와 홈

- [x] 매주 4·12·52주 예약과 동일 시간 중복 방지 로직
- [x] 완료된 예약 기준 참석률 80% 별 표시와 출석일 달력 별 표시
- [x] 연결 및 샘플 홈의 실행·출석·공지 구역 분리
- [x] 운영 공지 테이블 RLS와 인증 사용자 읽기 권한 적용
- [ ] 실제 Auth 계정의 주간 예약·공지 조회 브라우저 검증 (계정 없음)
- [ ] Android 실기기 예약 알림 검증
- [x] 새 계정 버튼을 별도 가입 폼으로 전환하고 이메일·비밀번호 재입력 검증
- [x] Supabase 신규 가입 허용 및 이메일 인증 활성화 상태 확인 (2026-10-01 Dashboard)
- [ ] 조직 외부 이메일의 확인 메일 발송 검증 (SMTP 설정 확인·발신 계정 필요)

- [~] 2026-10-02 미래 예약 웹 알림: 첫 1분 누락 회귀 테스트와 당일 보충 안내 수정. 웹 푸시·Android 실기기·접근성·부하 검증은 [비기능 점검](docs/notification-nfr.md)에 따라 미완료.

- [x] 2026-10-02 예약 시간 선택 기본값: 현재 이후 15분 단위 또는 다음 날 오전 10시. 회귀 테스트·전체 Flutter 테스트 70개·전체 Dart 분석 통과. 사용 보류는 안전 피드백 정책을 유지.

- [x] 2026-10-03 주요 웹 화면 상단 내비게이션: 하위 화면 뒤로가기, 오른쪽 메뉴에서 홈의 시연·예약/출석·공지 및 예약 화면의 새 예약·알림 안내 확인. 샘플 홈 이동·로그인 메뉴 위젯 테스트 통과.

## 웹 홈·예약 화면 품질 점검 (2026-10-03)

- PASS: `flutter test --no-pub` — 78개 테스트 통과. 320px/2배 글자, 넓은 화면 본문 폭, 달력 날짜 설명, 시연 홈 오류 재시도와 예약 알림을 포함한다.
- PASS: `dart analyze .` — 문제 없음.
- PASS: `flutter build web --release --base-href /vibecare-pilot/ --pwa-strategy=none --no-pub` — 웹 릴리스 빌드 완료.
- NOT RUN: 실제 스크린리더·키보드 전 경로, 실계정 두 개의 데이터 격리, 느린 네트워크, Android 실기기 알림. 브라우저 종료 후 Web Push는 구현되지 않았다. 상세 범위는 docs/web-ux-nfr.md 참조.


## 사용 후 통증 응답 정책 (2026-10-03)

- PASS: 이전 시연에서 통증을 보고한 경우 다음 시연 강도 상한을 90%로 낮추고 사용 전 확인창에서 취소·진행을 선택할 수 있다. Flutter `flutter test --no-pub --reporter compact` 81/81, `dart analyze .` 문제 없음.
- PASS: 서버는 이전 통증만으로 다음 연구용 시뮬레이션을 차단하지 않고, 지난 승인 재사용은 거부한다. 0013 마이그레이션은 통증만의 기존 보류를 제한적으로 전환한다. `npm run typecheck` 및 `npm test -- --reporter=dot` 81/81 통과.
- PASS: 사용 전 현재 통증 응답의 차단과 이전 어지럼·시간·주파수 심한 불편의 검토 보류를 유지한다.
- NOT RUN: 실제 의료·물리 장치 안전성, Android 실기기, 운영 백엔드 마이그레이션. 물리 출력은 계속 PROHIBITED / SIMULATOR_ONLY다.

## 2026-10-03 주요 기능 UX 비교와 예약·출석 개선

- PASS: `docs/ux-flow-comparison-2026-10-03.md`에서 로그인, 홈, 예약, 반복, 출석, 알림, 측정, 추천, 시연, 평가 흐름을 참고 앱과 비교했다.
- PASS: 예약 반복을 고르는 즉시 저장하던 창을 날짜·시간·반복·종료일·중복 수의 저장 전 검토 화면으로 교체했다. 스크롤 전에도 종료일·횟수를 저장 버튼 위에서 확인하고, 저장 후 첫 예약 날짜의 달력을 보여준다.
- PASS: 달력 날짜 선택으로 해당 날짜의 예약만 보고, 월 이동 시 날짜 선택을 초기화한다. 월별 목록으로 긴 반복 예약을 탐색할 수 있다. 날짜의 스크린리더 활성화 동작도 연결했다.
- PASS: `flutter test test/participation_screen_test.dart` 예약·달력 회귀 테스트, `flutter test --no-pub --reporter compact` 85/85, `dart analyze .` 문제 없음. 웹 릴리스 빌드 완료.
- FAIL: `flutter analyze --no-pub` 분석 서버가 LSP JSON 수신 오류로 종료했다. 같은 전체 Dart 프로젝트를 `dart analyze .`로 확인했다.
- NOT RUN: 실제 사용자 관찰, 전체 키보드·스크린리더 동선, Android 실기기 알림, 실제 Supabase 계정의 종단간 동작. 웹 푸시는 구현되지 않았다.


## 2026-10-15 실제 Flutter 모바일 화면 연결

- PASS: 의도한 RED — `test/sample_route_scope_test.dart`의 새 탐색/프로필/알림 설정 검사가 구현 전 `participant-navigation` 부재로 실패했다(0d6cb54 계약 커밋).
- PASS: 새 홈, 하단 4개 탐색, 알림함/설정, 기록에서 기존 예약·출석 달력 연결. 샘플 상태는 독립 ProviderContainer, 실계정은 기존 Supabase Auth/측정/예약 조회를 사용한다.
- PASS: Windows Flutter 3.47.2/Dart 3.13.3, ASCII X: 작업 경로와 TEMP 사용. `flutter analyze --no-pub` 문제 없음. `flutter test --no-pub --concurrency=1 --reporter expanded` 115개 통과. 이후 추가한 계정 상실 검사는 최종 CI에 포함한다.
- PASS: 기존 연구 흐름의 프로필·측정·안전 문진·시뮬레이터·중지 실패 복구·피드백 회귀 유지. 결과 화면의 생활 안내를 생활 돌보기로 이동했다.
- 검증 대상: `ui/mobile-release-20261015` 최종 HEAD 및 해당 PR CI. 빌드/배포 최종 결과는 PR과 Actions 실행을 함께 확인한다.
- NOT RUN: Android 실기기, 실제 계정 두 개의 종단간 격리, 실제 스크린리더·사용자 평가, AI 외부 데이터 전송, FITRUS 수집/물리 장치. 닫힌 웹의 푸시는 구현되지 않았다. AI 미연결과 샘플 구분 및 SIMULATOR_ONLY/PROHIBITED를 유지한다.


- 2026-10-15 CI 38719986774: Backend 승인 테스트 11개가 고정 9월 측정값의 30일 유효기간 경과로 실패했다(운영 코드 변경 없음). 테스트에만 2026-10-05 Date 기준을 고정하고 실제 타이머·운영 측정 유효기간·안전 차단은 유지한다. PostgreSQL HTTP, Flutter 포맷/분석/전체 테스트는 해당 CI에서 통과했다.

- PASS (수정 후 로컬): Backend npm run typecheck 및 npm test -- --reporter=dot, 86/86. 실제 Flutter 웹 릴리스 빌드와 데스크톱 베젤/홈 표시 확인. 캡처: docs/assets/20261015-web-home-bezel.png (507x871 브라우저, 연결 측정 없음 상태; 실제 개인 측정/계정 식별자 미포함).

## 2026-10-15 실제 생활 돌보기 AI 연결 준비

- 승인: 앱의 매 요청 동의 후 골격근량/체중/체지방률과 목표만 OpenAI로 전송. 계정 식별자·원본 CSV·제한/문진 답변은 공급자 입력에서 제외한다.
- PASS: 측정 시작을 출석보다 앞에 배치하는 RED(504px vs 212px), 실계정 측정 준비 부재 RED, 예약 하위 탭 index 0/1 RED 후 GREEN.
- PASS: AI 인증 RED(501 vs 401), 동의 버튼 부재 RED, 측정 변경 시 동의창이 남는 RED 후 GREEN. Flutter 포맷/분석과 전체 테스트 124개, Backend typecheck/전체 테스트 96개.
- PASS: 최소 전송, 제한은 서버 필터만 적용, 최신 측정/출처/30일 검증, quota 초과, 비허용 AI ID/불완전 응답, 타임아웃 비자동 재시도, 표시 중 변경과 취소/늦은 응답 폐기, 320px/2배 글자.
- PARTIAL: wellness-advice Edge Function v1 ACTIVE, verify_jwt=true. 키 미등록이면 configured=false이고 일반 안내와 실패 상태를 구분한다.
- BLOCKED: 자동 승인 검토가 저장된 .dev.vars 비밀키 파일 읽기와 Supabase 비밀값 대시보드 접근을 각각 거절했다. 키는 읽거나 출력하지 않았으며 다른 경로로 우회하지 않았다. 구체적 키 읽기/등록 승인이 마지막 활성화 조건이다.
- NOT APPLIED: Supabase RPC/요청 한도 마이그레이션은 apply_migration 2회 및 트랜잭션 execute_sql 요청에서 Invalid or expired requestState 오류. 두 함수가 없는 것을 메타데이터로 확인했다. 실제 데이터 수정·quota 사용은 없다.
- NOT RUN: 실제 OpenAI 응답/비용/계정 모델 접근, 운영 RPC/RLS/원자적 quota, 최신 변경 웹/APK 빌드/배포, 실제 Android/임상/물리 장치. 기존 물리 출력 PROHIBITED/SIMULATOR_ONLY 유지.
- 기존 보안 점검 결과(변경 전): prevent_overlapping_device_sessions_fn search_path, 유출 비밀번호 보호 비활성 경고. 이번 작업은 해당 기존 설정을 바꾸지 않았다.

## 2026-10-15 AI 서버 활성화 후 검증

- 승인: 지정된 `.dev.vars`의 OPENAI_API_KEY만 Supabase jaekmjiupbsufxaevosf 서버 Secret에 등록하고 AI 설정을 적용하도록 사용자가 명시 승인했다. 위의 초기 BLOCKED/NOT APPLIED 상태는 아래 결과로 갱신한다.
- PASS: Dashboard에 OPENAI_API_KEY, OPENAI_WELLNESS_MODEL=gpt-6-luna, WELLNESS_ALLOW_REAL_DATA=true 등록. 키를 소스·Flutter·Git에 포함하지 않는다.
- PASS: MCP DDL 도구의 requestState 오류가 계속되어 로그인된 Dashboard SQL Editor에서 준비한 20261015112043_wellness_ai.sql을 트랜잭션으로 적용했다. 함수/테이블 존재와 권한을 별도 읽기 쿼리로 재확인했다. CLI migration history 등록은 수행하지 않았다.
- PASS: anon의 두 RPC 실행 거부, authenticated의 context 실행 허용, usage 테이블 직접 접근 거부, RLS 활성화. SQL authenticated 역할의 합성 JWT 두 개로 소유 측정 없음, 3회 허용/4번째 차단, 다른 사용자 quota 분리를 assertion 검증했다. 전체 ROLLBACK 후 합성 usage 행 0개 확인. 실제 Auth 두 계정의 종단간 검증과 동시 부하 검증을 뜻하지 않는다.
- BLOCKED (공급자): 합성 세 수치+목표로 실제 OpenAI 요청 2회, 각각 HTTP 429. 마지막 응답의 안전한 오류 코드 credit_balance_exhausted 확인. Auth와 측정/quota RPC는 이 공급자 검증에서 stub이었다. 실제 AI 추천 성공·모델 접근 가능성을 검증했다고 표시하지 않는다. 사용자의 OpenAI API 크레딧 충전 후 재검증이 필요하다.
- PASS: 코드 0c3f727의 PR CI 38737976307에서 backend, PostgreSQL HTTP, Flutter 포맷/분석/124개 테스트/debug APK, 웹 릴리스 빌드 통과. 문서만 추가한 후 최종 main 배포는 GitHub Actions로 다시 검증한다.
- NOT RUN: 실제 로그인 계정→소유 측정→OpenAI 성공→앱 표시 전체 경로, Android 실기기, 임상·FITRUS·물리 출력. 샘플은 외부 AI에 전송하지 않으며 물리 출력 PROHIBITED/SIMULATOR_ONLY는 유지된다.
- 증거: docs/assets/20261015-ai-sql-applied.png, docs/assets/20261015-ai-quota-rollback-verified.png. 서버 Secret 값은 캡처/문서에 포함하지 않는다.

## 2026-10-15 Gemini 합성 시연 연결

- 승인: 무료 Gemini를 샘플 시연에 연결하며 실제 건강정보를 전송하지 않는다.
- PASS RED→GREEN: 서버의 동의/임의 필드 거절(501 vs400), 화면의 Gemini 시연 진입 부재. 새 클라이언트 검사가 합성 응답 ID 비교 오류를 찾아 수정했다. 테스트 작성 중 괄호 문법 오류는 수정 후 의도한 RED를 재확인했으며 기능 RED로 계산하지 않았다.
- PASS: Backend typecheck 및 전체102개 (`npm test -- --reporter=dot --maxWorkers=1 --no-file-parallelism`). 기본 다중 워커 실행은 로컬 메모리 부족으로 실패해 단일 워커로 재검증했다.
- PASS: Flutter 포맷/분석, 전체128개 (`flutter test --no-pub --concurrency=1 --reporter expanded`). 320px/2배 글자, Gemini 동의/취소, 실제 입력 폐기/JWT 미전송, 잘못된 샘플 응답 차단, 기존 OpenAI·안전 흐름 포함. 실행 중 로컬 Dart IO 스레드 경고가 있었으나 최종128개/exit0이며 CI에서도 확인한다.
- PASS: wellness-sample v1 ACTIVE, apikey 직접 확인, 고정 합성 입력, verify_jwt=false. 실제 wellness-advice는 변경하지 않는다. 문서의 과거 샘플 미연결 상태는 새 합성 시연 계약으로 갱신했다.
- PASS: migration20261015142131_wellness_sample_quota 적용. anon의 실제 측정 RPC/usage 테이블 직접 접근 false. 실제 공개 REST quota 예약19/18/17 후 네 번째 SAMPLE_MINUTE_LIMIT. 이 검증은 Google 호출 없이 공용 일일 한도3회를 소비했다.
- PARTIAL: 일일20회 경계의 운영 SQL transaction assertion은 관리 도구 requestState 오류로 미실행. 운영 카운터를 초기화하거나20회를 소진하지 않았다. 한도 분기/차단 후 provider 미호출은 단위 검사로 검증했다.
- PASS: 배포 endpoint의 context200/고정합성/configured=false, 동의 누락400, 임의 체중 필드400. 서버 Secret 등록 전에는 Gemini를 호출하지 않는다.
- BLOCKED activation: 현재 Supabase 관리 탭 접근이 브라우저 URL 보안 정책으로 차단됐다. 다른 브라우저/토큰 경로로 우회하지 않았다. GEMINI_API_KEY와 GEMINI_SAMPLE_ENABLED=true 서버 Secret 설정이 필요하다. 앱→함수→Gemini 실제 응답, 새 웹/APK 배포는 아직 NOT RUN.
- 이전 개별 합성 Gemini 호출은 HTTP200/스키마 정상(운영 함수와 앱을 통하지 않은 테스트)이다. 이를 앱 연결 완료로 해석하지 않는다. 실제 사용자 정보·CSV 전송 및 Android 실기기/물리 출력 검증은 NOT RUN. PROHIBITED/SIMULATOR_ONLY 유지.

## 2026-10-16 합성 시연 진입 개선

검사 기준: `feat/gemini-sample-20261015`, HEAD `d9e39aea7c9255fc37d042fd93eb4cb8b2942db8` + 이번 미커밋 변경, Windows Flutter 로컬 환경. 기존 미추적 캡처는 보존했다.

- RED: sample_route_scope_test에서 새 주 버튼 부재 2건과 중복 ParticipantShell 발견 1건으로 의도한 FAIL 재현.
- PASS: `flutter test --no-pub test/sample_route_scope_test.dart --reporter expanded` 10/10. 직접 진입, 격리 Mock 로그인, 프로필/측정 이력, 원래 호출 화면으로 복귀, 예약 탭 이동, 320px·글자2배 포함.
- PASS: `flutter pub get`, `dart format --output=none --set-exit-if-changed lib test` 64파일 변경0.
- PASS: `flutter analyze --no-pub` No issues found. 한글 절대 경로의 LSP 초기 JSON 파싱 실패(code255) 후 같은 폴더를 임시 V: 경로로 분석하여 통과.
- PASS: `flutter test --no-pub --concurrency=1 --reporter expanded` 128/128.
- 공개 배포·실제 계정/RLS·실기기·스크린리더 검증 NOT RUN. Backend/API/DB/알고리즘 변경 없음.
- PASS: `flutter build apk --debug --no-pub`, assembleDebug 251.4초, `mobile-app/build/app/outputs/flutter-apk/app-debug.apk`. 기본 합성 모드 debug 빌드이며 공개 웹 배포는 포함하지 않는다.
- 배포 전 PR 검토 보완: 직접 시연 로그인에서 보이는 BackButton 부재를 RED로 재현한 뒤 이전 화면이 있는 로그인에 앱바·뒤로가기를 추가했다. sample_route_scope_test 10/10 재통과(취소 후 재진입 포함). 최종 전체 검증은 GitHub PR/main quality-gates 결과로 확인한다.

## 2026-10-17 합성 시연 중복 로그인 제거

기준 main `2360a21aa0324e8354cd64eb89b80a6db870b36d`의 `fix/sample-start-without-login-20261017` 작업판.

- RED: 합성 시연 준비 화면에 TextField 2개가 존재하여 코드·PIN 입력 부재 회귀 테스트가 의도한 FAIL.
- PASS: `flutter test --no-pub test/widget_test.dart test/sample_route_scope_test.dart --concurrency=1 --reporter expanded` 35/35. 320px·글자2배에서 대상 선택/시연 시작/프로필 반영, Backend 인증 필드 보존, 시연 취소·복귀와 기존 설정/문진 흐름 포함.
- 전체 형식·분석·테스트·APK·웹 빌드와 공개 배포는 같은 최종 커밋의 GitHub quality-gates에서 확인한다. 실계정/RLS·실기기·임상 검증은 이번 변경 검증에 포함하지 않는다.
- 재진입 RED: 샘플 홈에서 첫 시연을 닫고 다시 열면 persona-selector가 없어지는 FAIL 재현. 매 진입을 새 Mock 컨테이너로 분리한 뒤 sample_route_scope_test 11/11 PASS. 높은 근육량 → 홈 복귀 → 중간 근육량으로 새로 시작하는 조작 포함.
- 최종 보완 로컬 형식·정적 분석 PASS. 첫 PR CI는 테스트의 중복 import 1건으로 FAIL하여 제거했다. 최종 커밋 전체 검증은 후속 CI 결과를 따른다.

## 2026-10-17 시연 구획·어깨·완료 흐름 개선

기준 main `f90dbf5dd5b95cf29e20233fcf91ab1a0cd92f9a`의 `ux/demo-journey-20261017` 작업판. Windows Flutter 3.47.4, 동일 작업판을 임시 V: 경로로 실행했다.

- RED→GREEN: 어깨 선택 시 가슴이 함께 칠해지는 픽셀 회귀와 전신 선택의 중첩 색상 회귀를 재현하고 수정했다. 설문 저장 후 완료 요약 부재도 회귀로 재현했다. 초기 SDK 경로·비동기 캡처 문제는 기능 RED로 계산하지 않았다.
- PASS: `flutter analyze --no-pub`, No issues found. `flutter test --no-pub --concurrency=1 --reporter expanded` 전체134개. 320px·글자2배 전체 시연, 저장 실패 후 응답 보존/재시도, 명시적 새 시연/안전 문진, 어깨 픽셀 검사 포함. 발견된 큰 글자 설문 제목/양끝 라벨 overflow를 수정한 후 전체 재통과했다.
- PASS: `flutter build web --release --base-href / --pwa-strategy=none --no-pub`. 기존 웹 의존성의 Wasm dry-run 및 Cupertino font 경고가 있으나 JS 릴리스 빌드 exit0. 기본 합성 모드 로컬 브라우저 배치 확인용이다.
- 실제 AI: 사용자가 유료 기존 API + 사용 한도를 선택하고 API 크레딧 미충전을 확인했다. 운영 wellness-advice ACTIVE v4/verify_jwt=true와 RPC 정의를 읽기 전용으로 확인했다. quota는 사용자 UTC일3회/전체100회 원자적 제한이다. 키 값·실제 측정값 조회나 공급자 호출은 수행하지 않았다. 크레딧 충전과 실제 계정 종단간 응답 성공은 미검증이다.
- 최종 커밋의 APK/웹/전체 CI와 공개 배포는 후속 GitHub Actions 결과를 따른다. 실제 Android·스크린리더·임상·물리 장치 검증 NOT RUN. PROHIBITED/SIMULATOR_ONLY 유지.

## 2026-10-17 측정 결과 문구·따뜻한 색상

기준 main `f1f0708e5134819e06f3828a16b58486a3e48ed9`의 `ux/friendly-measurement-20261017` 작업판, Windows Flutter 3.47.4.

- RED→GREEN: 접힌 상세 보기 밖에 skeletal-muscle-level이 남아 있는 의도한 FAIL 재현. 기본 화면에는 값과 합성 표시만 남기고 등급·지수·한계 설명을 상세 보기에서 확인한 뒤 같은 설정값으로 다음 단계에 진입하는 회귀 통과.
- PASS: `flutter test --no-pub test/widget_test.dart --concurrency=1 --reporter expanded` 26/26. 상세 보기, 시연 대상 반영, 320px·글자2배, 설정·문진·설문 전체 흐름 포함. `flutter analyze --no-pub` No issues found.
- 연구 등급/계산·비교 주의는 상세 보기로 이동했다. 증가·감소에 관계없이 같은 따뜻한 비교 색상을 사용하며 건강 효과를 주장하지 않는다. 추천 계산·API·실제 기기 경계 변경 없음.
- 최종 커밋의 전체 테스트·APK·웹 빌드와 공개 배포는 GitHub quality-gates로 확인한다. 실제 사용자 접근성·임상·물리 장치 검증 NOT RUN.

## 2026-10-17 무료 식사·운동 콘텐츠

기준 main `1ff7d3e41bd17a99421c99223e965b41b527f526`의 `feat/food-movement-guide-20261017` 작업판. Windows Flutter 3.47.4.

- RED→GREEN: 생활 탭에 들어갈 때 측정 AI load가 0회여야 하나 1회 실행되는 회귀를 재현했다. 초기 테스트의 잘못된 탐색 키 실패는 기능 RED로 계산하지 않았다. 기본 안내를 먼저 열고 추가 AI를 펼칠 때만 load 1회임을 확인했다.
- PASS: 식사 조합 전환·방법 표시, 미확인 운동 보류→현재 상태 확인 후 방법 표시→제한 응답 시 즉시 숨김, 측정 없는 추가 AI 상태 표시를 320px/글자1배·2배에서 확인했다. 큰 글자 테스트는 스크롤 후 hit-test 가능한 실제 버튼을 눌러 검증했다.
- PASS: 초기 관련 3개 suite 35개와 후속 큰 글자 신규 흐름 검사. 최종 전체 Flutter·분석·APK·웹 빌드는 최종 커밋의 CI 결과를 따른다.
- 콘텐츠: WHO Healthy diet, NHS Sitting exercises를 2026-10-17 직접 확인한 일반 안내. 실시간 AI 생성/실제 측정 기반 개인 처방으로 표시하지 않는다. 신규 공급자 호출·키 등록·데이터 전송·DB 변경 없음. 기존 Gemini 합성 전용 및 OpenAI 유료 실제 데이터 경계를 유지한다.
- 실제 사용자·스크린리더·임상·물리 장치 검증 NOT RUN. PROHIBITED/SIMULATOR_ONLY 유지.
