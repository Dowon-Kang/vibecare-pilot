# ASM / SMM 정의 고정 설계

FITRUS의 `골격근량` 필드가 사지근육량인지 전신 골격근량인지 공식 자료로 확인되지 않았다. 앱은 값을 임의 변환하지 않고 같은 4건 평균을 두 가지 **명시적 가정**으로 계산해 사용자가 비교·선택하게 한다.

## 공통 계산

```text
평균 근육량 = 네 측정 근육량의 합 / 4
근육지수 = 평균 근육량(kg) / 키(m)²
```

원본값으로 경계를 판정하고 화면 표시만 소수 둘째 자리로 반올림한다. 서로 다른 사용자·기기, 중복 ID, 결측·비유한 값, BMI·체지방 불일치는 `REVIEW`로 처리한다.

## ASM 가정

사지근육지수 `ASMI`로 해석한다. BIA 기준 절단값은 AWGS 2025를 참고한다.

- 여성: `5.7 kg/m²` 미만을 낮음
- 남성 65세 이상: `7.0 kg/m²` 미만을 낮음
- 남성 50–64세: `7.6 kg/m²` 미만을 낮음
- 낮음은 Mock P1 `3분·12Hz·30%`, 그 외는 Mock P2 `4분·16Hz·40%`

## SMM 가정

전신 골격근지수 `SMMI`로 해석하며 Janssen 2004의 전신 BIA 구간을 참고한다.

- 여성: `≤5.75` 낮음, `≤6.75` 중간, 초과 참조 이상
- 남성: `≤8.50` 낮음, `≤10.75` 중간, 초과 참조 이상
- 낮음 P1 `3분·12Hz·30%`, 중간 P2 `4분·16Hz·40%`, 참조 이상 P3 `5분·20Hz·50%`

## 구현 위치

- Flutter 계산: `mobile-app/lib/algorithm/vibration_algorithm.dart`
- 선택 상태와 두 결과: `mobile-app/lib/controllers/pilot_controller.dart`
- 비교 UI: `mobile-app/lib/screens/overview_card.dart`
- 서버 재계산: `backend-api/src/algorithm.ts`
- API 요청 필드: `muscleMassBasis = ASM | SMM`. 저장된 `muscleDefinition`과 같아야 하며 사용자가 임의로 바꿀 수 없다.

두 경로와 위 후보는 현재 `pilot-0.7.0` Mock 시뮬레이션에서만 활성화한다. 이 연결은 `HYPOTHESIS_UNVALIDATED` 연구가설이지 임상 처방이나 물리 기기 실행 규칙이 아니다. 정의가 `UNKNOWN`이면 두 경로 모두 차단하며 실제 장비 출력은 항상 금지한다.
