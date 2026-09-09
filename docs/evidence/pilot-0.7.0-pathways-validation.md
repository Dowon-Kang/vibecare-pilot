# pilot-0.7.0 ASM/SMM 비교 모듈 검증

검증일: 2026-09-09. 범위: 새 순수 연구 계산 모듈과 기존 코드 회귀 검사. [설계·근거·실행 방법](../algorithm/asm-smm-pathways.md).

## 실행 결과

| 위치 | 명령 | 최종 결과 |
|---|---|---|
| backend-api | `npm test` | 6파일, 130/130 통과. 신규81 + 기존49 |
| backend-api | `npm run typecheck` | exit0 |
| mobile-app, 기존 영문 junction E:/vibecare-pilot | `flutter test --no-pub` | 126/126 통과. 신규81 + 기존45 |
| 같은 위치 | `flutter analyze --no-pub` | No issues found, exit0 |
| repo root | `node --experimental-strip-types backend-api/tools/verify-muscle-pathways.mjs --dart E:\flutter-sdk\bin\cache\dart-sdk\bin\dart.exe` | 79개 전체 JSON 출력 일치, 숫자 허용오차1e-10 |
| repo root | `node --experimental-strip-types --test app/algorithm/vibration-algorithm.test.mjs` | 기존 웹8/8 통과 |
| repo root | `npm run lint` | exit0 |
| repo root | `git diff --check` | 공백 오류 없음. 기존 파일 CRLF 변환 안내 존재 |
| repo root | Node JSON.parse | 새 입력 Schema·공통 fixture 2파일 문법 파싱 성공 |
| mobile-app | `dart tool/compare_muscle_pathways.dart` | 합성 ASM/SMM 결과 JSON 출력. 장치/API 호출 없음 |

도구: 기존 Node22.19.0, Flutter3.47.2/Dart3.13.2. 신규 패키지·SDK 설치 없음. 임상 데이터나 비밀키 사용 없음.

## 확인한 동작

- ASM의 나이64/65 × BIA/DXA × 성별, 각 경계 바로 아래/같음/위.
- SMM 성별별 두 경계 바로 아래/같음/위. 문헌 적용 최소연령과 미지원 방법.
- 정의 미상·혼합·정의 참조 누락, 다른 사용자·기기, 중복 ID, 3건/5건, 결측/문자열/음수/비유한 근육량, 품질 실패.
- 잘못된 날짜·시간대 누락·체지방 불일치·BMI 불일치, 문진 누락과 세 차단 증상.
- BMI18.499/18.5, 반복 측정값 구간 교차, 평균·표본 SD.
- 160cm의 소수 연산 경계. 이진 오차 때문에 정확한 ASM 경계를 LOW로 분류하는 문제를 머신 정밀도 수준 비교로 방지.
- 모든 경로 command=null 및 realDeviceSendAllowed=false. 정상값도 CALIBRATION_REQUIRED. 증상 시 평가/조건 null, REVIEW 시 조건 null.
- 79사례 기대값 검증은 양쪽에서 각각 수행. 별도 비교 도구는 상태·분류·preset·근거·추적 ID/시각·SD/CV를 포함해 반환 객체 전체를 비교한다. 모든 가능한 입력의 수학적 동일성을 증명한 것은 아니다.

## 이번 작업이 증명하지 않는 것

- 실제 FITRUS 필드가 ASM 또는 SMM이라는 사실, 해당 BIA 기기/식과 문헌 모집단의 동등성.
- 근육량 분류가 통증이나 최적 진동 조건을 예측한다는 인과관계. 분류→P1/P2/P3는 미검증 프로젝트 가설이다.
- 나이·성별·체지방 통증계수 학습, 실제 참여자의 치료 효과나 안전성.
- 장치의 진폭·가속도·주파수 교정, 실제 명령/ACK/긴급 중지.
- 신규 모듈의 화면·Controller·서버 route·DB 통합. 기존 v0.6.0 흐름은 유지했다.
- 이번 턴 APK 재빌드·에뮬레이터 설치·실장치 실행·클라우드 배포는 하지 않았다. Flutter 테스트 컴파일 통과를 APK 빌드 성공으로 표현하지 않는다.
- JSON 문법 파싱은 전체 JSON Schema conformance 검사가 아니다.

## 실패와 복구

- 최초 sandbox Dart 배치 포맷 실행이 무출력 지연: 해당 실행만 중단, 승인된 기존 dart.exe 직접 실행으로 복구.
- oxFmt sandbox 자식 프로세스 spawn EPERM: 새4파일만 승인된 로컬 포매터로 재실행 성공.
- 최초 Flutter analyze: 신규 파일16개 스타일 진단(중괄호14, package import2). 실제 수정 후 최종 No issues found.
- `dart fix` 첫 진단명 오타로 실행 실패: SDK가 보고한 `curly_braces_in_flow_control_structures`로 지정하여 해당 파일14곳 수정. 다른 소스 일괄 수정 없음.

## 코드/fixture SHA-256

- shared-contracts/muscle-pathways.ts: FA0ECAD7096EF2B0620D614624C4976C2AF748632DA559E26B2A6F99A8E106C8
- mobile-app/lib/algorithm/muscle_pathways.dart: BAFFB5888F6B95B6FBBEADB68724BDF03927CF84361F3B56CEA65C1D56BA12E4
- shared-contracts/fixtures/pilot-0.7.0-pathways.json: C0812FABBEAC5CCE43401AA94FA2526E04B154BCB761BB27951331FFD52FF29B

Git 작업 트리는 시작부터 여러 기존 수정/미추적 파일을 포함했다. 이 기록은 이번에 추가한 v0.7.0 모듈의 검증이며 다른 변경의 작성자·완성도를 보증하지 않는다. commit/push하지 않았다.
