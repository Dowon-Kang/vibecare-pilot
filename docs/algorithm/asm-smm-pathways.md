# ASM / SMM 분리 설계 — pilot-0.7.0 연구 비교 모듈

2026-09-09. 사용자 요청: 측정값이 사지근육량인 경우와 전신 골격근량인 경우를 각각 설계·구현.

## 범위와 핵심 결정

기존 pilot-0.6.0 앱 흐름을 변경하지 않고 별도 호출 가능한 TypeScript/Dart 순수 모듈을 추가한다. 입력 종류를 추정하거나 서로 변환하지 않는다. 모든 출력은 연구용이며 command=null, realDeviceSendAllowed=false. 현재 앱의 실행 허가 API에는 연결하지 않는다. 향후 연동 시 서버 검증·규칙 저장·실행 허가 버전을 함께 변경해야 한다.

## 입력 계약

profile: participantId, age(정수18–100), sex(female/male), heightCm(100–250).
measurements: 정확히4건. id/participantId/deviceId/measuredAt/qualityPassed, weightKg/bmi/bodyFatPct/fatMassKg, muscle={kind:ASM|SMM|UNKNOWN,method:BIA|DXA|UNKNOWN,massKg,definitionRef}.
safety: acutePain/dizziness/clinicianHold 세 boolean 명시.

definitionRef는 공급사 필드 정의/기기 모델/식 버전 또는 합성 시나리오 참조다. 문자열 존재는 공급사 검증의 증거가 아니다. 본 모듈은 모두 INPUT_DEFINITION_ASSUMED로 표시한다. 실제 공급사 정의는 별도 검증이 필요하다. BIA는 기기·주파수·모집단별 타당성을 확인해야 하며 FITRUS 출력의 동등성을 선언하지 않는다. ASM은 양팔+양다리 합계이며 한쪽 다리나 전체 제지방량을 뜻하지 않는다. SMM은 전신 골격근량이며 DXA 전신 제지방량을 대신 넣지 않는다.

동일인/동일기기/동일kind/동일method/동일definitionRef만 평균 가능. 중복 ID·결측·비유한값은 추천 없음. kg/cm 필드의 단위는 계약에 고정되며 공급사 어댑터가 단위를 확인해야 한다. 숫자만 잘못된 단위로 전달되면 이 모듈만으로 항상 감지할 수는 없다. 이 모듈에 넘길 4건은 호출자가 최신 유효4건으로 선택해야 한다. 정상 평가 결과에 원본 측정 ID 4개와 시각을 입력 순서대로 남긴다. 최대 경과시간/간격은 미정이며 생리적 동일 상태를 보증하지 않는다. 시각은 어댑터가 UTC ISO 형식 YYYY-MM-DDTHH:mm:ss.SSSZ로 정규화한다.

## 공통 계산

μ=ΣmassKg/4 [kg]; q=μ/(heightCm/100)^2 [kg/m²]. 평균·경계 판단은 반올림 전 수행; 표시만2자리. 표본 SD=sqrt(Σ(m−μ)^2/3). 각 원본이 서로 다른 구간에 속하면 MUSCLE_TIER_UNSTABLE→REVIEW. 이는 프로젝트 품질 가설이며 임상 신뢰구간이 아니다.

경계 비교에는 8×IEEE754 epsilon×max(1,|a|,|b|) 이내의 이진 부동소수점 오차만 동등 처리한다. 예: 160cm, ASM14.592kg는 ASMI5.7과 같으며 LOW가 아니다. 이것은 측정 오차 허용범위 또는 표시 반올림이 아니다. 체중/키²와 BMI 차이0.6, 체지방량/체중×100과 체지방률 차이1%p 초과는 입력 불일치로 보류하는 PILOT 품질 규칙이다. 입력 연령18–100/키100–250 제한 역시 엔지니어링 계약이지 임상 적응증이 아니다.

## A. 사지근육량(ASM)

ASMI=평균 ASM/키². [AWGS 2025 원 논문](https://www.nature.com/articles/s43587-025-01004-y), Table2, DOI10.1038/s43587-025-01004-y. 출판사 인증 오류로 동일 원 논문의 [공개 PDF 사본](https://waltersport.com/wp-content/uploads/2025/11/NATURE-A-focus-shift-from-sarcopenia-to-muscle-health-in-the-Asian-Working-Group-for-Sarcopenia-2025-Consensus-Update-Chen-et-al.-2025.pdf) Table2(p4)를 확인했다.

| 연령 | BIA 남/여 | DXA 남/여 |
|---|---|---|
| 50–64 | 7.6 / 5.7 | 7.2 / 5.5 |
| ≥65 | 7.0 / 5.7 | 7.0 / 5.4 |

q<경계는 LOW, q≥경계는 NOT_LOW. 정확히 같은 값은 LOW가 아니다. 50세 미만은 REFERENCE_OUT_OF_SCOPE로 보류. 중간/높음 경계를 임의로 추가하지 않는다. 근력 검사가 없으므로 근감소증 진단을 하지 않는다. BMI 보정 방식은 이번에 추가하지 않으며 두 방식 중 유리한 결과를 골라 쓰지 않는다.

## B. 전신 골격근량(SMM)

SMMI=평균 SMM/키². [Janssen 2004](https://pubmed.ncbi.nlm.nih.gov/14769646/), 전신 BIA 기반 ≥60세 코호트 장애 위험 연구.
여성 q≤5.75 LOW; 5.75<q≤6.75 MIDDLE; q>6.75 REFERENCE.
남성 q≤8.50 LOW; 8.50<q≤10.75 MIDDLE; q>10.75 REFERENCE.
60세 미만 또는 DXA 입력은 이 경로의 적용 범위 밖으로 보류한다. MRI 등 다른 방식도 별도 타당화 없이 자동 수용하지 않는다. ASM 분류와 동일 위험 등급으로 해석하지 않는다.

## Mock 설정 가설

P1=(180초,12Hz,30%), P2=(240초,16Hz,40%), P3=(300초,20Hz,50%). ASM LOW→P1, NOT_LOW→P2. SMM LOW→P1, MIDDLE→P2, REFERENCE→P3. 이는 계산 경로를 비교하기 위한 명시적인 프로젝트 PILOT 가설이며 문헌의 치료 권고/안전 상한/최적 용량이 아니다. ASM의 NOT_LOW는 SMM의 REFERENCE와 같은 의미가 아니므로 같은 최대 조건으로 연결하지 않는다. 이 선택 자체도 검증 전이다.

낮은 근육량에 작은 숫자의 preset을 배정한 것은 검증할 가설이지 입증된 인과관계가 아니다. 낮은 Hz가 항상 안전하다는 의미도 아니다. 정현파에서 a_peak=(2πf)²×A_peak, A_peak=A_peak-to-peak/2이므로 실제 전달 자극은 주파수뿐 아니라 진폭·파형·축·부하·자세에 영향을 받는다. intensityPct는 교정 전 무차원 Mock 값이며 가속도 g 또는 PWM과 등가가 아니다. 두 인체구성 연구는 이 세 preset을 검증하지 않는다.

기존 통증·어지럼·보류→BLOCKED, 필수4건 부족→INSUFFICIENT_DATA, 규격/정의/범위 문제→REVIEW, BMI<18.5→REVIEW(PILOT 정책), 그 외 READY는 Mock만 의미. 증상 시 assessment/protocol 모두 null. REVIEW에서 assessment는 검토를 위해 보여줄 수 있지만 simulationProtocol은 null. 실출력 허가 없음.

## 나이·성별·체지방 및 개인화

ASM은 문헌에 따라 나이와 성별로 경계를 선택한다. SMM은 성별 경계를 선택한다. 체지방률/체지방량/체중은 입력 일관성 검사와 개인차 연구 변수로 보존한다. 통증 예측계수는 학습되지 않아 NOT_FITTED, appliedFactor=null로 반환한다. 임의 감산을 넣지 않는다. 기존 피드백 정책과 독립 모듈이며 후속 개인화·장치 제어를 이미 구현한 것처럼 표시하지 않는다.

## 구현·검증 계획

shared-contracts의 입력 Schema/순수 TypeScript 함수/공통 fixture → backend-api에서 export → Flutter 순수 Dart JSON 계약 함수 → 공통 경계·결측·혼합·문진·미지원 방식 테스트 → 기존 회귀 테스트/타입/Flutter analyze.
비교 예시의 동일 숫자를 ASM/SMM으로 넣는 것은 가상 실험일 뿐 한 사람의 두 측정값이 같다는 가정이 아니다. 연구 효과와 실제 출력은 별도 데이터·장치 교정·연구 승인이 필요하다.

## 파일과 실행 방법

- `shared-contracts/muscle-pathways.ts`: 순수 계산 및 입력 방어. `calculateMusclePathway(input)` 호출.
- `shared-contracts/muscle-pathway-input.schema.json`: 입력 계약. Schema 파일을 둔 것과 HTTP 경로에서 Schema 검증을 활성화한 것은 다르다.
- `backend-api/src/muscle-pathways.ts`: 서버 import 경계. 기존 route에는 미연결.
- `mobile-app/lib/algorithm/muscle_pathways.dart`: Flutter에서 호출 가능한 동일 Dart 계산 모듈. 기존 Controller/UI에는 미연결.
- `shared-contracts/fixtures/pilot-0.7.0-pathways.json`: 합성 79사례. 실제 참여자 자료 아님.
- `backend-api/test/muscle-pathways.test.ts`, `mobile-app/test/muscle_pathways_test.dart`: 각각81개 새 검사.
- `backend-api/tools/verify-muscle-pathways.mjs`: 전체 JSON 출력의 언어 간 비교.
- [검증 결과](../evidence/pilot-0.7.0-pathways-validation.md).

모바일 폴더에서 예제 실행:

```powershell
cd "E:\산학협력\vibration-control-app\mobile-app"
& E:\flutter-sdk\bin\cache\dart-sdk\bin\dart.exe tool/compare_muscle_pathways.dart
```

합성 여성70세/키200cm/평균24kg를 각 종류라고 가정하면 q=6.0: ASM은 NOT_LOW, SMM은 MIDDLE이다. 둘 다 현재 가설 매핑상 P2이지만 분류의 의미는 다르다. 이 키/질량은 경계 산술 검증을 위해 선택했으며 대표적인 고령 참여자 값이 아니다.

앱 연동 순서는 공급사 kind/method/definitionRef 확정 → Repository 정규화 → 종류·근거·평균·계산 표시 → 서버 동일 버전 재계산 → 기존 Mock 허가 경로와 통합이다. 사용자에게 유리한 결과를 고르도록 ASM/SMM을 임의 토글하는 운영 UI는 만들지 않는다. 데이터 정의 미확정 상태에서는 비교 실험 화면으로만 제공한다.
