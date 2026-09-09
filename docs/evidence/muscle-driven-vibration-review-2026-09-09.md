# 근육량 기반 진동 추천 문헌·오픈소스 검토

검토일: 2026-09-09
대상: 고령자, FITRUS 전신 골격근량 추정값, 진동 장치 제어 앱

## 결론

근육량은 `전신 골격근량/키²`로 정규화해 장애위험 등급을 만드는 근거가 있다. 그러나 그 등급을 특정 주파수·시간·강도에 직접 연결한 검증 논문은 찾지 못했다. 따라서 다음 세 층을 분리한다.

1. **근거 기반 측정층**: 동일 기기 4건 평균, 전신 골격근지수 계산, Janssen 위험구간
2. **연구가설 추천층**: 근육등급별 낮은 초기 프로토콜을 단조 증가 방식으로 선택
3. **기기 안전층**: 실제 진폭·가속도 보정, 증상 차단, 서버 재계산, 감사기록

## 선정 기준

- 원 논문, 무작위 대조시험, 체계적 문헌고찰, 국제 전문가 합의문 우선
- 고령자 또는 근감소증 대상 우선
- 주파수뿐 아니라 진폭·시간·자세를 확인할 수 있는 연구 우선
- FITRUS와 측정방식이 다른 연구는 직접 호환으로 간주하지 않음
- GitHub 코드는 임상 수치의 근거로 사용하지 않고 결정론·검증·추적 구조만 평가

## 핵심 논문 평가

| 순위 | 자료 | 설계/대상 | 핵심 결과 | 프로젝트 적용 | 한계 |
|---:|---|---|---|---|---|
| 1 | Janssen 2000 | MRI 대비 BIA 전신 골격근량 회귀식, 18~86세 388명 | `R²=0.86`, 표준추정오차 2.7kg(9%); 아시아인에서 과소추정 | 전신 골격근량이라는 개념과 장비별 검증 필요성 | FITRUS 식과 동일하지 않음 |
| 2 | Janssen 2004 | 60세 이상 NHANES III 4,449명 | 전신 골격근량/키² 구간이 신체장애 위험과 연관 | 여성 5.75/6.75, 남성 8.50/10.75를 RESEARCH 경계로 사용 | 미국 과거 코호트·특정 BIA 식 |
| 3 | Wei et al. 2017 RCT | 근감소증 고령자 80명, 12주 | 20Hz×720s, 40Hz×360s, 60Hz×240s 중 40Hz×360s가 수행능력 결과 우수 | 주파수와 시간을 함께 다뤄야 함; 총 진동횟수 통제 사례 | 근육량 등급별 처방 연구가 아님 |
| 4 | Wu et al. 2020 | 6개 연구 223명 체계적 문헌고찰 | 근력·수행능력 개선 가능, 근육량 효과 불명확; WBV 12~60Hz·1~20분으로 이질적 | 초기값은 낮은 범위에서 제한하고 효과를 과장하지 않음 | 연구 수와 표본이 작음 |
| 5 | van Heuvelen et al. 2021 | 국제 전문가 보고 합의문 | frequency, peak-to-peak displacement, peak/RMS acceleration, 자세·접촉부위 보고 필요 | 강도 `%`를 실제 진폭·가속도로 교정하기 전 실기기 차단 | 처방 가이드가 아니라 보고 표준 |
| 6 | Rogan et al. 2015 | 고령자의 기능수준별 체계적 문헌고찰 | 낮은 기능의 고령자에게 짧은 진동이 skilling-up으로 활용될 가능성 | 취약군에서 낮은 초기 부하·점진 진행 | 근육량 단독 층화가 아님 |

## 근육량 분류에 적용하는 근거

Janssen 2000의 전신 골격근량은 다음 BIA 회귀식으로 MRI와 교차검증됐다.

```text
SMM(kg) = (heightCm² / resistanceOhm × 0.401)
        + (sex × 3.825)
        + (age × -0.071)
        + 5.102
```

FITRUS는 저항 원자료와 산출식을 공개하지 않으므로 이 식을 앱에서 다시 계산하지 않는다. 공급사가 반환한 `skeletalMuscleMassKg`를 사용하되 `RESEARCH`로 명시한다.

Janssen 2004의 전신 골격근지수는 다음과 같다.

```text
totalSMMI = total skeletal muscle mass kg / height m²
```

| 성별 | 높은 장애위험 | 중간 장애위험 | 낮은 위험/참조 |
|---|---:|---:|---:|
| 여성 | `≤5.75` | `5.76~6.75` | `>6.75 kg/m²` |
| 남성 | `≤8.50` | `8.51~10.75` | `>10.75 kg/m²` |

이는 ASM 기반 AWGS 기준이 아니며 근감소증 확진 기준으로 표시하지 않는다.

## 진동 메커니즘에 적용하는 근거

진동의 기계적 크기는 주파수만으로 결정되지 않는다. 정현파에서:

```text
aPeak = (2πf)² × A
```

같은 진폭이면 주파수 증가에 따라 가속도가 제곱으로 증가한다. 따라서 근육등급을 Hz에만 연결하는 방식은 위험하며 시간·진폭/가속도·자세·파형을 함께 제한해야 한다.

문헌에서 근육량 LOW/MEDIUM/HIGH를 특정 장치 명령에 직접 연결한 표준은 확인되지 않았다. `12/16/20Hz`, `180/240/300초`, `30/40/50%`는 아래 조건을 가진 검증 대상 연구가설이다.

- 전신진동 장치일 때만 후보값으로 사용
- 낮은 근육등급부터 낮은 초기 부하로 시작
- 상승은 사용자 피드백과 전문가 승인 후 진행
- 실제 `%`는 장비별 진폭·가속도 보정표가 있을 때만 유효
- 장치 보정 전에는 Mock 또는 화면 미리보기만 허용

## GitHub 조사 결과

검증된 근육량→진동 처방 오픈소스는 찾지 못했다. 다음 구현 원칙만 채택한다.

| 프로젝트 | 채택할 부분 | 채택하지 않을 부분 |
|---|---|---|
| CacheControl/json-rules-engine | 직렬화 가능한 조건, `all/any`, 규칙 저장 | 임상 수치 없음 |
| jbt95/rulit | 타입 안전, reason code, 실행 trace, 규칙 버전 | 새 의존성 즉시 도입 안 함 |
| hoppybunny/json-rules-engine-upgraded | JSON Schema, 로드 시 검증, `eval` 미사용 | 프로젝트 성숙도 확인 전 패키지 도입 안 함 |
| tiana-code/decision-engine | 동일 입력=동일 결과, fail-closed, I/O 없는 순수 평가 | JVM 구현 자체는 사용하지 않음 |

현재 프로젝트는 별도 런타임 규칙엔진을 추가하지 않고 기존 순수 Dart/TypeScript 함수와 JSON Schema를 유지한다. 규칙 ID, 버전, 입력 스냅샷, 발생 이유, 결과를 저장해 같은 설명가능성을 구현한다.

## 알고리즘 채택안

```text
1. 동일 사용자·동일 기기 최근 유효 4건 선택
2. 골격근량 평균
3. totalSMMI = meanSMM / height²
4. 성별 Janssen RESEARCH 구간으로 LOW/MEDIUM/HIGH 결정
5. 근육등급으로 기본 주파수·시간·강도 선택
6. 통증·어지럼·보류는 BLOCKED
7. 저체중·문진 미완료·기기 보정 없음은 REVIEW
8. 서버가 같은 규칙으로 재계산한 경우에만 실행 허가
```

## 반드시 남겨야 하는 불확실성

- FITRUS 골격근량이 Janssen 정의의 전신 골격근량과 교환 가능한지 확인되지 않음
- 실제 진동기가 전신진동, 국소진동, 모터 진동 중 무엇인지 확정되지 않음
- 앱 강도 `%`와 진폭·가속도 관계가 없음
- 근육등급→12/16/20Hz 직접 매핑은 임상 검증되지 않음
- 안전성과 효능을 주장하려면 전문가 승인 파일럿과 전향적 검증이 필요

## 출처

- Janssen et al. 2000: https://doi.org/10.1152/jappl.2000.89.2.465
- Janssen et al. 2004: https://doi.org/10.1093/aje/kwh058
- Wei et al. 2017: https://doi.org/10.1177/0269215517698835
- Wu et al. 2020: https://pmc.ncbi.nlm.nih.gov/articles/PMC7499918/
- Rogan et al. 2015: https://doi.org/10.1186/s11556-015-0158-3
- WBV 보고 합의문: https://pmc.ncbi.nlm.nih.gov/articles/PMC8533415/
- WBV 용량 검토: https://pmc.ncbi.nlm.nih.gov/articles/PMC11396361/
- FITRUS 공식 매뉴얼: https://manual.onesoftdigm.com/page/fitrus.manual.php?getLang=en
- json-rules-engine: https://github.com/CacheControl/json-rules-engine
- rulit: https://github.com/jbt95/rulit
- json-rules-engine-upgraded: https://github.com/hoppybunny/json-rules-engine-upgraded
- decision-engine: https://github.com/tiana-code/decision-engine
