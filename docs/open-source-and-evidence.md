# VibeCare 오픈소스·논문 근거와 자체 접근

## 1. 결론

VibeCare는 논문에 나온 특정 주파수 하나를 그대로 처방하는 앱이 아니다. 공개 연구에서 얻을 수 있는 것은 **연구 시작 범위와 측정 원칙**이며, 연령·성별·체지방별 고정 감산율은 아직 임상적으로 확정된 값이 아니다. 따라서 `pilot-0.3.0`은 아래 순서의 설명 가능한 안전 엔진으로 운영한다.

```text
4회 BIA 정합성 검사
→ 항목별 산술평균과 변동성 계산
→ 통증·어지럼·사용보류 안전 게이트
→ 버전이 붙은 PILOT 보정계수 적용
→ 교정된 기기의 물리 출력 한계 검사
→ 서버 1회성 실행 허가
→ ACK 감시·즉시중지·사후반응 수집
```

현재의 `70세 이상 ×0.90`, `여성 ×0.95`, `성별 체지방 참고범위 밖 ×0.90`은 제품 가설이다. 앱은 이 값을 임상 사실로 표시하지 않고, 규칙 버전과 적용 이유를 함께 기록한다.

## 2. GitHub 오픈소스 선정

| 구성 | 후보/저장소 | 라이선스 | 적용 방식 |
|---|---|---|---|
| 모바일 UI | [Flutter](https://github.com/flutter/flutter) | BSD-3-Clause | Android 우선 단일 코드베이스 |
| 상태 관리 | [Riverpod](https://github.com/rrousselGit/riverpod) | MIT | 화면 상태와 도메인 로직 분리 |
| HTTP | [Dio](https://github.com/cfug/dio) | MIT | 타임아웃·취소·인증 인터셉터 |
| 보안 저장 | [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) | BSD-3-Clause | access/refresh token 저장, PIN은 저장하지 않음 |
| BLE 후보 | [flutter_reactive_ble](https://github.com/PhilipsHue/flutter_reactive_ble) | BSD-3-Clause | 공급사 GATT 명세 확정 뒤 어댑터에만 연결 |
| 엣지 API | [Workers SDK](https://github.com/cloudflare/workers-sdk) | MIT/Apache-2.0 | Workers·D1 개발/배포 도구 |
| API 라우팅 | [Hono](https://github.com/honojs/hono) | MIT | Web Standard 기반의 작은 API 계층 |

Flutter 공식 아키텍처 가이드의 View/ViewModel/Repository/Service 분리를 따르되, 계산 규칙은 별도 domain 계층에 둔다. 오픈소스 예제 코드를 복사해 알고리즘으로 주장하지 않으며, 패키지는 통신·상태관리 같은 기반 기능에만 사용한다.

`flutter_blue_plus`는 기능상 후보였지만 현재 라이선스가 일반적인 상용 허용 라이선스가 아니므로 기본 후보에서 제외한다. 최종 출시 전 `flutter pub deps --json`, `npm ls --json` 결과로 전이 의존성까지 SBOM과 고지문을 만든다.

## 3. 논문에서 직접 가져오는 것과 가져오지 않는 것

| 근거 | 직접 사용할 수 있는 내용 | 사용할 수 없는 확대 해석 |
|---|---|---|
| [AWGS 2019 합의문](https://www.sciencedirect.com/science/article/pii/S1525861019308722) | 아시아 고령자의 근감소증 평가 맥락과 성별 SMI 기준 | SMI만으로 진동강도를 자동 결정 |
| [한국 근감소증 진료지침](https://pmc.ncbi.nlm.nih.gov/articles/PMC10073972/) | 국내 대상 선별·평가 맥락 | 진단 기준을 기기 처방식으로 치환 |
| [Wei 등 WBV 무작위시험](https://pubmed.ncbi.nlm.nih.gov/28933611/) | 20/40/60 Hz와 시간 조합이 연구된 사실, 40 Hz 조건의 상대적 결과 | 다른 구조의 국소 진동기에 같은 효과·안전성을 보장 |
| [Tseng 등 고령자 급성반응 연구](https://pmc.ncbi.nlm.nih.gov/articles/PMC8625607/) | 50~69세에서 20 Hz 급성 근활성 반응 관찰 | 장기효과 또는 모든 고령자에게 20 Hz 처방 |
| [Muir 등 장비 출력 연구](https://pmc.ncbi.nlm.nih.gov/articles/PMC3688642/) | 표시 주파수가 같아도 장비별 실제 가속도가 크게 다르므로 실측 필요 | UI의 `%`를 물리적 강도로 간주 |
| [BIA 신뢰도·표준화 연구](https://pmc.ncbi.nlm.nih.gov/articles/PMC11649400/) | 자세·측정조건·기기 일관성이 중요 | 4회 평균이 측정편향을 자동 제거 |
| [수분상태와 BIA 연구](https://pmc.ncbi.nlm.nih.gov/articles/PMC10143694/) | 수분상태가 체성분 추정에 영향을 줄 수 있음 | 이상값을 근거 없이 삭제 |
| [성별 WBV 문헌고찰](https://pmc.ncbi.nlm.nih.gov/articles/PMC8805365/) | 성별 반응 차이 가능성과 근거 부족 | 여성 고정 5% 감산이 검증됐다고 주장 |

## 4. VibeCare 고유 접근

### A. 데이터 품질을 알고리즘의 첫 단계로 둔다

- 동일 참여자, 동일 기기, 중복되지 않은 정확히 4건만 한 세트로 묶는다.
- 평균뿐 아니라 표준편차와 범위를 저장한다. 변동이 큰 세트는 자동 제외하지 않고 `REVIEW`로 보낸다.
- 측정 시각, 식사·운동·수분상태 같은 메타데이터가 공급되면 품질 플래그에 반영한다.

### B. 추천과 실행을 분리한다

- 앱 계산은 설명 가능한 미리보기다.
- 서버가 같은 원본 측정 ID와 규칙 버전으로 다시 계산한 뒤, 짧게 만료되는 1회성 허가를 발급한다.
- `READY`와 교정된 기기 ID가 모두 일치해야 실행한다. `REVIEW/BLOCKED`는 참여자 앱에서 우회할 수 없다.

### C. `% 강도`를 물리량으로 교정한다

기기의 단계값 또는 퍼센트는 Hz와 별개의 값이다. 공급사별로 `강도 단계 → 진폭(mm) → 가속도(m/s² 또는 g)` 교정표를 만들고, 접촉부위·부하조건·최대시간을 함께 저장한다. 교정표가 없으면 `targetAccelerationG`는 `null`이며 실제 전송은 비활성화한다.

### D. 파일럿 데이터를 이용해 계수를 갱신한다

초기에는 규칙 기반으로 시작하고 세션별 실제 출력, RPE, 통증, 어지럼, 중단 여부를 기록한다. 충분한 데이터가 쌓이면 참여자 반복측정을 고려하는 혼합효과모형 또는 베이지안 계층모형으로 `나이/성별/체지방` 효과와 불확실성을 추정한다. 새 계수는 사전 정의한 평가계획과 전문가 검토를 통과한 새 규칙 버전으로만 승격한다. 블랙박스 ML이 안전 게이트를 대신하지 않는다.

## 5. 검증 증거

각 릴리스는 다음 파일을 남긴다.

- `packages/contracts/fixtures/pilot-0.3.0.json`: TypeScript/Dart/서버 공통 입력·기대값
- `docs/evidence/algorithm-parity.md`: 세 구현의 결과 비교
- `docs/evidence/bia-api-validation.md`: 공급사 응답 스키마·4건 정합성 결과
- `docs/evidence/device-calibration.md`: 단계·Hz·진폭·가속도 교정표
- `docs/evidence/device-protocol.md`: ACK·중지·타임아웃 시험
- `docs/evidence/pilot-analysis-plan.md`: 계수 갱신 전 통계분석계획

> 이 문서는 연구·제품 설계 근거이며 의료 처방을 대체하지 않는다. 실제 인체 적용과 출력 상한은 연구책임자·의료/안전 담당자와 기기 제조사의 검증을 거쳐야 한다.
