# VibeCare 검증 체크리스트

기준일: 2026-09-10
상태: [x] 코드와 검증 증거 있음 · [~] 일부 구현 · [ ] 미구현/외부 차단

## A. 저장소 품질 게이트

- [x] 공개 문서 진입점: `docs/README.md`
- [x] GitHub Actions 구성: 백엔드 typecheck/test, Flutter format/analyze/test/debug APK build
- [x] 실제 환경값 제외: `.env*`, `.dev.vars`, `*.local.txt`, 로컬 상태·빌드 산출물 ignore
- [x] 패키지 버전 잠금: 백엔드 `package-lock.json`, Flutter `pubspec.lock`
- [x] AWS 인계 범위와 미구현 항목 분리
- [~] `pilot-0.7.0` 로컬 품질 게이트 통과, 최신 원격 `quality-gates`는 push 후 확인
- [ ] branch protection에서 `quality-gates` 필수화

## B. 현재 정량 검증

| 검사 | 마지막 결과 | 합격 기준 |
|---|---:|---:|
| 백엔드 전체 Vitest | 43/43 통과 | 실패 0 |
| Flutter 전체 테스트 | 38/38 통과 | 실패 0 |
| 백엔드 TypeScript | 통과 | 오류 0 |
| Flutter format/analyze | 통과 | 오류 0 |
| Flutter debug APK | 최신 main GitHub Actions에서 확인 | 빌드 실패 0 |
| API 계약 | OpenAPI·핵심 JSON Schema 유지 | 참조 오류 0 |

수치는 실행한 자동 검사 기준이며 임상 안전성 수치가 아니다.

## C. 데이터와 FITRUS

- [x] FITRUS API 키는 백엔드 환경변수만 사용
- [x] 공급 API 종류: bodyfat, bp, hr, stress, stress2, bodytemp
- [x] 공급 원본과 앱 표준 DTO의 책임 분리
- [~] FITRUS 서버 전용 client와 오류 전달
- [ ] 공식 요청 형식·인증 헤더·성공/오류 응답 fixture
- [ ] bodyfat 근육 필드가 ASM인지 SMM인지, 산출법·단위·방법 근거 확인 후 `applicableMethods` 등록
- [ ] 실제 응답의 표준 DTO 변환과 `normalized:true`
- [ ] 호출 제한·타임아웃·개발/운영 endpoint 확인
- [ ] 개인정보 보존기간·삭제·접근 감사 정책

## D. 측정과 알고리즘

- [x] 동일 참여자·동일 장치·정확히 네 건 검사
- [x] 중복·결측·비유한수·단위/정의 혼합·BMI/체지방 모순 차단
- [x] 평균·표본 SD·CV·최솟값·최댓값 계산
- [x] ASM/ASMI와 SMM/SMMI 분리, 상호 변환 금지
- [x] 현재/과거 통증·어지럼·사용보류 실패 폐쇄
- [x] `UNKNOWN`·ASM/SMM 기준 불일치·방법/단위/프로토콜 혼합 시 층화·인가 차단
- [x] 공급사가 확인한 ASM/SMM 정의만 앱에서 활성화하고 임의 재해석 차단
- [x] 연령·성별·체지방 진동량 곱셈 미사용(`pilot-0.7.0`)
- [~] 앱·백엔드·공유 fixture의 핵심 결과 parity; 공개 계약 전체 자동 parity는 미완료
- [x] 모든 결과 `physicalExecution=PROHIBITED`, 모든 Mock 명령 `SIMULATOR_ONLY`
- [ ] FITRUS 정의 동등성 검증
- [ ] 신뢰된 정책·이력 Repository와 안전보류 해제 감사
- [ ] 근육량→특정 시간·Hz·물리량의 전향 검증
- [ ] 나이·성별·체지방 개인화 계수의 추정·외부 검증

## E. Flutter 사용자 흐름

- [x] 측정 입력·네 건 평균·추천 결과 표시
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
- [~] D1은 `SqlDatabase` 포트로 사용 중; AWS DB adapter는 미구현
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
