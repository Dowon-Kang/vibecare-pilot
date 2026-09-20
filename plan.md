# VibeCare 구현 계획

> **Owner:** 구현 담당 · **Approver:** 제품·QA 담당
>
> **Update trigger:** 단계 순서, 의존성, 현재 작업 범위 또는 검증 상태가 바뀔 때
>
> **Must not contain:** `docs/project-overview.md`나 공유 계약에 먼저 반영되지 않은 새 요구사항
>
> PLAN은 제품 정답을 바꾸지 않는다. 요구 변경은 관련 문서·계약의 delta를 먼저 승인한 뒤 이 계획에 반영한다.

기준일: 2026-09-10
주 대상: 고령자가 사용하는 발판형 전신진동 연구 앱
현재 릴리스 성격: Mock 중심 연구 프로토타입. 의료 처방·실장비 운영 제품 아님.

## 1. 목표와 완료 정의

FITRUS의 동일 참여자 체성분 측정 4건을 검증·평균하고, 근육량 정의에 맞는 연구용 프로토콜 후보와 그 근거를 표시한다. 안전 문진과 서버 재계산을 통과한 Mock 세션에서 전송·시작·중지·피드백을 재현한다.

이번 프로젝트가 완료되려면 다음이 모두 필요하다.

1. 공급사가 확인한 FITRUS 요청·성공·오류 응답과 ASM/SMM 정의
2. 동일인·동일 BIA 장치의 최신 유효 4건 선택
3. 앱과 서버의 같은 입력·규칙 버전·결과 일치
4. 통증·어지럼·사용 보류의 실패 폐쇄 처리
5. 장치별 Hz·변위·peak/RMS 가속도·자세·하중 교정
6. 실제 장치의 ACK·타임아웃·긴급 중지·재시작 복구
7. 독립 임상·공학 검토와 승인된 전향 검증
8. AWS 인증·DB·비밀관리·감사로그·모니터링

현재는 1, 5, 6, 7, 8이 완료되지 않았다.

## 2. 기준 아키텍처

```text
Flutter mobile-app
  → VibeCare backend-api
    → FITRUS Adapter
    → Algorithm Service
    → Repository interface
    → AWS DB Adapter (미구현)
  → DeviceGateway
    → Mock (구현)
    → REST/BLE real adapter (미구현)
```

- Flutter는 FITRUS API 키와 서버 권위 규칙을 보관하지 않는다.
- 백엔드는 사용자 소유권, 원본 측정, 정책 버전, 안전보류, 실행 허가를 책임진다.
- 알고리즘은 순수 함수로 유지하고 네트워크·DB·장치 부수효과와 분리한다.
- OpenAPI와 JSON Schema가 컴포넌트 연결 형식의 기준이다.
- 실제 명세 전에는 `realDeviceSendAllowed=false`를 유지한다.

## 3. 알고리즘 기준선

| 버전 | 용도 | 상태 |
|---|---|---|
| `pilot-0.8.0` | SMM 4건 평균·6개 부위 기준값·성별/나이/체지방 연구용 보정·Mock 후보 | 연결됨 |
| `pilot-0.7.0` | 이전 ASM/SMM 연구 층화 방식 | 폐기·감사 기록만 보존 |
| `pilot-0.6.0` | 이전 ASM/SMM 가정 선택 방식 | 폐기·감사 기록만 보존 |

현재 구현 기준은 [pilot-0.8.0 설계](docs/algorithm/pilot-0.8.0-design.md)를 따른다.

2026-09-14 추가 연구: [근육량 기반 반응 추론 모델 설계](docs/algorithm/response-model-design.md).
멀티에이전트 문헌·오픈소스 조사와 오프라인 평가 도구 검증을 완료했다.
사용자+설정→반응 예측을 먼저 검증한 후 설정 후보 선택을 평가한다.
실측 학습 자료와 훈련된 모델은 아직 없으며 이 설계가 현재 앱 알고리즘 버전을 대체하지 않는다.

- `pilot-0.8.0`은 확인된 SMM 4건과 프로젝트가 제공한 6개 부위 기준값을 사용한다.
- 기기 출력에 성별·나이·체지방 계수를 곱하되 모두 `HYPOTHESIS_UNVALIDATED` 연구용 가설로 표시한다. 시간과 주파수는 부위 기준값을 유지한다.
- 근육량 계수는 인과 근거가 확보될 때까지 `1.00` 중립값이며, 현재 SMM은 데이터 적격성과 화면 근거에 사용한다.
- Flutter와 백엔드의 Case A~E, 6개 부위, 안전 차단을 검증했다. 공유 계약 전체 자동 deep parity는 **부분 완료**다.

## 4. 구현 단계

### 현재 Build — Supabase PostgreSQL 저장소 연결

상태: **Supabase project and private schema provisioned / backend hosting and HTTP integration pending**

이 단계는 외부 FITRUS·실장비·AWS 계약을 추측하지 않고도 현재 체크리스트의 실제 공백을 줄이는 다음 세로 슬라이스다.

| 계약 항목 | 내용 |
|---|---|
| 목표 | 기존 `SqlDatabase` 포트에 공급자 중립 PostgreSQL 어댑터를 유지하고 Supabase PostgreSQL에 연결한다. |
| 비목표 | Flutter의 DB 직접 접근, Supabase Auth/Data API 도입, 물리 장치 연동, 알고리즘 변경 |
| 선정 | Supabase managed PostgreSQL. 현재 Hono API와 자체 PIN 인증은 유지하고 Session pooler를 서버에서만 사용한다. |
| 허용 파일 | `backend-api/src/storage/`, Node 진입점, PostgreSQL 스키마·환경 예제, 백엔드 테스트·문서·계획 |
| 보존 동작 | 확인 전 실행 금지, 중복 시작 차단, `PROHIBITED`/`SIMULATOR_ONLY`, 실패를 성공으로 표시하지 않기 |
| RED | 어댑터 모듈 부재로 PostgreSQL 포트 회귀 테스트가 실패한다. |
| GREEN | placeholder 변환, `first/all/run`, 원자적 batch, Node 진입점, PostgreSQL 스키마와 합성 seed를 최소 구현한다. |
| VERIFY | 어댑터 집중 테스트 → typecheck/전체 백엔드 테스트 → Docker PostgreSQL migration/seed/HTTP 로그인. AWS 실환경은 `NOT RUN`. |
| 중단 조건 | 기존 SQL 의미 변경, 비밀값 커밋, 실장비 활성화, Docker/AWS 환경 부재 |
| 완료 증거 | 테스트 명령·결과, `/ready`·로그인·측정 조회 응답, 남은 `NOT RUN` 항목 |

이 계약은 구현 승인이 아니다. 구현 전 관련 코드·계약을 다시 조사하고 RED 결과를 확인한다.

### Phase 1 — FITRUS 계약 확정

구현 대상:

- 여섯 공급 API의 인증·요청·성공·오류·단위·제한 문서 확보
- 원본 DTO와 표준 `BodyCompositionMeasurement` 분리
- ASM/SMM/근육량 필드 정의를 공급사 문서로 확인
- 민감 원본의 보존기간·마스킹·접근권한 결정

수정 위치: `backend-api/src/fitrus-client.ts`, 신규 provider adapter, `shared-contracts/`.

완료 조건: 익명화된 실제 응답 fixture로 변환 테스트가 통과하고 `normalized:true`가 검증된 경우에만 반환된다.

### Phase 2 — 연구 알고리즘 고도화

REQ-SIMPLE-01: 기존 계산을 바꾸지 않고 Flutter 계산 근거를 네 단계의 쉬운 설명으로 구현.
범위: `mobile-app/lib/algorithm/calculation_summary.dart`, `mobile-app/lib/screens/pilot_screen.dart`,
`mobile-app/test/calculation_summary_test.dart`, `mobile-app/test/widget_test.dart`,
본 문서와 `checklist.md`.
새 임상계수·설치·실장치 출력·백엔드 정책 변경 없음. 순수 설명 함수와 화면 연결을 검증.

2026-09-15 근거 확장 (REQ-MECH-01~03): 멀티에이전트로 SMM/ASM·인구학·WBV 인과 근거를
반대 검증하고, 처방과 분리된 물리 가설 민감도 계산을 구현한다. 범위:
`backend-api/src/vibration-mechanics.ts`, `backend-api/test/vibration-mechanics.test.ts`,
`docs/algorithm/exa-results/muscle-wbv-causal-design-2026-09-15.md`, 본 문서,
`docs/README.md`와 `checklist.md`.
기존 후보·앱·실행 인가 정책은 변경하지 않는다. 신규 설치·유료 학습·실기기 실험 제외.

구현 대상:

- 서버에서 네 측정으로 근육평가를 다시 계산
- 공급사가 확인한 ASM/SMM 정의를 추천·실행 허가·감사 기록에 동일하게 저장하고 임의 재해석 차단
- 입력·평균·분류·피드백·물리량·근거 수준 표시

완료 조건: Mock 화면에서 `SIMULATION_READY/REVIEW/BLOCKED`, 데이터 결정과 이유 코드가 재현된다. 준비 상태에서도 `SIMULATOR_ONLY` 명령만 만들고 물리 장치 명령은 생성하지 않는다.

### Phase 3 — Supabase 저장·서버 실행 기반

구현 대상:

- 라우트에서 D1 구체 타입을 제거하고 도입한 `SqlDatabase` 포트를 유지
- `SqlDatabase`의 prepare/bind/first/all/run/batch 계약을 구현하는 공급자 중립 PostgreSQL adapter 유지
- Supabase의 비공개 `vibecare` schema와 migration 적용
- Node 서버 진입점, TLS, 배포 환경 비밀 주입과 관측성 준비
- 정책·보류해제·추천·세션의 변경 불가 감사 이력

완료 조건: Supabase remote migration·security/performance advisor·HTTP 통합과 OpenAPI 계약, 장애·롤백·백업 시험이 모두 통과한다. AWS 인프라는 별도 담당자가 [AWS 인계 기준](deployment/aws/README.md)에 따라 이어서 적용할 수 있다.

현재 상태: `SqlDatabase` 포트, PostgreSQL adapter, Node 진입점, 통합 migration을 구현했고 서울 리전의 `vibecare-pilot` Supabase 프로젝트에 비공개 schema를 적용했다. 원격 스키마 버전과 활성 규칙을 확인했으며, 백엔드 호스팅·비밀 주입·HTTP 종단간·RLS 방어 심층화·성능 index 검증은 아직 수행하지 않았다. AWS 운영 인프라는 후속 담당 범위다.

### Phase 4 — 실제 장치 어댑터

구현 대상:

- REST 또는 BLE 명령·ACK·중지·상태 계약
- 장치/펌웨어/자세/하중별 3축 교정
- 일회성 실행 허가, 중복 방지, watchdog, 앱 재시작 복구

완료 조건: 벤치 시험에서 교정 범위·오차·ACK·통신단절·긴급중지를 검증한다. 사람 대상 자동 실행은 아직 금지한다.

### Phase 5 — 전향 연구와 개인화

구현 대상:

- 근육지수, 나이, 성별, 체지방, 노출 물리량, RPE, 통증, 강도·시간·주파수 체감 수집
- 참여자 단위 학습/검증 분리와 사전 정의된 분석계획
- 고정 프로토콜 대비 효과·유해사건·중도탈락률 평가
- 임상·공학 독립 검토와 정책 버전 승인

완료 조건: 코드 테스트와 별개로 승인된 연구 결과가 재현되고, 적용 대상·금기·불확실성이 문서화된다.

## 5. 변경 통제 절차

모든 알고리즘 변경은 다음 순서를 따른다.

```text
요구사항 ID
→ 근거와 적용 대상
→ 실패 사례 fixture
→ TS/Dart 구현
→ 단위·경계·전수 조합
→ 언어 간 전체 출력 비교
→ 회귀검사
→ 독립 검토
→ 새 정책 버전
```

기존 정책을 덮어쓰지 않는다. 근육 정의·정책·장치 교정 중 하나가 바뀌면 기존 결과를 재사용하지 않고 재평가한다.
