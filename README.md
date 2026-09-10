# VibeCare Pilot

FITRUS 체성분 측정값 4건을 평균하고, 골격근량을 `사지근육량(ASM)` 또는 `전신 골격근량(SMM)`으로 해석해 연구용 진동 시간·주파수·강도를 비교하는 Flutter 프로토타입입니다.

> 현재는 Mock 데이터와 Mock 장치만 실행합니다. FITRUS 응답 규격, 진동기 통신 명세와 장비 교정값이 확정되기 전에는 실제 진동을 출력하지 않습니다.

## 핵심 흐름

```text
로그인 → 최근 측정 4건 평균 → ASM/SMM 기준 선택
      → 안전 문진 → 설정 전송 → 시연 시작/중지 → 사용 후 피드백
```

## 폴더 구조

```text
mobile-app/        Flutter Android 앱과 앱 테스트
backend-api/       인증·FITRUS 프록시·추천 재검산·세션 API
shared-contracts/  OpenAPI, JSON Schema, 공통 fixture
deployment/aws/    AWS 배포 담당자를 위한 인계 조건
docs/              아키텍처, 알고리즘 근거, 검증 기록
```

## 실행

```powershell
# 저장소 루트에서 Flutter Mock 앱 실행
Push-Location .\mobile-app
flutter pub get
flutter run
Pop-Location

# 저장소 루트에서 백엔드 검사
Push-Location .\backend-api
npm ci
npm run typecheck
npm test
Pop-Location
```

백엔드 연결 앱은 `--dart-define=VIBECARE_API_BASE_URL=https://...`를 추가합니다. 실제 API 키는 앱이나 Git에 저장하지 않고 백엔드 환경변수 `FITRUS_API_KEY`로만 주입합니다.

## 현재 구현 상태

- Flutter: 측정값, 두 근육량 해석 결과, 안전 문진, 강도 조절, Mock 전송·시작·중지·피드백 구현
- Backend: PIN 인증, 본인 측정 조회, 서버 재계산, 일회성 시연 허가와 세션 기록 구현
- Algorithm: `pilot-0.6.0`은 근육지수 등급으로 Mock 시간·Hz·강도 preset을 선택한다. 연령·성별·체지방 곱셈 보정은 사용하지 않는다(현재 계수 모두 `1.0`).
- FITRUS: URL과 인증 경계만 준비됨. 공식 성공 응답 스키마가 없어 실제 정규화는 미완료
- 진동기: 공통 게이트웨이와 Mock만 구현. REST/BLE 실장비 어댑터는 미구현
- AWS: 인계 문서만 제공. 라우트는 `SqlDatabase` 포트에 의존하며 현재 D1 구현을 AWS DB 어댑터로 교체해야 함

## 마지막 검증 기준

- 기준 커밋: `13a16c0`
- GitHub Actions: [quality-gates 실행 34443151436](https://github.com/Dowon-Kang/vibecare-pilot/actions/runs/34443151436)
- 백엔드: typecheck 통과, Vitest 56/56 통과
- Flutter: format·analyze·전체 테스트·debug APK 빌드 통과

테스트 통과는 코드 흐름의 재현성을 뜻하며 임상 효과나 실제 장비 안전을 증명하지 않는다.

자세한 내용은 [문서 안내](docs/README.md), [계획](plan.md), [검증 체크리스트](checklist.md)를 확인하세요.
