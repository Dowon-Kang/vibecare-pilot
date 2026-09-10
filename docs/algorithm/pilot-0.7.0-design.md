# pilot-0.7.0 알고리즘 설계

## 목적과 경계

이 버전은 FITRUS 체성분 4건을 검증하고 근육량 지표를 **연구용으로 층화**한 뒤, Mock 시뮬레이터 후보를 재현한다. 의료 진단·처방 알고리즘이 아니며 모든 결과는 `physicalExecution=PROHIBITED`, 모든 명령은 `executionMode=SIMULATOR_ONLY`다.

## 처리 순서

```text
측정 적격성 확인
→ ASM/SMM 정의 일치 확인
→ 4건 기술통계
→ 연구 층화
→ 안전 게이트
→ 검증되지 않은 시뮬레이션 후보
```

1. 동일 참여자·동일 기기·서로 다른 ID의 정확히 4건인지 검사한다.
2. `muscleDefinition`이 `ASM` 또는 `SMM`으로 확인되고 네 건의 방법·방법 근거·단위·정의 문서·획득 프로토콜이 일치하는지 검사한다. 해당 `method + methodEvidenceRef + definitionRef` 조합이 서버 규칙의 `applicableMethods`에 등록되지 않았거나 `UNKNOWN`, 혼합, 선택 기준 불일치이면 층화와 후보를 만들지 않는다.
3. 근육량 `m_i`에 대해 평균, 표본 표준편차, 변동계수와 범위를 계산한다.

```text
mean = Σmᵢ / 4
sampleSD = √(Σ(mᵢ-mean)² / 3)
CV(%) = 100 × sampleSD / mean
range = max(mᵢ) - min(mᵢ)
index = mean / height(m)²
```

CV에 임의 합격선을 적용하지 않는다. 대신 네 원본 지수가 서로 다른 연구 구간에 걸치면 `MUSCLE_TIER_UNSTABLE`로 검토한다. 30일 유효기간과 미래 5분 허용은 임상 근거가 아니라 명시된 `ENGINEERING_POLICY`다.

4. ASM과 SMM은 다른 분자를 가진 값이므로 상호 변환하지 않는다. SMM 구간은 `INDIRECT`, 현재 ASM 3구간은 두 번째 경계까지 직접 뒷받침하지 못하므로 전체를 `HYPOTHESIS_UNVALIDATED`로 표시한다. 성별은 확인된 정의별 연구 경계를 고르는 데만 쓰며 나이·성별·체지방을 진동값에 곱하지 않는다.
5. 통증·어지럼·전문가 보류는 `BLOCKED`; 데이터·의미·경계 불안정은 `REVIEW`; 조건을 통과한 결과만 `SIMULATION_READY`다.
6. 기존 `180/240/300초`, `12/16/20Hz`, `30/40/50%`는 `HYPOTHESIS_UNVALIDATED` 후보다. 근육량이 이 진동값을 최적화한다는 직접 근거는 없으므로 물리 장치에 사용할 수 없다.

## 근거 수준

| 항목 | 수준 | 해석 |
|---|---|---|
| ASM과 SMM 구분, 근육량만으로 근감소증을 진단하지 않음 | 문헌 근거 | [EWGSOP2](https://pmc.ncbi.nlm.nih.gov/articles/PMC6322506/) |
| 현재 ASM 3구간 경계 | `HYPOTHESIS_UNVALIDATED` | 적용 방법·연령별 근거 확정 전 연구 분류 금지 |
| BIA 반복 측정 조건·수분 상태의 영향 | 문헌 근거 | [ESPEN BIA 지침](https://www.espen.org/documents/BIA2.pdf) |
| WBV는 주파수 외 변위·가속도·파형·자세를 함께 보고 | 문헌 근거 | [WBV 보고 합의](https://doi.org/10.3390/biology10100965) |
| 위험을 식별·통제하고 전 생애주기에서 확인 | 안전 원칙 | [ISO 14971](https://www.iso.org/standard/72704.html) |
| 임상 연관성·분석 검증·임상 검증을 구분 | 평가 원칙 | [IMDRF N41](https://www.imdrf.org/documents/software-medical-device-samd-clinical-evaluation) |
| 정확히 4건, 30일/5분, 경계 교차 검토 | `ENGINEERING_POLICY` | 재현 가능한 파일럿 운영 규칙 |
| 연구 구간→시간·Hz·% 후보 연결 | `HYPOTHESIS_UNVALIDATED` | 전향 검증 전 시뮬레이터에만 사용 |

## 구현과 검증 추적

| 책임 | 구현 | 검증 |
|---|---|---|
| 서버 계산·실패 폐쇄 | `backend-api/src/algorithm.ts` | `backend-api/test/algorithm.test.ts` |
| 규칙 계약 | `backend-api/src/rule-schema.ts`, `shared-contracts/algorithm-rule-set.schema.json` | 타입검사·JSON parse |
| 인가·세션 안전 | `backend-api/src/routes/recommendation-routes.ts`, `session-routes.ts` | `backend-api/test/routes.test.ts` |
| Flutter 미리보기 | `mobile-app/lib/algorithm/vibration_algorithm.dart` | `mobile-app/test/vibration_algorithm_test.dart` |
| 앱 조작·Mock 상태 | `mobile-app/lib/services/mock_device_gateway.dart` | Flutter gateway·widget tests |
| 공통 기준 fixture | `shared-contracts/fixtures/pilot-0.7.0.json` | TypeScript/Dart 회귀검사 |

## 실장비 전 필수 차단 조건

- FITRUS의 근육량 필드 정의, 산출법, 단위, 측정 방법, 획득 프로토콜 확인
- 장치별 `%`와 변위·peak/RMS 가속도·파형·축의 교정
- 승인된 연구 프로토콜과 독립 임상·공학 검토
- 전향 연구, 유해사건 절차, 적용 대상과 금기의 확정

이 항목이 끝나기 전 실제 장치 어댑터와 물리 실행 허가는 구현 완료로 판정하지 않는다.
