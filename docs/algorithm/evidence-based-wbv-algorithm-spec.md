# 근육량 기반 전신진동 연구 알고리즘 명세

## 1. Executive Summary

이 시스템은 체성분만으로 개인의 “안전한 진동 처방”을 계산하지 않는다. 동일 조건에서 측정한 최근 BIA 4건을 검증하고, ASM 또는 전신 SMM을 서로 다른 근거로 평가한 뒤, 승인·교정된 전신진동(WBV) 연구 프로토콜 후보를 선택한다. 통증·어지럼·사용 보류, 데이터 정의 불일치, 장치 교정 부재 중 하나라도 있으면 실제 명령을 생성하지 않는다.

핵심 결정은 다음과 같다.

- [DIRECT EVIDENCE] ASM과 SMM은 다른 측정량이며 같은 임계값을 적용하지 않는다.
- [DIRECT EVIDENCE] AWGS 2025의 근육 건강 평가는 ASM뿐 아니라 근력과 적용 집단·측정법을 함께 고려한다.[1]
- [DIRECT EVIDENCE] WBV는 `%`가 아니라 실제 주파수, peak-to-peak 변위, peak/RMS 가속도, 파형, 자세, bout와 휴식으로 기술해야 한다.[4]
- [INDIRECT EVIDENCE] WBV가 일부 고령자의 근력·기능에 도움이 될 수 있지만 연구 프로토콜의 이질성이 크고, 특정 체성분에서 특정 용량을 도출하는 공식은 확인되지 않았다.[6][7][8]
- [HYPOTHESIS] 근육량 등급은 초기 안전 단계와 감독 수준을 정하는 층화 변수로 사용하고, 이후 단계는 실제 내약성 이력으로 한 단계씩 조정한다.
- [UNRESOLVED] 장치의 `intensityPct`와 실제 변위·가속도 대응표가 없으므로 현재 실제 출력은 항상 금지한다.

따라서 현재 `12Hz·3분·30% / 16Hz·4분·40% / 20Hz·5분·50%` 규칙은 임상 또는 연구 실행 규칙에서 제외하고, 화면과 회귀 테스트용 합성 데이터로만 보존해야 한다.

## 2. 현재 알고리즘의 냉정한 평가

현재 앱의 `pilot-0.6.0`은 SMMI 등급에 따라 세 가지 값을 반환한다. 예시 여성(72세, 150cm, 평균 SMM 18.1kg)은 `18.1 / 1.5² = 8.04kg/m²`이므로 기존 Janssen 분류에서 참조 등급이 되고 50%가 선택된다.

| 질문 | 판정 | 이유 |
|---|---|---|
| SMMI 계산은 산술적으로 맞는가 | 조건부로 맞음 | 값이 정말 Janssen 방식의 전신 SMM일 때만 의미가 있다. |
| FITRUS 값에 Janssen 경계를 적용할 수 있는가 | 미확인 | 공급사 필드 정의·추정식·검증 모집단이 확인되지 않았다. |
| 30/40/50%에 임상 근거가 있는가 | 없음 | 확인한 RCT는 Hz, mm, 시간으로 노출을 정의하며 이 비율표를 제시하지 않는다. |
| 50%가 물리적 강도인가 | 아님 | 장치별 변위와 가속도 교정표가 없다. |
| 근육량이 많을수록 강한 진동이 적절한가 | 입증되지 않음 | 관찰적 근육량 기준은 WBV 용량-반응의 인과 근거가 아니다. |
| 시간·Hz·%를 동시에 바꾸는가 | 부적절 | 효과 또는 이상반응을 어느 변수에 귀속할지 알 수 없다. |
| 실행 규칙으로 유지할 것인가 | 폐기 | 합성 UI fixture로만 명확히 표시해 보존한다. |

저장소 증거: `mobile-app/lib/algorithm/vibration_algorithm.dart`는 30/40/50%를 직접 포함하고 `AlgorithmResult.realDeviceSendAllowed`를 항상 `false`로 유지한다.

## 3. 확인된 사실과 가설 분리

### 확인된 사실

- [DIRECT EVIDENCE] AWGS 2025는 아시아인의 ASM 평가에 연령·성별·측정법별 기준을 제시하고, 근육량과 근력을 결합한다.[1][2]
- [DIRECT EVIDENCE] EWGSOP2도 근력 저하를 우선하고, 근육량은 진단 확인에 사용한다.[3]
- [DIRECT EVIDENCE] Janssen의 SMMI 경계는 NHANES III의 60세 이상 인구에서 BIA 식으로 추정한 전신 SMM과 기능장애 위험의 연관에서 도출됐다.[5]
- [DIRECT EVIDENCE] 실제 WBV 크기는 사용자 하중, 발 위치, 장치 형식과 파형에 따라 달라질 수 있다.[4]
- [DIRECT EVIDENCE] BIA는 자세, 섭취, 운동, 피부 온도, 수분 상태와 장치별 추정식의 영향을 받는다.[10][11]
- [INDIRECT EVIDENCE] 고령자 WBV 연구에는 6–26Hz, 12–26Hz, 20–60Hz 등 서로 다른 범위와 bout 구조가 사용됐다.[6][7][8]

### 연구 가설

- [HYPOTHESIS] 낮은 근육량은 더 큰 자극의 근거가 아니라 더 보수적인 시작·감독·진행의 근거다.
- [HYPOTHESIS] 최근 동일 단계 세션의 RPE와 강도·주파수·시간 체감은 다음 단계 후보를 정하는 데 사용할 수 있다.
- [HYPOTHESIS] 한 번에 한 변수 또는 사전 승인된 프로토콜 한 단계만 변경하면 반응 귀속과 안전 감사를 개선한다.
- [HYPOTHESIS] 4회 평균과 CV는 우연 변동을 요약하지만 정확도나 임상 타당성을 보증하지 않는다.

## 4. 입력 데이터 사전

| 그룹 | 필드 | 단위/형식 | 필수 | 신뢰 경계 |
|---|---|---:|---:|---|
| 참여자 | participantId | 불투명 ID | 예 | 인증 서버 |
| 참여자 | age, sex, heightCm | year, enum, cm | 예 | 등록 자료 |
| 선택 검사 | gripStrengthKg | kg | ASM 임상 판정 시 필요 | 표준화 측정 |
| BIA | measurementId, deviceId, measuredAt | ID, ID, ISO-8601 UTC | 예 | 공급사 원본 |
| BIA | weightKg, bmi, bodyFatPct, fatMassKg | kg, kg/m², %, kg | 예 | 공급사 원본 |
| 근육 | kind | ASM 또는 SMM | 예 | 공급사 계약 |
| 근육 | massKg, method, definitionRef | kg, BIA/DXA, 버전 ID | 예 | 공급사 계약 |
| 획득 | standardized, protocolRef | bool, 버전 ID | 예 | 연구 운영자 |
| 안전 | acutePain, dizziness, clinicianHold | bool | 예 | 당일 문진/서버 |
| 이력 | stageId, completed, RPE, 세 체감 | ID, bool, 0–10, enum | 적응 시 | 서버 감사로그 |
| 장치 | calibrationId, loadKg, frequencyHz | ID, kg, Hz | 실행 전 | 공학 교정 |
| 장치 | Dpp, peakG, rmsG, waveform | mm, g, g, enum | 실행 전 | 3축 실측 |

체수분·단백질·무기질·기초대사량·내장지방은 화면과 탐색적 분석에는 저장할 수 있지만, 현재 용량 공식에는 넣지 않는다. 체지방은 `fatMassKg / weightKg × 100` 교차검증과 연구 층화에만 사용한다.

## 5. ASM 알고리즘

[DIRECT EVIDENCE] ASM은 양팔과 양다리의 근육 또는 lean soft tissue 합으로 정의된 경우에만 ASMI를 계산한다.

\[
\overline{ASM}=\frac{1}{4}\sum_{i=1}^{4}ASM_i, \qquad
ASMI_h=\frac{\overline{ASM}}{h^2}
\]

AWGS 2025의 높이 보정 BIA 경계는 50–64세 남성 7.6, 여성 5.7kg/m²이고 65세 이상 남성 7.0, 여성 5.7kg/m²다. DXA 경계는 각각 7.2/5.5와 7.0/5.4kg/m²다.[1][2] AWGS 2025는 ASM/BMI 지표도 추가했으므로, 2025 판정을 주장하려면 원 합의문의 결합 규칙과 측정법을 규칙 버전에 고정해야 한다.[2]

권장 출력은 `LOW_MUSCLE_MASS` 또는 `NOT_LOW_MUSCLE_MASS`이며, 근력 입력이 없으면 `sarcopenia=true`를 반환하지 않는다. 공급사 값이 ASM인지 확인되지 않거나 연령·측정법이 기준 범위 밖이면 `REVIEW`다.

## 6. SMM 알고리즘

[INDIRECT EVIDENCE] 전신 SMM에는 ASM 기준을 사용하지 않는다. Janssen 2004의 전신 SMMI 분류를 사용할 수 있는 조건은 다음과 같다.[5]

- 60세 이상이며 해당 참조 집단으로의 이전 가능성을 연구팀이 승인함
- BIA 값이 Janssen 계열의 전신 SMM 정의와 동등함을 공급사 문서로 확인함
- 장치·추정식·단위·definitionRef가 버전으로 고정됨

\[
SMMI=\frac{\overline{SMM}}{h^2}
\]

조건이 충족되면 여성 `≤5.75 / 5.76–6.75 / >6.75`, 남성 `≤8.50 / 8.51–10.75 / >10.75kg/m²`를 각각 높은 기능장애 위험 연관/중간 연관/참조로 기술할 수 있다. 이는 근감소증 진단이나 WBV 용량표가 아니다. FITRUS 정의의 동등성이 확인되지 않은 현재는 SMMI를 연속값으로만 표시하고 `REFERENCE_UNVERIFIED`로 처리해야 한다.

## 7. 측정값 검증 공식

정확히 4건의 동일 참여자·동일 장치·동일 근육 정의·동일 단위·유효 품질 측정만 허용한다.

\[
\bar M=\frac{\sum M_i}{4},\qquad
s=\sqrt{\frac{\sum(M_i-\bar M)^2}{3}},\qquad
CV=100\frac{s}{\bar M}
\]

\[
BMI_{check}=\frac{weightKg}{h^2},\qquad
BF\%_{check}=100\frac{fatMassKg}{weightKg}
\]

현재 소프트웨어 허용오차 `|BMI-BMIcheck|≤0.6`, `|BF%-BF%check|≤1.0 percentage point`는 [HYPOTHESIS] 제품 검증값이다. 공급사 측정오차와 반올림 규칙을 받아 재설정해야 한다. CV 임계값도 장치 반복성 연구 없이 숫자로 확정하지 않는다. 대신 경계 등급이 4건 사이에서 바뀌면 즉시 `RE_MEASURE`로 보낸다.

## 8. 근육량 분류 공식

```text
if kind == ASM:
  verify ASM definition and AWGS-applicable method/age
  calculate ASMI
  report LOW or NOT_LOW
  require grip strength before any sarcopenia label

if kind == SMM:
  verify total-SMM equation equivalence
  calculate SMMI
  if equivalence unverified: continuous value + REVIEW
  else report disability-risk association category

never convert ASM ↔ SMM
never map category directly to device percent
```

## 9. 초기 단계 선택 규칙

초기 단계는 물리값이 아니라 승인된 `protocolId`를 가리킨다.

| 조건 | 초기 결정 |
|---|---|
| 안전 문진 이상 | HOLD |
| 정의·반복성·기준 적용 불명 | RE_MEASURE 또는 REVIEW |
| 장치 교정·연구 승인 없음 | CALIBRATION_REQUIRED 또는 APPROVAL_REQUIRED |
| 낮은 근육량 | [HYPOTHESIS] 감독 필수 적응 단계 S0 후보 |
| 낮지 않은 근육량 | [HYPOTHESIS] 역시 S0 familiarization 후 반응 기반 진행 |
| 유효한 기존 사용자 | 서버의 현재 단계 유지 후 이력 평가 |

근육량만으로 신규 사용자를 즉시 높은 단계에 배치하지 않는다. 근육량 기반 개인화는 시작 단계, 감독 수준, 상향 속도 또는 최대 연구 단계의 제한으로 구현한다.

## 10. 적응 상태 전이 규칙

우선순위는 안전 → 데이터/맥락 → 이전 이상반응 → 최신 반응 → 반복 내약성 순이다.

| 조건 | 전이 |
|---|---|
| 현재 또는 미해제 과거 통증·어지럼·보류 | HOLD |
| 이력 소유자·장치·정책·단계 불일치 | REVIEW |
| 최신 세션 미완료/조기 중단 | HOLD 또는 임상 검토 |
| RPE 상한 초과 또는 하나라도 STRONG | 승인된 한 단계 하향 후보; 최저면 HOLD |
| 목표 RPE, 모두 OK | 현재 단계 유지 |
| 최근 q회 완료, 목표 RPE, 세 항목 모두 WEAK | 승인된 한 단계 상향 검토 후보 |
| 최고 단계에서 WEAK | 유지; 정책 밖 상향 금지 |

`q`, 목표 RPE 범위, 이력 유효기간은 장치별 연구계획서 파라미터다. 현재 fixture의 `q=2`, RPE 2–6, 30일은 임상 기준이 아니다.

## 11. 물리량 변환 공식

이상적인 단일축 정현파에서만 다음 검산식을 쓴다.

\[
A=\frac{D_{pp}}{2}\times10^{-3}\;m
\]

\[
a_{peak,g}=\frac{(2\pi f)^2A}{9.80665},\qquad
a_{rms,g}=\frac{a_{peak,g}}{\sqrt2}
\]

불변식은 `a(2f,D)=4a(f,D)`와 `a(f,2D)=2a(f,D)`다. 이는 기계적 검산이며 신체 전달량이나 안전 한계가 아니다. 비정현파·다축·좌우교대 장치는 발 위치의 3축 실측값을 우선한다.[4]

## 12. 안전 게이트

다음 순서 중 하나라도 실패하면 `command=null`이다.

1. 인증·참여자 소유권
2. 당일 안전 문진 완결
3. 동일 정의 4건 데이터 검증
4. ASM/SMM 적용 근거 확인
5. 승인된 연구 정책과 protocolId
6. 장치·펌웨어·사용자 하중별 유효 교정
7. 주파수·변위·가속도 공학 허용오차
8. 독립 연구자 또는 임상 승인
9. 일회용 실행 허가와 중복방지키
10. 장치 ACK·긴급중지·타임아웃

WBV 연구에서 통증, 어지럼, 혈압 상승, 부종과 낙상성 손상 등이 보고됐으므로 “대체로 경미하다”는 집단 결과를 개인 안전 보증으로 사용하지 않는다.[9]

## 13. 의사코드

```text
evaluate(input):
  if currentSafety.anyTrue: return BLOCKED
  if safetyIncomplete: return REVIEW

  rows = selectLatestFourSameParticipantDeviceDefinition(input.rows)
  if rows.count != 4: return RE_MEASURE
  if !crossChecksPass(rows): return RE_MEASURE

  stats = meanSdCv(rows.muscleMass)
  assessment = kind == ASM
    ? assessAsm(stats, profile, method, definitionRef)
    : assessSmm(stats, profile, method, definitionRef)
  if assessment.referenceUnverified: return REVIEW

  transition = adaptUsingAuthenticatedHistory(assessment, history, policy)
  if transition has no candidate: return transition.state

  protocol = exactApprovedProtocol(transition.protocolId)
  if protocol missing: return PROTOCOL_REQUIRED
  if calibration missing or expired: return CALIBRATION_REQUIRED
  if measuredOutputOutsideTolerance: return CALIBRATION_REVIEW
  if independentApproval missing: return APPROVAL_REQUIRED

  return READY_CANDIDATE(command=null, authorizationRequired=true)
```

## 14. 상태 전이표

```text
RE_MEASURE ──유효 4건──▶ REVIEW
REVIEW ──정의·정책 승인──▶ PROTOCOL_REQUIRED
PROTOCOL_REQUIRED ──프로토콜 승인──▶ CALIBRATION_REQUIRED
CALIBRATION_REQUIRED ──교정 통과──▶ INDEPENDENT_REVIEW_REQUIRED
INDEPENDENT_REVIEW_REQUIRED ──별도 실행허가──▶ READY
READY ──ACK──▶ RUNNING ──완료──▶ FEEDBACK_REQUIRED
어느 상태든 안전 이상/연결 상실──▶ HOLD/STOPPED
```

## 15. JSON 입력·출력 예시

```json
{
  "profile": {"participantId":"P-opaque","age":72,"sex":"female","heightCm":150},
  "measurements":[
    {"id":"M1","participantId":"P-opaque","deviceId":"BIA-1","measuredAt":"2026-09-01T09:00:00.000Z","qualityPassed":true,"weightKg":42,"bmi":18.67,"bodyFatPct":18.8,"fatMassKg":7.9,"muscle":{"kind":"SMM","method":"BIA","massKg":18.1,"definitionRef":"FITRUS-DEFINITION-PENDING"}}
  ],
  "safety":{"acutePain":false,"dizziness":false,"clinicianHold":false},
  "acquisition":{"standardized":false,"measurementDefinitionVerified":false,"protocolRef":""}
}
```

```json
{
  "state":"DATA_REVIEW",
  "reasonCodes":["MEASUREMENT_DEFINITION_UNVERIFIED","INSUFFICIENT_DATA"],
  "assessment":null,
  "selectedProtocol":null,
  "command":null,
  "realDeviceSendAllowed":false
}
```

예시는 실제 참여자나 처방이 아닌 계약 설명용 합성 데이터다.

## 16. 경계값 및 반례 테스트

필수 자동 테스트는 다음과 같다.

- 정확히 4건의 평균·표본 SD·CV
- 3건/5건, 중복 ID, 동일 시각 충돌
- 다른 참여자·BIA 장치·단위·definitionRef 혼합
- ASM/SMM 혼합과 근거 없는 변환 시도
- NaN, Infinity, 0, 음수, 비현실 범위
- BMI 및 체지방량 교차검증 경계
- ASM/SMM 임계값 바로 아래·같음·바로 위
- 50세/60세/65세 적용 범위 경계
- 근력 누락 상태에서 근감소증 확정 금지
- 현재 및 과거 통증·어지럼 우선 차단
- RPE 상한, 세 체감 중 하나만 STRONG
- q회 미만, 다른 단계·장치·정책 이력
- 한 번에 두 단계 이동과 미승인 transition 금지
- 최고/최저 단계 경계
- 교정 만료·장치 ID 불일치·허용오차 초과
- `f×2 → theoretical acceleration×4` 속성
- 앱/서버 공통 fixture 완전 동등성
- 중복 탭·ACK 미수신·앱 백그라운드 안전 중지

오픈소스 `fast-check`는 임의 입력과 축소 가능한 반례의 참고 구현이고, XState guard 개념은 순수 조건 함수와 명시적 우선순위의 참고다. 라이브러리 채택 자체가 생물의학적 타당성을 제공하지 않는다.[12][13]

## 17. 구현 모듈 설계

| 모듈 | 책임 | 현재 위치 |
|---|---|---|
| MeasurementGate | 4건·소유권·교차검증 | `mobile-app/lib/algorithm/vibration_algorithm.dart`, `backend-api/src/algorithm.ts` |
| MuscleAssessment | ASM/SMM 별도 지수·적용범위 | 같은 두 알고리즘 파일 |
| FeedbackPolicy | 불편 응답의 감산·보류 | `mobile-app/lib/models/models.dart`, `backend-api/src/feedback.ts` |
| Flutter preview | 앱 미리보기 순수 함수 | `mobile-app/lib/algorithm/vibration_algorithm.dart` |
| Server authority | 소유권·정책·최종 Mock 허가 | `backend-api/src/` |
| DeviceGateway | ACK·중지·중복 방지 | 현재 Mock 중심; 실장치 명세 미확보 |

현재 연결된 알고리즘은 `pilot-0.6.0`뿐이다. 화면은 알고리즘 버전과 `SIMULATION / CALIBRATION_REQUIRED / READY`를 명확히 보여야 한다.

## 18. Flutter–Backend–Device 데이터 흐름

```text
FITRUS API
  → Backend provider adapter: 원본 보존·정규화·definitionRef 부착
  → DB: 원본과 정규화 데이터 분리
  → MeasurementGate: 최근 동일 조건 4건
  → MuscleAssessment: ASM 또는 SMM 경로
  → AdaptationPolicy: 서버 이력과 승인 정책
  → ProtocolReadiness: 정확한 protocolId와 교정 비교
  → Flutter: 입력·평균·근거·상태 표시
  → Authorization API: 서버 재계산 및 일회용 허가
  → DeviceGateway: 명령·ACK·실행·중지
  → SessionEvent/Feedback: 실제 조건과 반응 감사로그
```

API 키는 Flutter에 넣지 않고 백엔드 비밀 저장소에서만 사용한다. 앱의 계산은 설명 가능한 미리보기이며 서버의 승인 결과와 다르면 전송을 차단한다.

## 19. 아직 확보해야 할 장치 정보

- 장치 제조사·모델·펌웨어
- 수직/좌우교대/다축 구동과 파형
- `%` 또는 PWM의 정의와 해상도
- 각 Hz·%·하중별 peak-to-peak 변위
- 플랫폼과 발 위치의 3축 peak/RMS 가속도
- 주파수 정확도, 고조파와 충격 성분
- 사용자 체중 범위와 발 위치 영향
- 연속 동작·bout·휴식 제한
- 손잡이·자세·무릎 각도·신발 조건
- 명령, ACK, watchdog, 긴급중지 통신 명세
- 교정 절차·유효기간·허용오차 승인자

## 20. 임상·연구 승인 전 금지해야 할 기능

- 체지방·나이·성별로 임의 강도 곱셈
- 근육량이 많다는 이유로 자동 상향
- 장치 %를 g 또는 mm처럼 표시
- 미교정 장치에 명령 전송
- REVIEW/BLOCKED 상태 우회
- 앱 로컬 이력만으로 보류 해제
- AI가 새로운 Hz·시간·강도를 생성
- “안전”, “치료”, “처방”, “근감소증 진단”으로 표시
- 실제 개인정보·API 키·원본 건강데이터를 Git 또는 로그에 저장

## 21. 근거 논문 표

| 출처 | 설계/표본 | 장치 조건 | 직접 사용할 수 있는 결론 |
|---|---|---|---|
| AWGS 2025[1] | 아시아 근육 건강 합의 | ASM, 근력, 연령·성별·방법별 기준 | ASM 판정 범위와 근력 필요성 |
| EWGSOP2[3] | 유럽 전문가 합의 | 근력→근육량→기능 | 근육량 단독 진단 금지 |
| Janssen 2004[5] | NHANES III 60세 이상 4,449명 관찰 | BIA 추정 전신 SMM/키² | 조건부 SMMI 기능장애 연관 |
| WAVEX 2021[4] | 국제 전문가 보고 합의 | Hz, Dpp, peak/RMS g, 파형, 자세, 하중 | WBV 물리량·교정·보고 계약 |
| Wei 2017[6] | 근감소 고령자 80명 RCT | 20Hz×720s, 40Hz×360s, 60Hz×240s; 4mm | 주파수·시간 조합 효과가 동일하지 않음 |
| Wadsworth·Lark 2020 및 관련 파일럿[7] | 허약 고령자 117명 RCT와 앞선 44명 파일럿 | 6–26Hz, 1–4mm, 1분 bout 점진 진행 | 낮은 단계·bout·감독 기반 진행 사례 |
| Piitulainen 등 2024[8] | 고령자 130명 RCT | 12/18/26Hz, 1분 bout·휴식, 하중별 가속도 실측 | 주파수만이 아니라 하중·변위·g가 중요 |
| de Oliveira 등 2023[9] | 고령자 연구 34편 체계적 문헌고찰·메타분석 | 5–60Hz, <0.1–14mm 등 다양한 프로토콜 | 효과 가능성과 이상반응·이질성 |
| ESPEN BIA 지침[10] | 성인 BIA 임상 지침 | 표준 자세·섭취·운동·온도 | 측정 조건 표준화 필요 |

## 22. 알고리즘 한계

- 문헌 검색은 체계적 문헌고찰 등록·이중 선별·비뚤림 평가를 수행한 새 리뷰가 아니다.
- 4회 평균은 제품 요구사항이며 최적 반복 횟수라는 임상 근거가 없다.
- FITRUS의 골격근량이 ASM인지 전신 SMM인지 아직 계약으로 확인되지 않았다.
- AWGS 2025의 ASM/BMI 결합 판정 전체를 현재 코드가 구현하지 않았다.
- Janssen 경계는 미국 NHANES III의 특정 BIA 추정식과 기능장애 위험에서 왔으며 한국 사용자·FITRUS로의 이전은 간접적이다.
- 확인한 RCT는 체성분별 개인 용량 공식을 제공하지 않는다.
- RPE와 WEAK/OK/STRONG을 WBV 단계 조절에 사용하는 정확한 q·범위는 검증되지 않았다.
- 물리 공식은 이상적 정현파 계산이며 실제 신체 전달량이 아니다.
- 현재 새 연구 알고리즘은 Flutter 화면·백엔드 route·실장치에 활성화되지 않았다.

## 23. 다음 실험 계획

1. **정의 연구:** FITRUS 요청·응답, ASM/SMM 정의, 추정식, 단위, 반복성 자료를 공급사로부터 확보한다.
2. **공학 교정:** 3축 가속도계로 무부하 및 대표 하중에서 모든 Hz·% 조합의 Dpp, peak/RMS g, 파형을 측정한다.
3. **정책 동결:** 임상·공학 책임자가 장치별 S0–Sn 후보, 자세, bout, 휴식, 중단 기준을 승인한다.
4. **분석 검증:** 합성 fixture, 경계값, 속성 테스트와 TypeScript/Dart 동등성을 통과한다.
5. **사용성 시험:** Mock 출력으로 고령자의 이해도, 오조작, 중지 접근성과 큰 글자 환경을 평가한다.
6. **전향 파일럿:** 승인된 연구계획에서 낮은 단계부터 감독하에 적용하고 이상반응·RPE·완료율·기능 결과를 수집한다.
7. **모델 검증:** 참여자 단위로 개발/검증을 분리하고 고정 프로토콜 대비 적응 정책의 안전성과 효과를 비교한다.
8. **운영 전환:** 독립 검토, 감사로그, 실행 허가, watchdog, 보류 해제 절차가 모두 검증된 뒤에만 실장치 전송을 활성화한다.

---

## Sources

1. Chen LK, et al. “[A focus shift from sarcopenia to muscle health in the Asian Working Group for Sarcopenia 2025 Consensus Update](https://www.nature.com/articles/s43587-025-01004-y).” *Nature Aging*. 2025. DOI: 10.1038/s43587-025-01004-y.
2. Kim M, et al. “[Prevalence of Sarcopenia in Korean Adults Based on the Asian Working Group for Sarcopenia 2025 Criteria](https://www.jkms.org/DOIx.php?id=10.3346%2Fjkms.2026.41.e256).” *Journal of Korean Medical Science*. 2026.
3. Cruz-Jentoft AJ, et al. “[Sarcopenia: revised European consensus on definition and diagnosis](https://pmc.ncbi.nlm.nih.gov/articles/PMC6322506/).” *Age and Ageing*. 2019.
4. van Heuvelen MJG, et al. “[Reporting Guidelines for Whole-Body Vibration Studies](https://pmc.ncbi.nlm.nih.gov/articles/PMC8533415/).” *Biology*. 2021. DOI: 10.3390/biology10100965.
5. Janssen I, et al. “[Skeletal muscle cutpoints associated with elevated physical disability risk in older men and women](https://pubmed.ncbi.nlm.nih.gov/14769646/).” *American Journal of Epidemiology*. 2004.
6. Wei N, et al. “[Optimal frequency/time combination of whole body vibration training for developing physical performance of people with sarcopenia](https://pubmed.ncbi.nlm.nih.gov/28933611/).” *Clinical Rehabilitation*. 2017. DOI: 10.1177/0269215517698835.
7. Wadsworth D, Lark S. “[Effects of Whole-Body Vibration Training on the Physical Function of the Frail Elderly](https://pubmed.ncbi.nlm.nih.gov/32145279/).” *Archives of Physical Medicine and Rehabilitation*. 2020; 관련 파일럿 RCT: [PMID 23864514](https://pubmed.ncbi.nlm.nih.gov/23864514/).
8. Piitulainen H, et al. “[Effect of 10-Week Whole-Body Vibration Training on Falls and Physical Performance in Older Adults](https://pmc.ncbi.nlm.nih.gov/articles/PMC11276669/).” *International Journal of Environmental Research and Public Health*. 2024.
9. de Oliveira RG, et al. “[Impacts of Whole-Body Vibration on Muscle Strength, Power, and Endurance in Older Adults](https://pmc.ncbi.nlm.nih.gov/articles/PMC10342949/).” *Journal of Clinical Medicine*. 2023.
10. Kyle UG, et al. “[Bioelectrical impedance analysis—part II: utilization in clinical practice](https://www.espen.org/documents/BIA2.pdf).” *Clinical Nutrition*. 2004.
11. ESPEN and EASO. “[Definition and Diagnostic Criteria for Sarcopenic Obesity](https://pmc.ncbi.nlm.nih.gov/articles/PMC9210010/).” 2022.
12. dubzzz. “[fast-check documentation](https://fast-check.dev/docs/introduction/getting-started/).” Accessed 2026.
13. Stately. “[XState guards documentation](https://stately.ai/docs/guards).” Accessed 2026.
14. ISO. “[ISO 2631-1:1997 — Evaluation of human exposure to whole-body vibration](https://www.iso.org/standard/7612.html).” Confirmed 2021; revision in progress. 이 표준은 치료 용량표로 직접 사용하지 않는다.
