# pilot-0.3.0 알고리즘 일치 검증

검증일: 2026-09-03

공통 fixture: `shared-contracts/fixtures/pilot-0.3.0.json`

| 구현 | 검증 | 결과 |
|---|---|---|
| 기존 TypeScript | `node --test lib\vibration-algorithm.test.mjs` | 5/5 통과 |
| Flutter 순수 Dart 도메인 | `dart --enable-asserts tool\verify_algorithm.dart` | 통과 |
| Workers TypeScript | `npm test` (`backend-api/`) | 알고리즘 3건 + FITRUS 클라이언트 2건 통과 |
| Workers 타입 검사 | `npm run typecheck` (`backend-api/`) | 통과 |

확인된 공통 결과:

- 4회 평균 체중: `42.05 kg`
- 4회 평균 체지방률: `18.88%`
- 여성 예제: `50 × 0.90 × 0.95 × 0.90 = 38.475 → 38%`
- 동일 값 남성 예제: `50 × 0.90 × 1.00 × 1.00 = 45%`
- 평균 BMI `17.75`이므로 두 예제 모두 `REVIEW`
- 어지럼 입력은 추천값 없이 `BLOCKED`

Flutter SDK 의존 패키지를 포함한 `flutter test`는 로컬 Flutter 도구 초기화 문제가 해결된 뒤 추가 실행해야 한다. 순수 Dart 계산 코드는 같은 SDK의 Dart 실행기로 별도 검증했다.
