# VibeCare Flutter 전환 체크리스트

각 작업은 완료 조건, 검증 명령, 증거 파일을 채운 뒤에만 완료 처리한다.

상태 표기: `[x]` 구현·검증 완료, `[ ] 부분 완료` 추가 검증이나 실연동 필요, `[ ] 차단` 외부 명세 필요, `[ ]` 미착수.

## 현재 구현 요약

| 영역 | 상태 | 남은 완료 조건 |
|---|---|---|
| Flutter Mock 사용자 흐름 | 검증 완료 | 실 FITRUS 정규화와 실제 물리 Android 기기 QA |
| 최근 유효 4건과 전체 평균 | 검증 완료 | 실 FITRUS fixture 검증 |
| Worker 인증·측정·추천·Mock 세션 | 부분 완료 | 라우트 D1 통합 테스트와 배포 환경 구성 |
| FITRUS 실연동 | 차단 | 요청·응답·단위 계약 확보 및 정규화 어댑터 작성 |
| 실제 진동기 | 차단 | REST/BLE·ACK·중지·물리 출력 교정 명세 확보 |

## 0. 외부 차단 조건

- [x] FITRUS API base URL·POST 방식·`x-api-key` 요구 확인
  - 증거: `docs/evidence/fitrus-api-contract.md`
- [x] 제공된 키로 인증 통과 여부 확인(키 값은 프로젝트·로그에 미저장)
- [ ] 운영 환경의 암호화된 `FITRUS_API_KEY` 등록·회전 정책 수립
- [ ] 운영 비밀값 등록 검증 후 사용자 승인 아래 평문 키 파일 제거
- [ ] FITRUS 요청 스키마·성공 응답 4건·단위·오류코드 전체 확보
  - 완료 조건: 공급사 예제 응답이 `packages/contracts/bia-measurement.schema.json` 검증을 통과한다.
  - 증거: `docs/evidence/bia-api-validation.md`
- [ ] 진동기기 통신방식 REST/BLE 확정
  - 완료 조건: 연결, 시작, 중지, ACK, 상태, 타임아웃, 오류코드 명세가 있다.
  - 증거: `docs/evidence/device-protocol.md`
- [ ] 기기 출력 물리량 확보
  - 완료 조건: 단계별 Hz·진폭·가속도, 접촉부위, 최대시간, 안전상한이 확인된다.
  - 증거: `docs/evidence/device-calibration.md`

## 1. 개발환경

- [x] Flutter stable 설치
  - 완료 조건: `flutter --version`이 stable channel을 표시한다.
- [x] Android Studio·Android SDK·Java 17 이상 설정
  - 완료 조건: `flutter doctor -v`의 Android toolchain 오류가 없다.
- [x] Android 35 Pixel 7 에뮬레이터 생성·연결·APK 설치
  - 완료 조건: `flutter devices`에서 Android 장치가 표시된다.
  - 증거: AVD `VibeCare_Pixel_7_API35`, package `com.vibecare.pilot` 설치·실행 확인
- [x] Android SDK 라이선스 승인
  - 검증: `flutter doctor --android-licenses`

## 2. Flutter 기반구조

- [x] Android 구조, package ID `com.vibecare.pilot`, API 24, Java 17 설정 및 debug APK 빌드
  - 증거: `docs/evidence/toolchain-status.md`
- [x] GitHub 오픈소스 후보·라이선스·논문 적용 한계 문서화
  - 증거: `docs/open-source-and-evidence.md`
- [ ] Flutter/NPM 직접·전이 의존성 라이선스 검사와 SBOM 생성
- [x] Material 3 테마와 한국어 기본 로케일 적용
- [x] Riverpod 상태관리, Dio canonical API repository, secure storage 구현체 구성
- [ ] dev·staging·prod 환경과 API base URL 분리
- [x] 제공된 FITRUS 키가 APK·로그·Git 작업 폴더에 포함되지 않는지 값 기반 검사
  - 결과: 프로젝트 내 일치 0건. 운영 secret 등록과 정기 자동 검사는 별도 필요.

## 3. 인증과 참여자 흐름

- [x] 참여자 코드+6자리 PIN 로그인 화면과 Mock 인증 구현
- [ ] 부분 완료 — Worker PIN 5회 실패 시 15분 잠금 구현
  - 남은 조건: Flutter 잠금 종료시각 표시와 D1 통합 테스트
- [ ] 부분 완료 — access/refresh token 발급·검증과 secure storage 구현
  - 남은 조건: Flutter 실 API 인증 전환과 토큰 자동갱신
- [x] Worker에서 토큰 participant ID로 본인 BIA 데이터만 조회
- [ ] 세션 만료·네트워크 오류·오프라인 상태 안내

## 4. BIA 수신과 4회 평균

- [ ] 부분 완료 — 공급사 독립 BIA DTO와 Worker canonical adapter 구현
  - 남은 조건: FITRUS 성공 응답 예제로 공급사 정규화 adapter 완성
- [x] 동일 사용자·동일 기기의 최근 유효 4건 선택
- [x] 필수 숫자, 품질상태, 중복 측정 ID 검사
- [x] 체중·BMI·체지방률·체지방량·골격근량과 선택 7항목 평균 구현
- [x] 체지방량/체중과 BMI/키·체중 일관성 검사
- [x] 평균에 사용한 측정 ID를 앱 결과와 Worker measurement set에 저장

## 5. 알고리즘 이식

- [x] TypeScript `pilot-0.3.0`을 순수 Dart 모듈로 이식
- [x] 연령 70세 이상 ×0.90 적용
- [x] 여성 ×0.95, 남성 ×1.00 적용
- [x] 여성 체지방 20~35%, 남성 10~28% 밖 ×0.90 적용
- [x] 결과를 20~70%로 clamp
- [x] 통증·어지럼·사용보류는 `BLOCKED`
- [x] 평균 BMI 18.5 미만은 `REVIEW`
- [ ] 부분 완료 — D1 AlgorithmRuleSet 저장·현재 규칙 API·서버 적용 구현
  - 남은 조건: Flutter 규칙 동기화 및 변경 승인 운영화
- [x] Dart·서버·기존 TypeScript 공통 fixture 결과 일치 확인
  - 증거: `docs/evidence/algorithm-parity.md`
- [ ] 부분 완료 — 서버 algorithm version 불일치 차단 구현
  - 남은 조건: Flutter가 서버 계산값과 필드별 비교
- [ ] 평균과 함께 표준편차·범위를 저장하고 임계치 초과 시 `REVIEW`
- [ ] 사전 정의된 파일럿 통계분석계획과 규칙 승격 절차 승인

## 6. 간편 화면

- [x] Mock 로그인→API 상태→추천·조절→전송→시작→중지의 모바일 핵심 흐름 구현
- [x] API 상태·장치 상태·적용 강도·시간·Hz를 첫 화면에서 확인 가능
- [x] 자동 권장값 이하 수동 강도 Slider·Stepper와 자동값 복원 구현
- [x] `장치로 보내기`와 `진동 시작`을 분리하고 실행 중에는 고정 `진동 중지`로 전환
- [x] 원본 4건·전체 평균·생체신호와 보정·안전 설정을 하단 상세 시트로 분리
- [x] 체성분 12항목 원본과 평균, 표시 전용 생체신호 구현
- [x] 원본 4건과 보정 사유를 펼침 영역에 배치
- [x] `REVIEW/BLOCKED`에서 실행 버튼 비활성화
- [x] 실행 중 남은 시간·연결상태·즉시 중지 구현
- [x] 나이·성별 변경 시 보정계수와 권장 강도 즉시 재계산
- [x] FITRUS 4회 평균 체지방률을 읽기 전용 보정 입력으로 표시
- [ ] 부분 완료 — 52dp 이상 주요 터치영역과 남은 시간 TalkBack live region 적용
  - 남은 조건: 큰 글자·실기기 TalkBack 위젯 검증

## 7. Workers와 D1

- [x] Workers 프로젝트 기본 구성
- [ ] staging/prod 환경과 실제 D1 ID 구성
- [x] D1 초기·확장 마이그레이션과 핵심 테이블 작성 및 로컬 적용
- [x] PBKDF2 PIN 해시, 로그인 잠금, 서명 access/refresh token 구현
- [ ] 부분 완료 — FITRUS 원본 보존과 canonical 조회 구현
  - 남은 조건: 공급사 응답 기반 bodyfat·vitals 정규화
- [x] FITRUS 6개 경로 allowlist와 서버 전용 API 클라이언트 구현
- [ ] FITRUS 성공 응답 명세 기반 `bodyfat` 표준 DTO 변환 구현
- [x] 서버 authoritative 평균·추천 재계산의 1차 구현
- [x] 1회성·60초 만료·참여자·기기 결합 실행 허가 구현
- [x] Idempotency-Key와 Mock 명령·ACK·중지 이벤트 저장

## 8. 기기 게이트웨이

- [x] `DeviceGateway` 공통 인터페이스 구현
- [x] `MockDeviceGateway` 구현
- [x] API base URL 설정 시 Worker 실행 허가·세션·중지 API를 사용하는 `ServerDeviceGateway` 구현
- [x] 앱 미리보기와 서버 시간·Hz·강도가 다르면 실행 차단
- [ ] REST/BLE 공급사 어댑터 계약 테스트 작성
- [ ] 통신방식 확정 후 실제 게이트웨이 하나 구현
- [ ] 부분 완료 — Mock 연결·허가·시작·ACK·중지 상태머신 구현
  - 남은 조건: 실기기 타임아웃·재시도 계약 테스트
- [x] Mock과 Worker에서 중복 실행·만료 허가 차단
- [ ] 부분 완료 — 앱 백그라운드 전환 시 Mock 안전 중지 구현
  - 남은 조건: 실기기 연결 해제·오류 검증

## 9. 테스트와 릴리스

- [x] 순수 Dart 검증과 Flutter test runner에서 parity·최근 유효 4건 선택 통과
- [x] 알고리즘 parity 테스트: 여성 예제 38%, 동일 값 남성 45%
- [x] 안전 테스트: 통증·어지럼·사용보류 시 추천·실행 차단
- [ ] 부분 완료 — 위젯 테스트: 로그인, 핵심 상태, 수동 강도, 상세 시트, 전송·시작·중지, 320×568 오버플로 통과
  - 남은 조건: 큰 글자, 오류상태, TalkBack 검증
- [ ] 통합 테스트: 로그인→BIA→추천→Mock 실행→피드백
- [ ] 장애 테스트: 네트워크 단절, ACK 미수신, 중복 요청, 앱 백그라운드
- [x] `dart analyze` 오류·경고 0, `flutter test` 10/10 통과
- [x] 내부 시험용 `flutter build apk --release`와 `flutter build appbundle --release` 통과
  - 주의: 현재 release 빌드는 debug 키로 서명됨. 배포용 keystore와 CI secret 설정 전에는 스토어 배포 금지.
- [ ] 실제 Android 기기에서 TalkBack·작은 화면·긴 문구 확인
- [ ] 실제 기기 제한 시험과 긴급중지 검증 후에만 출력 활성화

## 진행 기록

| 날짜 | 단계 | 결과 | 검증 명령/증거 | 담당 |
|---|---|---|---|---|
| 2026-09-03 | 근거·OSS | 논문 적용범위와 라이선스 후보 문서화 | `docs/open-source-and-evidence.md` | Codex |
| 2026-09-03 | 알고리즘 | TS 5건, Worker 3건, Dart 검증 통과 | `docs/evidence/algorithm-parity.md` | Codex |
| 2026-09-03 | 환경 | Flutter CLI 초기화와 Android SDK 미설치 확인 | `docs/evidence/toolchain-status.md` | Codex |
| 2026-09-06 | FITRUS API | 6개 POST 경로·서버 전용 키 처리 확인 및 어댑터 테스트 | `docs/evidence/fitrus-api-contract.md` | Codex |
| 2026-09-06 | Flutter Mock | 로그인·전체 원본/평균·vitals·안전·추천·Mock 실행 UI 연결 | `apps/mobile/lib/` | Codex |
| 2026-09-06 | Workers | 인증·측정 조회·규칙·추천·Mock 세션·중지·피드백 API 구현 | `services/api/src/`, `packages/contracts/openapi.yaml` | Codex |
| 2026-09-06 | Android | Flutter 3.47.2·SDK 36·Java 21, 테스트 7개 및 debug APK 통과 | `docs/evidence/toolchain-status.md` | Codex |
| 2026-09-07 | Flutter 입력·전송 | 나이·성별 즉시 재계산, Worker 서버 게이트웨이, Android 35 에뮬레이터 설치·실행 | `apps/mobile/lib/`, `flutter test` 10/10 | Codex |
| 2026-09-07 | 모바일 UX | 첫 화면 상태·강도 조절·고정 CTA, 전송/시작 분리, 실행 카운트다운·중지 및 에뮬레이터 시각 QA 완료 | `apps/mobile/lib/presentation/pilot_screen.dart`, `apps/mobile/test/widget_test.dart` | Codex |
| 2026-09-06 | D1 | 초기·확장 마이그레이션 로컬 적용 성공 | `services/api/migrations/` | Codex |
| 2026-09-06 | Android 릴리스 | 내부 시험용 release APK 48.7MB·AAB 47.7MB 생성, package/min/target SDK 확인 | `docs/evidence/toolchain-status.md` | Codex |
