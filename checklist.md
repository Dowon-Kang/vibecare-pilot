# VibeCare 검증 체크리스트

기준일: 2026-09-19
상태: [x] 코드와 검증 증거 있음 · [~] 일부 구현 · [ ] 미구현/외부 차단

## A. 저장소 품질 게이트

- [x] 공개 문서 진입점: `docs/README.md`
- [x] GitHub Actions 구성: 백엔드 typecheck/test, Flutter format/analyze/test/debug APK build
- [x] 실제 환경값 제외: `.env*`, `.dev.vars`, `*.local.txt`, 로컬 상태·빌드 산출물 ignore
- [x] 패키지 버전 잠금: 백엔드 `package-lock.json`, Flutter `pubspec.lock`
- [x] AWS 인계 범위와 미구현 항목 분리
- [x] `pilot-0.7.0` 구현 커밋 `2d15e9f`의 원격 `quality-gates` 통과: [run 34459978932](https://github.com/Dowon-Kang/vibecare-pilot/actions/runs/34459978932)
- [ ] branch protection에서 `quality-gates` 필수화

## B. 현재 정량 검증

| 검사 | 마지막 결과 | 합격 기준 |
|---|---:|---:|
| 백엔드 전체 Vitest | 80/80 통과 (2026-09-21, 근육지수 경계의 반올림 전 판정 회귀검사 포함) | 실패 0 |
| Flutter 전체 테스트 | 57/57 통과 (2026-09-21, 동일 경계 판정·측정 추세 그래프·320px·글자 2배 포함) | 실패 0 |
| 백엔드 TypeScript | 통과 | 오류 0 |
| Flutter format/analyze | V: 영문 경로에서 format·analyze 통과 (2026-09-21) | 오류 0 |
| Flutter debug APK | V: 영문 경로 로컬 debug APK 빌드 통과 (2026-09-21) | 빌드 실패 0 |
| API 계약 | OpenAPI·핵심 JSON Schema 유지 | 참조 오류 0 |

수치는 실행한 자동 검사 기준이며 임상 안전성 수치가 아니다.
2026-09-19에는 골격근량 기준 변경 후 백엔드·Flutter 전체 테스트와 debug APK를 다시 검증했다.

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
