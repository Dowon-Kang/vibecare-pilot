# VibeCare Pilot

> 저장소를 처음 살펴본다면 [파일 구조와 책임](docs/FILE_STRUCTURE.md)부터 확인하세요. Flutter 앱, 백엔드 API, 공통 데이터 규격과 테스트의 실제 연결 경로를 설명합니다.

FITRUS 체성분 측정 4건의 평균과 파일럿 보정 규칙을 이용해 진동 시간·주파수·강도를 추천하고, 전송·시작·중지 과정을 검증하는 연구용 프로토타입입니다.

> 현재 기본 실행은 Mock 데이터와 Mock 장치를 사용합니다. FITRUS 운영 API와 실제 진동 장비는 공급사 요청·응답 계약 및 장비 안전 명세가 확보되기 전까지 활성화하지 않습니다.

## 저장소 구성

```text
app/               웹 비교 화면과 웹 전용 알고리즘
mobile-app/        Flutter Android 앱
backend-api/       FITRUS·장치 연결을 보호하는 백엔드 API
shared-contracts/ 앱·백엔드 공통 데이터 규격
deployment/aws/   AWS 배포 담당자용 인수 조건과 환경변수 계약
docs/              설계·근거·검증·프로젝트 분석
```

파일 단위의 상세 책임과 현재 구현 상태는 [전체 파일 구조](docs/FILE_STRUCTURE.md)를 기준으로 확인합니다.

## FITRUS 연동 상태

| 경로 | 의미 | 현재 적용 |
|---|---|---|
| `/bodyfat` | 체성분/BIA 측정 | 향후 4건 평균의 주 입력. 현재 앱은 fixture 사용 |
| `/bp` | 혈압 추정 | 저장·표시 후보이며 강도 계산에는 미사용 |
| `/hr` | 심박 측정 | 저장·표시 후보이며 강도 계산에는 미사용 |
| `/stress` | 스트레스 측정 | 저장·표시 후보이며 강도 계산에는 미사용 |
| `/stress2` | 대체 스트레스 모델 | 공급사 차이 설명 전까지 미채택 |
| `/bodytemp` | 체표면/체온 측정 | 저장·표시 후보이며 강도 계산에는 미사용 |

모바일 앱은 FITRUS API를 직접 호출하지 않습니다. `backend-api/src/fitrus-client.ts`만 `x-api-key`를 사용하며 앱은 VibeCare 백엔드 API의 표준 응답만 읽습니다. 공급사 성공 응답 스키마가 아직 없어 프록시 응답은 원본으로 저장되고 `normalized: false`로 반환됩니다.

## 로컬 실행

### Flutter Mock 앱

```powershell
cd mobile-app
E:\flutter-sdk\bin\flutter.bat run
```

백엔드 연결 빌드는 `--dart-define=VIBECARE_API_BASE_URL=https://...`를 사용합니다. 값을 생략하면 Mock 모드입니다.

### 웹 비교 화면

```powershell
npm install
npm run dev
```

### 백엔드 API

```powershell
cd backend-api
npm install
npm test
```

실제 키는 Git에 넣지 말고 백엔드 환경변수 `FITRUS_API_KEY`로만 주입합니다. 최종 배포 대상은 AWS이며, 현재 Cloudflare Workers/D1 코드는 교체가 필요한 프로토타입 어댑터입니다. 인수 조건은 [AWS 배포 인계 문서](deployment/aws/README.md)를 따릅니다.

## 안전 범위

`pilot-0.3.0`의 연령·성별·체지방 계수는 임상 확정값이 아닌 파일럿 규칙입니다. 통증·어지럼·사용 보류는 실행을 차단하며, 실제 장비의 진폭·가속도·ACK·긴급중지 명세가 검증되기 전에는 물리 출력을 활성화하지 않습니다.

상세 진행 상태는 [`checklist.md`](checklist.md), 시스템 구조는 [`docs/system-design.md`](docs/system-design.md)를 참고하세요.

## Windows 문제 해결

- 웹 화면의 `Cannot read properties of undefined (reading 'send')`는 Android 오류가 아니라 Vite 개발용 HMR 소켓 경합입니다. 이 저장소는 콘솔 전달을 비활성화해 반복 오류 오버레이를 방지합니다.
- Flutter 분석 서버가 한글 경로에서 잘린 LSP JSON을 읽을 수 있으므로, 문제가 재현되면 프로젝트를 가리키는 영문 junction과 영문 `TEMP`/`TMP` 경로에서 분석·테스트합니다.
- 검증 기준 에뮬레이터는 Android 35 `VibeCare_Pixel_7_API35`입니다. API 36 이미지에서 불안정하면 Android 35의 cold boot를 우선 사용합니다.
