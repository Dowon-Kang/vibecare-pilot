# VibeCare 구현 계획

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
| `pilot-0.6.0` | 현재 Flutter·서버의 ASM/SMM Mock 계산 | 연결됨 |

설계 기준은 [근거·수식·안전 명세](docs/algorithm/evidence-based-wbv-algorithm-spec.md)를 따른다.

- `pilot-0.6.0`은 근육지수 등급으로 Mock preset(시간·Hz·강도)을 선택한다.
- 성별은 근육지수 경계 선택에 사용하지만, 나이·성별·체지방을 강도에 곱하는 보정은 사용하지 않는다. 현재 네 곱셈계수는 모두 `1.0`이다.
- 나이는 연구 코호트 범위 확인, 체지방은 입력 일관성 검사와 향후 분석 변수로만 사용한다. 근거 없는 일괄 감산이나 체지방 증가에 따른 자동 증량은 실장비 규칙으로 사용하지 않는다.
- 앱·백엔드·공유 fixture의 핵심 결과 parity는 검증됐지만 공개 계약 전체 필드의 자동 parity는 **부분 완료**다.

## 4. 구현 단계

### Phase 1 — FITRUS 계약 확정

구현 대상:

- 여섯 공급 API의 인증·요청·성공·오류·단위·제한 문서 확보
- 원본 DTO와 표준 `BodyCompositionMeasurement` 분리
- ASM/SMM/근육량 필드 정의를 공급사 문서로 확인
- 민감 원본의 보존기간·마스킹·접근권한 결정

수정 위치: `backend-api/src/fitrus-client.ts`, 신규 provider adapter, `shared-contracts/`.

완료 조건: 익명화된 실제 응답 fixture로 변환 테스트가 통과하고 `normalized:true`가 검증된 경우에만 반환된다.

### Phase 2 — 연구 알고리즘 고도화

구현 대상:

- 서버에서 네 측정으로 근육평가를 다시 계산
- ASM/SMM 선택값을 추천·실행 허가·감사 기록에 동일하게 저장
- 입력·평균·분류·피드백·물리량·근거 수준 표시

완료 조건: Mock 화면에서 UI 추천 상태 `READY/REVIEW/BLOCKED`와 별도 연구 실행 상태·이유 코드가 재현된다. `READY`에서는 Mock 명령만 만들 수 있고 실제 장치 명령은 생성되지 않는다.

### Phase 3 — AWS 저장·실행 기반

구현 대상:

- 라우트에서 D1 구체 타입을 제거하고 도입한 `SqlDatabase` 포트를 유지
- `SqlDatabase`의 prepare/bind/first/all/run/batch 계약을 구현하는 AWS DB adapter 작성
- RDS PostgreSQL 등 확정 DB adapter와 migration 작성
- 컨테이너 또는 Lambda 진입점, Secrets Manager/SSM, CloudWatch
- 정책·보류해제·추천·세션의 변경 불가 감사 이력

완료 조건: [AWS 인계 기준](deployment/aws/README.md), OpenAPI 계약, 장애·롤백·백업 시험이 모두 통과한다.

현재 상태: `SqlDatabase` 포트 분리는 완료됐고 D1이 이를 구현한다. RDS PostgreSQL 등 AWS adapter, migration과 운영 인프라는 미구현이다.

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
