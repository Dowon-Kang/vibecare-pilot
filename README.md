# VibeCare Pilot

FITRUS 체성분 측정 4건의 출처와 품질을 확인하고, 확인된 `ASM`(사지근육량) 또는 `SMM`(전신 골격근량)을 연구 층화한 뒤 **검증되지 않은 시뮬레이터 후보값**을 보여주는 Flutter 연구 프로토타입입니다.

> `pilot-0.8.0`은 의료 처방이 아닙니다. 물리 장치 실행은 모든 경로에서 `PROHIBITED`이며, 현재 허가는 Mock 시뮬레이션에만 발급됩니다.

## 핵심 흐름

```text
로그인 → 최근 측정 4건의 출처·품질 확인
      → 평균·표본 SD·CV·범위 계산
      → 확인된 ASM 또는 SMM 연구 층화
      → 안전 문진 → Mock 후보 확인 → 시뮬레이션 시작/중지 → 피드백
```

근육량 정의가 `UNKNOWN`이거나 4건의 정의·방법·단위·획득 프로토콜이 맞지 않으면 층화와 후보 생성을 모두 거부합니다. ASM과 SMM은 사용자가 임의로 바꾸어 해석하지 않습니다.

## 폴더 구조

```text
mobile-app/        Flutter Android 앱과 앱 테스트
backend-api/       인증·FITRUS 프록시·서버 재계산·Mock 세션 API
shared-contracts/  OpenAPI, JSON Schema, 공통 fixture
deployment/aws/    AWS 배포 담당자를 위한 인계 조건
docs/              아키텍처, 알고리즘 근거, 검증 기록
```

## 실행

```powershell
Push-Location .\mobile-app
flutter pub get
flutter run
Pop-Location

Push-Location .\backend-api
npm ci
npm run typecheck
npm test
Pop-Location
```

백엔드 연결 앱은 `--dart-define=VIBECARE_API_BASE_URL=https://...`를 사용합니다. FITRUS 키는 앱이나 Git에 넣지 않고 백엔드 환경변수 `FITRUS_API_KEY`로만 주입합니다.

## 구현 경계

- Backend algorithm: `pilot-0.8.0`의 측정 적격성, SMM 4건 평균, 6개 부위 기준값, 성별·나이·체지방 연구용 보정, 안전 차단 구현
- Baselines and coefficients: 프로젝트 제공값을 코드·서버 규칙·화면에서 추적하며 모두 `HYPOTHESIS_UNVALIDATED`로 표시
- Demographics: 나이·성별·체지방을 진동량에 곱하는 보정은 사용하지 않음. 성별은 정의별 연구 경계 선택에만 사용
- FITRUS: 공식 요청·응답 필드에 맞춘 서버 전용 프록시와 체성분·활력 자동 저장 경로가 구현됨. 단위·유효 범위·근육 산출법이 미확인인 값은 추정하지 않고 미지원 응답은 raw로 보존
- Device: 앱 내부 Mock과 서버 시뮬레이터만 구현. REST/BLE 물리 장치 어댑터는 없음
- AWS: 인계 문서와 저장소 포트만 있음. 운영 인프라·AWS DB 어댑터는 미구현

테스트 통과는 코드 흐름의 재현성을 뜻하며 임상 효과나 물리 장치 안전을 증명하지 않습니다. 정량 결과와 원격 빌드 상태는 [검증 체크리스트](checklist.md)와 최신 GitHub Actions 실행을 함께 확인하세요.

자세한 내용은 [문서 안내](docs/README.md), [계획](plan.md), [검증 체크리스트](checklist.md)를 확인하세요.
