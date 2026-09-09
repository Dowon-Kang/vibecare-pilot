# 근육량 기반 WBV 알고리즘: 설계·근거·검증·유지보수

2026-09-09 · REQ-ALGO-05 · `adaptive-research-0.2.0` / `research-gate-0.8.1`

## 1. 무엇을 구현했는가

발판에 서는 전신진동(WBV) 연구용 **결정론적 프로토콜 후보 선택기**다. 근육량은 시작 후보를 찾는 층화 변수이고, 실제 사용 후 반응은 같은 연구 정책 안에서 유지·하향·상향 검토를 결정한다. 학습된 AI 모델이나 임상적으로 검증된 개인 처방 알고리즘은 아니다.

이번 변경은 기존 TypeScript/Dart 모듈을 수정했다. 계산 모듈 사이 연결 함수까지 구현했지만 **현재 앱 화면·API route·실제 장치에는 새 선택기를 활성화하지 않았다.** 기존 UI가 새 버전으로 바뀌었다고 해석하면 안 된다. 모든 연구 결과의 `command=null`, `realDeviceSendAllowed=false`는 유지한다.

```text
evaluateAdaptiveResearch({readinessInput, adaptationInput})
  → 안전·측정 정의·동일인 4건 검증
  → calculateMusclePathway: ASM 또는 SMM 평가
  → selectAdaptiveProtocol: 검증된 분류 + 이력 + 버전 정책
  → 선택 stage의 protocolId
  → evaluateProtocolReadiness: 같은 근육 분류 + 정확한 ID
  → 물리량·교정 비교 → 독립 검토 필요
```

## 2. 근거 조사와 적용 범위

이번 보강에서는 WBV 보고 지침, 용량 비교 임상시험, 오픈소스 검증, 상태 전이의 네 검색축에서 상위 5건씩 **20개 검색 결과**를 선별했다. 이는 20개 독립 논문을 정독했다는 뜻도, 체계적 문헌고찰이라는 뜻도 아니다. 아래 1차 문헌·공식 문서를 직접 확인했다. 이전 조사의 결론과 이번에 확인한 내용을 구분한다.

| 출처 | 직접 뒷받침하는 내용 | 적용 / 적용하면 안 되는 것 |
|---|---|---|
| [WAVEX 국제 전문가 합의, van Heuvelen 등, Biology 2021](https://doi.org/10.3390/biology10100965), §4.2 items 3–6, §4.3 item 8 | 주파수·peak-to-peak 변위·peak/RMS 가속도·파형·자세·노출/휴식·하중 조건의 명시와 실제 측정 | 단위와 이론 물리량 검증에 적용. 개인별 안전 용량 공식으로 쓰지 않음. |
| [Wei 등, WBV 주파수/시간 RCT](https://pubmed.ncbi.nlm.nih.gov/28933611/), DOI 10.1177/0269215517698835, 초록 | 근감소증 고령자 80명, 세 진동군과 대조군, 12주 비교. 같은 진동 횟수라도 조합별 결과가 다름 | Hz×시간만으로 생물학적 자극을 등가 취급하지 않음. 연구의 특정 군 결과를 우리 장치 처방으로 복사하지 않음. |
| [Janssen 등, AJE 2004](https://pubmed.ncbi.nlm.nih.gov/14769646/), 초록 | 60세 이상 4,449명, BIA 전신 근육량/키²와 기능장애 위험 연관 | 기존 SMMI 분류의 간접 근거. 한국 FITRUS 정의·인구집단과의 동등성, 진동 용량의 인과는 입증하지 않음. |
| [AWGS 2025, Nature Aging](https://www.nature.com/articles/s43587-025-01004-y), 출판사 초록 | 근육량과 근력 등을 함께 보는 근육 건강 평가 | ASM과 전신 SMM 혼용 금지, 근육량만으로 근감소증 진단 금지. 이번에는 원문 표의 수치를 새로 추출하거나 임계값을 변경하지 않음. |
| [fast-check GitHub](https://github.com/dubzzz/fast-check), [공식 검증 문서](https://fast-check.dev/docs/introduction/getting-started/) | 속성·입력 생성·재현 가능한 반례 검증 방법 | 유한 입력 공간의 전수 검사와 공통 반례 fixture 원칙에 반영. 패키지 설치·소스 복사는 하지 않았고 shrinking/random fuzzing을 구현했다고 주장하지 않음. |
| [XState GitHub](https://github.com/statelyai/xstate), [공식 guards 문서](https://stately.ai/docs/guards) | 부수효과 없는 조건 함수와 우선순위가 있는 전이 | 안전→입력→정책→반응의 순수 함수로 구현. XState 런타임을 도입한 것은 아님. |

**판정:** 근육량·나이·성별·체지방으로 개인 통증이나 안전 Hz·시간·%를 직접 계산하는 계수는 위 자료로 정당화되지 않는다. 이 변수들이 반응과 관련 있을 가능성과, 곱셈계수 0.90/0.95가 맞다는 주장은 별개다.

## 3. 수학적 설계

### 측정 평가 — 기존 정의 유지

유효한 동일 정의의 근육량 네 값에 대해서만 다음을 계산한다.

\[
\bar M=\frac{1}{4}\sum_{i=1}^{4}M_i,\qquad
s=\sqrt{\frac{\sum_{i=1}^{4}(M_i-\bar M)^2}{3}},\qquad
CV=100\frac{s}{\bar M}
\]

\[
ASMI=\frac{\overline{ASM}}{h^2},\qquad SMMI=\frac{\overline{SMM}}{h^2}
\]

질량 단위 kg, 키 단위 m, 지수 단위 kg/m². ASM과 SMM은 각각 다른 측정량이며 서로 변환·대입하지 않는다. 4회 평균은 측정 편차를 요약하는 제품 규칙이지 체계적 BIA 편향을 제거하거나 정확도를 보증하는 임상 근거가 아니다. 분류 코드와 기존 경계 근거는 [ASM/SMM 설계](asm-smm-pathways.md), `shared-contracts/muscle-pathways.ts`를 따른다.

### 실제 진동의 물리량 — 이상적인 단일축 정현파에 한정

\[
x(t)=A\sin(2\pi ft),\quad A=\frac{D_{pp}}{2}\times10^{-3}\;[m]
\]
\[
a_{peak,g}=\frac{(2\pi f)^2A}{9.80665},\qquad
a_{rms,g}=\frac{a_{peak,g}}{\sqrt 2}
\]
\[
T_{active}=n\,t_{bout},\qquad T_{rest}=\max(0,n-1)t_{rest}
\]

`Dpp`는 mm 단위 peak-to-peak 변위다. %는 이 식에 들어가지 않는다. 출력에는 `IDEAL_SINUSOID_SINGLE_AXIS_NOT_MEASURED_BODY_DOSE`를 명시한다. 계산한 RMS는 측정 RMS가 아니며, 전신·어깨·머리에 전달된 가속도도 아니다. 비정현파, 다축 합성, 좌우 교대 장치의 발 위치는 이 식만으로 평가하지 못한다. 실제 측정과 독립 검토가 계속 필요하다.

검사할 수학적 불변식은 `a(2f,D)=4a(f,D)`, `a(f,2D)=2a(f,D)`. 부동소수 오버플로·언더플로 또는 안전한 정수 범위를 넘는 시간 합계는 물리량을 반환하지 않고 검토 상태로 보낸다.

RCT 세 군의 `20×720=40×360=60×240=14,400`은 같은 주기 횟수일 뿐 같은 생체 반응을 뜻하지 않는다. 따라서 **단계 번호는 물리적 강도의 단조 증가를 보증하지 않는다.** 하향/상향 모두 해당 프로토콜 쌍에 별도 `reviewRef`가 있어야 후보를 낸다. 그 문자열은 검토 증거의 진위 검증이나 실행 허가를 대신하지 않는다.

### 적응 규칙 — 검증할 연구 가설

현재 적용된 단계를 \(k\), 정책이 요구하는 완료 횟수를 \(q\), RPE 구간을 \([r_{min},r_{max}]\)라 한다. RPE는 이 계약에서 정수 0–10 자기보고값이며 다른 척도를 자동 변환하지 않는다.

| 우선순위 | 조건 | 결정 |
|---|---|---|
| 1 | 현재 통증·어지럼·사용보류 | HOLD |
| 2 | 정책/이력/소유권/시각/현재 단계 불일치 | REVIEW, 후보 없음 |
| 3 | 제공된 동일 맥락 이력의 어느 기록이든 이상반응 있음 | HOLD. 최신 정상 기록으로 해제하지 않음 |
| 4 | 최신 세션 미완료 | HOLD |
| 5 | 최신 시간·Hz·강도 중 하나가 STRONG 또는 RPE 상한 초과 | 최저 단계라면 HOLD, 아니면 승인 전이가 있는 k−1 후보 |
| 6 | 최근 q건 모두 같은 k에서 완료, RPE 구간 내, 세 체감 모두 WEAK | 승인 전이가 있는 k+1 검토 후보. 최고 단계면 유지 |
| 7 | 나머지 | k 유지 후보 |

새 참여자만 명시적 빈 이력+`currentStageId=null`로 시작할 수 있다. 근육 분류에 대응하는 시작 단계가 정책에 없으면 임의값으로 채우지 않는다. 모든 후보는 독립 검토가 필요하며 실제 적용 단계를 바꾸지 않는다.

`q=2`, RPE `2–6`, 이력 기간 `30일`은 **합성 시험 데이터**다. 논문에서 검증된 우리 장치의 기준이나 앱 기본 처방이 아니다. 실제 운영값은 연구팀이 근거·대상·장치·평가 결과와 함께 버전 정책으로 확정해야 한다.

## 4. 이번에 고친 결함

| 이전 동작 | 변경 | 검증 |
|---|---|---|
| history 누락/null도 최초 사용자로 처리 | 명시적 배열과 완전성 맥락 필수 | omitted/null/wrong type/returning user 사례 |
| 다른 참여자·장치·정책 이력 사용 가능 | context 및 각 기록 일치 검사 | 소유권/장치/정책 사례 |
| 미래·오래된 기록·동일시각 순서 불명확 | 정책 기간 검사, 동일시각 중복 거부 | 날짜/기간/timestamp tie 사례 |
| 최신 정상 기록이 과거 통증을 가림 | 이전 이상반응을 자동 해제하지 않음 | older pain/dizziness 사례 |
| k−1이면 무조건 더 약하다고 취급 | 전이별 검토 참조 필수, 후보도 독립 검토 | no downward/upward review 사례 |
| Dart 정수형 2.0의 형변환 예외 | 정수 검사 후 num.toInt() | 공유 JSON integer double 사례 |
| 같은 근육 층의 프로토콜이 여러 개면 연결 불가 | 단계가 지정한 정확한 protocolId와 근육 층 동시 확인 | 연결·ID 선택 테스트 |
| 물리 계산에 Infinity/0이 나올 수 있음 | 유한성·양수·안전한 정수 결과 검사 | 1e308/1e−300 Hz 입력 사례 |
| 선택기와 물리 평가기가 독립적으로만 존재 | evaluateAdaptiveResearch 연결 함수 | TS/Dart 연결 테스트 |

## 5. 모듈 책임·계약·보안 경계

| 위치 | 책임 |
|---|---|
| `shared-contracts/muscle-pathways.ts` / Dart `muscle_pathways.dart` | 동일인 4건·측정 정의·근육 지수/분류 |
| `shared-contracts/adaptive-protocol.ts` / Dart `adaptive_protocol.dart` | 정책·이력 조건 평가 및 모듈 연결 |
| `shared-contracts/protocol-readiness.ts` / Dart `protocol_readiness.dart` | 후보 물리 프로토콜·교정·독립 검토 조건 |
| `shared-contracts/*protocol*.schema.json` | 각 평가기의 JSON 입력 계약 |
| `shared-contracts/fixtures/adaptive-research-0.2.0.json` | 공유 합성 회귀 데이터·기대 결정 |
| `backend-api/tools/adaptive-cases.ts` | 891개 이산 입력 조합 생성 |
| `backend-api/tools/verify-adaptive-parity.ts` / `mobile-app/tool/compare_adaptive_protocol.dart` | 같은 입력의 전체 결과 비교 |

순수 함수는 DB를 읽거나 승인기관에 조회하지 않는다. **참여자 ID를 비교하는 검사는 인증/권한 시스템의 대체가 아니다.** `historyComplete`, `approvalRef`, `reviewRef`, 현재 적용 단계는 신뢰된 서버 Repository가 조회해야 하고 앱의 임의 JSON을 신뢰하면 안 된다. 연결 함수는 `muscleAssessment`를 직접 받아 신뢰하지 않고 네 측정에서 다시 계산하며, 참여자와 선택된 진동 장치의 맥락도 확인한다.

이력의 완전성과 안전보류 상태를 서버에 영속화하고, 변경/보류 해제 승인을 감사하는 저장·API 기능은 아직 연결되지 않았다. 오래된 이력을 삭제하거나 기간 밖 기록을 몰래 제외하여 보류를 풀면 안 된다. 재평가·보류 해제 워크플로가 마련되기 전에는 REVIEW/HOLD로 남긴다.

현재 JSON Schema는 구조 계약이고 함수는 핵심 업무 검증을 수행한다. 실제 외부 API 경계에서 스키마 허용목록·길이/개수 제한·권한 검사를 강제하는 것은 별도 통합 작업이다. 새 입력이 없는 0.1 호출은 0.2에서 검토 상태가 되며, 누락값 자동 기본값은 없다.

## 6. 검증과 재실행

1. `(backend-api)` `npm test -- --reporter=dot`
2. `(backend-api)` `npm run typecheck`
3. `(repo root)` `npm run lint`
4. `(mobile-app)` `flutter test --no-pub`, `flutter analyze --no-pub`
5. `(repo root)` `node --experimental-strip-types backend-api/tools/verify-adaptive-parity.ts`

5번은 Dart가 PATH에 있거나 `DART_BIN` 환경변수가 설치된 dart 실행파일을 가리켜야 한다. Windows 한글 경로 분석 오류가 나면 기존 영문 junction `E:/vibecare-pilot/mobile-app`을 이용할 수 있다. 패키지 추가 설치는 없다.

검증 결과는 아래 완료 기록과 `state/current.md`에 기록한다. 공통 fixture 41건 + 이산 조합 891건 = **932건**. TypeScript/Dart의 모든 결과 필드가 정확히 같은지 비교한다. TS에는 입력 불변성과 이력 순서 불변 테스트도 있다. 결합 흐름과 물리량은 양쪽 런타임별 별도 테스트이며, 결합 흐름 전체 JSON의 언어 간 동등성까지 검사했다고 주장하지 않는다.

테스트 통과는 구현한 규칙의 정확성에 관한 증거다. 사람의 통증·효과·안전성이 검증됐다는 뜻은 아니다.

### 2026-09-09 실제 실행 결과

| 검사 | 결과 |
|---|---|
| 백엔드 전체 Vitest | 10파일, 1,192/1,192 통과 |
| Flutter 전체 테스트 | 295/295 통과. 기존 작은 화면·큰 글자·Mock 시작/중지·피드백 포함 |
| TS/Dart 선택기 전체 JSON 동등성 | 932/932 일치 |
| 백엔드 typecheck / 프로젝트 oxlint | 종료코드0 |
| Flutter analyze | No issues found |
| JSON Schema | 두 계약 스키마 유효, adaptive 정상 fixture 적합. 기존 jsonschema4.25.1 사용 |
| 신규 APK 빌드·실장비·임상 평가 | 이번 변경에서 수행하지 않음 |

첫 Flutter 전체 검사에서 신규 테스트 데이터의 Map 타입 오류 1건을 수정한 뒤 전체 295건을 다시 통과했다. 테스트 도구의 sandbox spawn EPERM 및 복구 기록은 `state/failures.md`에 있다. 측정량 분류 경계는 이번에 변경하지 않았으며 이전 테스트도 전체 회귀에 포함했다.

## 7. 유지보수와 다음 연구

변경 절차는 **문헌/장치 명세 확인 → 적용 대상과 가설 기록 → 실패 사례 fixture 추가 → TS/Dart 함께 수정 → 회귀/동등성 검사 → 독립 검토 → 정책 버전 발행**이다. 운영 반영과 장치 실행은 이 순서 뒤에 별도로 승인한다. 정책은 덮어쓰지 않고 버전별 보관하고, 정책·근육 분류가 바뀌면 기존 이력을 그대로 승계하지 않고 재평가한다.

실데이터 단계에서 저장할 최소 연구 항목은 측정 정의·원본 ID/시각, 네 건 평균/변동, 성별·나이·체지방, 장치/펌웨어/교정/자세/부하, 실제 적용 물리량과 bout, 완료 여부, RPE, 통증/어지럼, 시간·Hz·강도 각 체감이다. 식별정보·원본 건강정보는 Git이나 콘솔이 아닌 접근 제한 저장소에서 관리한다.

후속 가설은 “근육 지수·나이·성별·체지방이 **같은 검증된 노출 조건에서** 불편감과 관련되는가”로 정의한다. 승인된 연구에서 반복 측정에 맞는 분석, 참여자 단위 학습/평가 분리, 고정 프로토콜 대비 효과·유해사건·탈락률 비교를 해야 한다. 현재 계수 추정·모델 학습·전향 임상 비교는 하지 않았다. 자료 없이 선형 계수나 최적 Hz를 생성하지 않는다.

실사용 전 우선순위: FITRUS ASM/SMM 정의·실응답 확정 → 신뢰된 이력/정책 Repository → 장치 하중별 파형·변위·3축 peak/RMS 교정 → 독립 임상/공학 검토 → Mock UI 통합 → 승인된 전향 연구. 기존 연구 후보를 인체 자동 실행으로 바꾸는 기능은 이 변경 범위에 없다.
