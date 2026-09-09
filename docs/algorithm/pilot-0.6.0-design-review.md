# pilot-0.6.0 — 근육량 연구 알고리즘 설계 심사

검토일 2026-09-09. 코드 변경 전 작성한 설계. 실제 처방이나 안전 인증이 아니다.

## 1. 결론

근육량→최적 진동 용량을 추정할 개인별 반응 데이터가 없다. 따라서 기존 세 단계는 **시뮬레이션용 실험 조건 선택기**로만 유지한다. FITRUS 값이 Janssen 전신 SMM과 동등하다는 증거가 없어 지표 이름은 `추정 근육지수(연구용)`로 제한한다. 물리 출력 가능 여부는 별도 실행 게이트로 계산한다. 기존 70세 이상 0.90 감산은 근거 없는 연령 절벽을 만들므로 제거한다. 낮은 주파수=안전이라는 기존 설명을 철회한다.

## 2. 저장소 증거 심사

아래 표는 **변경 전 v0.5 감사 결과**다. 현재 수정·검증 결과는 [v0.6 검증 기록](../evidence/pilot-0.6.0-validation.md)에서 구분한다.

| 주장 | 상태 | 증거 파일/함수 | 한계 |
|---|---|---|---|
| 4건 골격근량·키·성별이 기본 조건을 결정 | CONFIRMED | backend-api/src/algorithm.ts calculateRecommendation; mobile-app/lib/algorithm/vibration_algorithm.dart | 임상 검증 없음 |
| 최신 동일인·동일기기 선택 | CONFIRMED | backend-api/src/index.ts latestValidSql; Dart selectLatestValidMeasurements | 당시 시간 정렬·중복·숫자 검증만; 측정환경 기록 없음 |
| FITRUS 실측 입력이 앱까지 연결됨 | UNKNOWN | backend-api/src/fitrus-client.ts; index.ts normalized:false | 공급사 성공 응답 정규화 미구현; Mock와 구분 |
| 3개 구현이 모든 입력에서 일치 | 반증 CONFIRMED | 웹/서버는 SMMI 2자리 반올림 후 분류, Dart는 분류 후 반올림 | 기존 fixture는 경계 결함을 발견하지 못함 |
| 증상·BMI 게이트 | CONFIRMED | 세 calculate 함수 | BMI 18.5는 WBV 안전 임계값으로 검증되지 않음 |
| 실제 출력 어댑터 있음 | 반증 CONFIRMED | index.ts device-sessions mode 검사; MockDeviceGateway | 서버는 real mode 501; 승인 endpoint는 그 전에 허가를 발급했던 불일치 |
| 서버 규칙이 없으면 Dart가 실패함 | 반증 CONFIRMED | fitrus_repository.dart parseRuleSet | muscle 누락 시 로컬 기본값을 섞는 fallback 발견 |
| 피드백이 세 변수에 독립 반영됨 | PARTIAL/CONFIRMED | feedback.ts; session_feedback.dart | 저장은 세 항목, 감산은 RPE만 사용; 시간/주파수 평가는 자동 조정 근거 아님 |

입력: profile(id, sex, age, heightCm), 정확히 4개 측정(id, participantId, deviceId, time, quality, kg/%, BMI), 증상 3문항, 버전 규칙. 출력: 평균, 연구 등급, 미리보기 T/f/I, 계산 상태, 실행 상태, 이유 코드, 버전. 원시 측정→파생 평균→미리보기→서버 허가→Mock 세션 경계가 있다.

## 3. Evidence Matrix

| 자료 | 연구·대상 | 장치/프로토콜·측정 | 결과·적용 | 적용 불가 |
|---|---|---|---|---|
| [Janssen 2000](https://doi.org/10.1152/jappl.2000.89.2.465) | BIA 회귀식/MRI 검증, 성인 388명 | 전신 SMM; height²/resistance, 성별, 나이 | SMM 추정식의 장비·집단 의존성 | FITRUS 동등성, 진동 처방 |
| [Janssen 2004](https://doi.org/10.1093/aje/kwh058) | NHANES III 60세 이상 4,449명, 관찰 | BIA 전신 SMM/height²; 진동 없음 | 여성 5.75/6.75, 남성 8.50/10.75 장애위험 경계 | ASMI 기준으로 사용, 인과적 용량 배정 |
| [EWGSOP2](https://pmc.ncbi.nlm.nih.gov/articles/PMC6322506/) | 국제 합의, 개별 시험 N 해당 없음 | ASM/SMM·근력·수행능력; BIA는 추정 | 근육량≠근력, 기기/집단/수분 영향 | 근육량만으로 진단 또는 내성 확정 |
| [Wei 2017](https://doi.org/10.1177/0269215517698835) | 80명 근감소증 고령자 RCT | WBV 20Hz×720s, 40Hz×360s, 60Hz×240s; 12주; 상세 진폭·자세는 전문 확보 후 별도 추출 | 주파수와 시간을 함께 비교 | 근육량별 12/16/20Hz 매핑 |
| [Wu 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7499918/) | 6연구/7출판물/223명, WBV+국소진동 | 장치·자세·세션 이질적; 개별 프로토콜 하나로 합치지 않음 | 근력·기능 개선 가능; 표본 제한 | 모든 장치·고령자에게 동일 처방 |
| [2025 WBVT vs RT RCT](https://www.nature.com/articles/s41598-025-91644-2) | ≥65세 27명, 14/13 무작위, 12주/주3회 | 수직 Maizu, 맨발 무릎30°, 12Hz, inter-peak 4mm; 1분 작동×10+각1분 휴식; InBody S10 ASM | 양군 개선; KES 군간 RT 우세, 체성분 군간 차이 없음 | 20분 연속 출력, 12Hz가 LOW 근육량 최적이라는 주장 |
| [2026 메타분석](https://www.nature.com/articles/s41598-026-45710-y) | 6 RCT/202명; 검색 종료 2025-03 | 9–40Hz, 2–5mm 등 이질적 조건 | 근력 SMD .50, 기능 .50; 근육량 .14(CI −.22~.50) | 개별 용량 반응·최적값 추정 |
| [Altaf 2026](https://www.nature.com/articles/s41598-026-53239-3) | ≥60세 56명, 군당28, 성별14; 초록 확인 | WBV+동적 스쿼트, 15–40Hz/1.2–1.8mm, 8주/주3회; 상세 기기·SMM 식 미확인 | 성별 반응 차이 연구 필요 | 여성 일괄 감산, 초록만으로 세션 처방 |
| [보고 합의문 2021](https://pmc.ncbi.nlm.nih.gov/articles/PMC8533415/) | 전문가 합의 | 주파수·진폭 정의·측정 가속도·방향·자세·접촉·시간 | 물리량과 측정 조건 계약 | 보편적 안전 상한 제공 아님 |
| [전달률 연구 2025](https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2025.1573571/full) | 우주운동 대응 연구, 두 조건 8/7명 | 20Hz/3–4mm, 발판·허리·이마 가속도 | 자세·전달률 고려 | 고령자 처방 전용, ISO 직업 노출기준을 의료 안전 인증으로 사용 |
| [FITRUS 공식](https://manual.onesoftdigm.com/page/fitrus.manual.php?getLang=en) | FR-B10 제조사 매뉴얼 | Upper body, 50kHz, 비의료기기 | 측정부위≠출력값 정의, 정의/검증 공급사 확인 필요 | 상체 측정이므로 전신 추정이 절대 불가능하다는 단정도 금지 |

최신 조사 기준일은 2026-09-09. 검색 결과의 문구와 링크는 후보이며 원문/초록 열람 범위를 위에 구분했다. 모든 연구의 모든 수치를 전문에서 추출한 체계적 문헌고찰로 주장하지 않는다. Exa 4개 검색축(측정/효과/용량/OSS)에서 52개 결과 슬롯을 검토했다. 이는 고유 논문 52편이나 전문 52편을 의미하지 않는다.

GitHub: [CacheControl/json-rules-engine](https://github.com/CacheControl/json-rules-engine), ISC, JSON 규칙·eval 미사용 구조를 참고. 신규 의존성·소스 복사 없음. 기존 순수 함수+JSON Schema가 세 플랫폼 parity에 더 단순하다. GitHub는 임상 근거가 아니다.

## 4. 기존 규칙 판정

| 규칙 | 판정 | 결정 |
|---|---|---|
| 정확히 4건 평균 | PILOT | 요구사항 유지, SD/CV/min/max 병기. 4가 최적이라는 주장 삭제 |
| SMM/height² | EVIDENCE(정의), INDIRECT(FITRUS 전이) | 미확인 추정지수로만 표시 |
| 성별 경계 | EVIDENCE(원 코호트), INDIRECT(본 대상) | 연구 층화값, 진단 금지 |
| 12/16/20Hz·180/240/300s·30/40/50% | PILOT; 임상 사용은 UNSUPPORTED | Mock 시뮬레이션 조건만 유지 |
| 낮은 근육량이면 세 용량 모두 낮아야 함 | UNSUPPORTED | 효과·안전 단조성 주장 삭제 |
| 70세·0.90 | UNSUPPORTED | 계수 1로 폐기; 연령은 연구 모집 기준과 전문가 검토에 사용 |
| BMI<18.5 | PILOT(보수적 검토 정책) | REVIEW 유지, WBV 금기 확정 아님 |
| 증상·사용 보류 | INDIRECT+안전 공학 | BLOCKED 유지, 완전한 문진을 대신하지 않음 |
| %를 물리 자극량으로 간주 | UNSAFE | 교정 계약과 실출력 차단 |

## 5. 선택한 수학 설계

3단계 선택기를 채택한다. 연속 보간은 검증되지 않은 정밀도를 더한다. 백분위/z-score는 FITRUS 한국 고령자 참조분포가 필요하며, 나이 표준화는 고령자의 절대적 낮은 근육량을 숨길 수 있다. 베이지안 방식은 장비 오차·반응 데이터와 사전분포 검증이 필요하다. 현 단계에서는 SD/범위로 경계 불안정성을 보여주는 단순 규칙이 적합하다.

### A 데이터 품질

μ = Σmᵢ/4 [kg]; s = sqrt(Σ(mᵢ−μ)²/3) [kg]; CV=100s/μ [%]. min/max도 기록한다. 4건 수분 편향은 평균으로 제거되지 않는다. 독립 동일분포 오차일 때만 SE=s/2; 반복 측정 상관이나 체성분 변화가 있으면 해당 가정은 성립하지 않는다. 따라서 자동 95% 신뢰구간을 안전 근거로 사용하지 않는다. 단위·숫자·소유권·기기·ID 실패는 추천 없음. 결측 선택항목은 null. 입력 계약이 없는 실제 원본은 정규화하지 않는다.

### B 근육지수

SMM은 전신 골격근량[kg], SMMI는 해당 SMM/키²[kg/m²]다. ASM은 팔·다리의 사지골격근량[kg], ASMI는 ASM/키²[kg/m²]로 분자가 다르다. 문헌에 따라 측정법과 명칭이 다르므로 식의 분자를 먼저 확인한다. FITRUS `skeletalMuscleMassKg`를 ASM이나 MRI 전신 SMM으로 확정하거나 서로 변환하지 않는다.

q=μ/(heightCm/100)² [kg/m²]. 내부 계산에는 반올림하지 않는다. 표시만 2자리. 경계 비교는 q를 나누어 반올림하는 대신 Σmᵢ와 4bH²를 비교한다. 여성 b=(5.75,6.75), 남성 b=(8.50,10.75). LOW:q≤b₁, MEDIUM:b₁<q≤b₂, REFERENCE:q>b₂. 각 원본 mᵢ/H²가 다른 등급에 걸치면 `MUSCLE_TIER_UNSTABLE` REVIEW. 이는 신뢰구간이 아닌 관측 범위 기반 검토 정책(PILOT)이다.

### C 기본 프로토콜

P(LOW)=(180s,12Hz,30%), P(MEDIUM)=(240s,16Hz,40%), P(REFERENCE)=(300s,20Hz,50%). **기존 연구가설 보존용 시뮬레이션 숫자**다. dose란 명칭을 쓰지 않는다. 선택 이유와 버전, 근거 라벨을 응답에 포함. 연령·성별·체지방 곱셈계수는 1. 60세 미만은 코호트 밖 REVIEW. 이 숫자를 장치에 곧바로 적용할 수 없다.

### D 안전·실행

기존 status는 화면/Mock의 READY/REVIEW/BLOCKED를 유지한다. 별도 executionStatus는 BLOCKED → INSUFFICIENT_DATA → REVIEW → CALIBRATION_REQUIRED 우선순위. 이번 버전은 `simulation_only`이므로 실제 READY를 발급하지 않는다. realDeviceSendAllowed=false는 상수다. reasonCodes에는 증상, 입력 부족, 규칙 불일치, 근육지수 미검증, 보정 필요, PILOT 프로토콜을 기록한다. Mock 허가에는 mode=mock를 포함하고 서버 real mode에서는 허가 발급 이전부터 차단한다.

### E 기기 보정

정현파 A=peakToPeakMm/2000 [m]; a_peak=(2πf)²A [m/s²]; a_peak_g=a_peak/9.80665; a_rms=a_peak/√2 (정현파·해당 축 가정). 장치 측정값과 이론값을 구분한다. 허용표는 deviceId/calibrationVersion/유효기간/파형/자세/접촉/부하범위/주파수/%/변위/실측 peak·RMS/측정 불확실성/제조사 상한/시험 승인 ID를 가진다. 표에 없는 점은 외삽 금지. 실측값+불확실성≤승인 상한, 시간≤상한을 검증한다. 검증 통과는 교정표 적합성일 뿐 임상 승인 아님. 실제 어댑터가 없으므로 여전히 실출력 불가.

### F 피드백

I_next=min(I_muscle,I_previous, floor(0.9 I_used)) if RPE≥7 OR intensity=strong; otherwise min(I_muscle,I_previous,I_used). 0.9와 RPE7은 시뮬레이터 PILOT 정책. 약함은 유지. 시간/주파수 strong, 통증·어지럼·중도중단은 REVIEW/보류를 요구하고 자동 Hz 변화 금지. 사용자 체감 주파수는 실제 f 추정값이 아니다. 서버는 sessionId로 멱등 저장하며 불일치 재전송 거부. policyVersion/reasonCode 저장. 실제 실행시간·peak/RMS는 측정 없으면 null(예상값으로 채우지 않음). 이상반응은 이전 허가에도 재검증된다.

## 6. 의사결정·상태 전이

| 조건 | 미리보기/Mock 상태 | 실제 실행 상태 | 명령 |
|---|---|---|---|
| 통증/어지럼/사용보류/피드백 보류 | BLOCKED | BLOCKED | 없음 |
| 개수≠4 | REVIEW | INSUFFICIENT_DATA | 없음 |
| 혼합·중복·결측·규칙오류 | REVIEW | REVIEW | 없음 |
| BMI<18.5/문진 미완료/코호트 밖/등급 불안정 | REVIEW | REVIEW | 없음 |
| 입력 유효·문진 완료 | READY(시연) | CALIBRATION_REQUIRED | Mock만 |

서버: 인증→최신4건→규칙→추천→피드백→수동하향→모드검사→Mock허가→세션. 앱 변경 시 이전 허가 폐기, 서버 버전/수치 불일치 거부, 연결 실패·ACK 유실 시 오류와 중지 재시도. 물리 ACK를 받지 못한 경우 중지 성공으로 표시하지 않는다.

## 7. 검증·승격 기준과 남은 입력

먼저 공급사 SMM 정의/모델 버전/표준 단위/국내 고령자 검증을 확보. 반복 측정은 시각·식사·운동·수분·자세 기록. MRI 전신 SMM 또는 맞는 정의의 참조법과 Bland–Altman bias/일치한계, 반복성 ICC/SEM을 평가한다. 허용 오차 수치는 연구책임자가 사전 정의한다. ASMI와 totalSMMI를 혼용하지 않는다.

최신 4건이라는 정렬 규칙은 최신성이 임상적으로 충분함을 보장하지 않는다. 최대 측정 경과시간·4건 사이 간격·같은 세션 반복인지 장기 추적인지의 정책은 아직 미정이며 실제 연구 전에 확정해야 한다.

후속 파일럿은 장치 유형을 고정하고 근육지수 층별 안전성·수용성·실측 가속도·RPE·근력·수행능력을 수집한다. 참가자 단위 검증 분할과 반복측정 모형을 사용한다. 근육량만으로 용량을 바꾸는 방식과 고정 프로토콜을 비교하고 이상반응/탈락을 포함한다. n과 효과크기는 검정력·정밀도 분석으로 결정하며 임의 표본수로 임상 검증을 선언하지 않는다.

## 8. 구현 계획

입력 범위의 기술적 계약: 나이 정수18–100세(60세 미만 연구 검토), 키100–250cm, 필수 체성분 유한 양수, 체지방률≤100%, 지방량·골격근량≤체중. 체중/키와 BMI 차이>0.6, 지방량/체중과 체지방률 차이>1%p는 검토. 이 허용오차는 기존 공학적 일관성 검사이며 FITRUS 오차를 입증한 한계값이 아니다. 서버 규칙 내 강도는 현재20–70%, 실제 시연 추천은30/40/50%; 수동 조절은 해당 추천 이하만 허용한다. 선택 체성분의 값 하나라도 없으면 해당 항목 평균은 null. 결측·비유한 필수값은 추천 없음.

호환성: `totalSmmi`와 `AGE_70_PILOT` 같은 기존 코드 필드명은 직렬화/UI 호환을 위해 남겼지만, 화면의 뜻은 미확인 추정지수와 비활성 계수1이다. 레거시 `.txt`는 소스 감사용 스냅샷이며 독립 실행 패키지 보존을 의미하지 않는다.

1. v0.5 소스/fixture 보존, v0.6 규칙·계약·순수 함수 작성.
2. 원시 평균 기준 분류와 SD/CV/범위·불안정 게이트를 웹·서버·Dart에 연결.
3. Mock 가능 상태와 실제 실행 상태·reasonCodes 분리, 실모드 허가 차단, 규칙 fallback 제거.
4. 교정표 순수 검증기와 피드백 기록·멱등·보류 정책 적용.
5. 공유 경계 fixture와 안전/오류/위젯/HTTP 테스트, 타입·웹 빌드·APK 검증.
6. plan/checklist/검증 증거 갱신. 운영 DB migration·배포·실제 API/장치 호출은 수행하지 않음.

장치 형태는 사용자 확인으로 **발판에 서는 전신진동 장치**로 확정했다. 국소진동 연구의 수치를 직접 옮기지 않는다. 수직형/교대형, 파형, 자세 및 무릎 각도, 부하 조건은 아직 미확인이다.

불확실성: FITRUS 출력 정의·원응답·측정오차, 장치 모델과 교정표, 근육량별 최적 자극, 임상 상한, 적정 세션/휴식, 시험 승인. 이것들이 없다는 이유로 숫자를 추정해 승인 조건을 통과시키지 않는다.
