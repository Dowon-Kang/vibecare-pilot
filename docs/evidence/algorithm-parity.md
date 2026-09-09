# 알고리즘 교차 검증 현황

이 문서는 과거 단일 fixture 기록 대신 현재 검증 자료를 안내한다.

| 대상 | 최신 증거 | 의미 |
|---|---|---|
| 현재 앱 경로 `pilot-0.6.0` | [설계 심사](../algorithm/pilot-0.6.0-design-review.md), [실행 결과](pilot-0.6.0-validation.md) | 웹·백엔드·Flutter 회귀 및 Mock 흐름 |
| ASM/SMM 평가 `pilot-0.7.0` | [정의와 수식](../algorithm/asm-smm-pathways.md), [실행 결과](pilot-0.7.0-pathways-validation.md) | 사지/전신 근육량 분리와 공통 fixture |
| 적응 선택 `adaptive-research-0.2.0` | [최신 방법론·검증](../algorithm/adaptive-research-v2.md) | 공유 41사례와 891개 이산 조합, 총 932개 TS/Dart 전체 JSON 일치 |
| 물리 검토 `research-gate-0.8.1` | [최신 방법론·검증](../algorithm/adaptive-research-v2.md) | 정현파 peak/RMS, 교정 오차, 독립 검토 조건 |

검증 통과는 구현된 규칙의 재현성을 의미한다. FITRUS 측정 정의의 동등성, 근육량에서 특정 진동 용량으로 이어지는 인과, 사람 대상 효과·안전성을 증명하지 않는다.
