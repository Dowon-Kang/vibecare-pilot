# VibeCare 문서와 저장소 안내

이 파일이 공개 문서의 단일 진입점이다. 문서에 적힌 계획과 실행 코드를 구분하며, 최신 구현 상태는 코드·테스트·검증 기록으로 교차 확인한다.

## 저장소 구조

```text
vibration-control-app/
├── app/                    # React/Vinext 비교용 웹 화면
├── mobile-app/             # 주 클라이언트: Flutter Android 앱
│   ├── lib/                # 화면·상태·서비스·Dart 알고리즘
│   ├── test/               # 단위·위젯·통합 회귀검사
│   ├── tool/               # 언어 간 알고리즘 비교 실행기
│   └── android/            # Android 빌드·Manifest
├── backend-api/            # 인증·FITRUS 프록시·추천·세션 API
│   ├── src/                # HTTP 및 서버 권위 계산
│   ├── migrations/         # 현재 D1 SQL 기준선; AWS DB 전환 필요
│   ├── test/               # API·보안·알고리즘 검사
│   └── tools/              # 공통 fixture·동등성 검증
├── shared-contracts/       # OpenAPI·JSON Schema·공통 TS 알고리즘·fixture
├── deployment/aws/         # AWS 담당자 인수 조건; 배포 코드는 아직 없음
├── docs/
│   ├── algorithm/          # 수식·의사결정·근거 수준
│   └── evidence/           # 실행한 검증과 외부 계약 확인 기록
├── .github/workflows/      # GitHub 자동 품질검사
├── plan.md                 # 다음 구현 순서와 완료 조건
├── checklist.md            # 정량 품질 게이트와 현재 상태
└── design.md               # 고령자 모바일 UI 규약
```

## 제품 흐름과 책임

```text
FITRUS API
  → backend-api: 비밀키 보호·원본 수신·정규화(현재 미완료)
  → shared-contracts: 데이터 형식과 알고리즘 규칙
  → mobile-app: 입력/평균/결과 표시·Mock 장치 흐름
  → DeviceGateway: Mock 구현 / 실제 REST·BLE 미구현
```

| 구성요소 | 현재 책임 | 상태 |
|---|---|---|
| `mobile-app/` | 고령자용 측정·추천·전송·시작·중지 UI | Mock 흐름 구현 |
| `backend-api/` | PIN 인증, 본인 데이터, 재계산, 1회성 허가, 세션 | 로컬 프로토타입 |
| `shared-contracts/` | 입력/출력 계약, 연구 알고리즘, 공통 fixture | 구현·검증 |
| FITRUS Adapter | 공급사 원본을 표준 측정값으로 변환 | 성공 응답 계약 대기 |
| 실제 진동기 Adapter | 물리 장치 연결·ACK·긴급 중지 | 명세·교정 대기 |
| AWS 배포 | 런타임·DB·비밀·관측성 구성 | 인계 문서만 존재 |

## 읽는 순서

1. [README](../README.md): 목적, 실행 방법, 외부 연동 상태
2. [아키텍처](architecture.md): 사용자·데이터·안전 흐름
3. [최신 알고리즘](algorithm/adaptive-research-v2.md): 입력, 수식, 결정 규칙, 근거와 한계
4. [ASM/SMM 분리](algorithm/asm-smm-pathways.md): 사지근육량과 전신근육량 정의
5. [API 계약](../shared-contracts/openapi.yaml): 앱과 서버의 공개 HTTP 형식
6. [AWS 인계](../deployment/aws/README.md): 다음 담당자가 구현할 항목
7. [체크리스트](../checklist.md): 완료·부분·차단과 정량 검증

## 현재와 과거 구분

- 현재 앱의 연결된 계산 경로는 `pilot-0.6.0`이다.
- `pilot-0.7.0`, `adaptive-research-0.2.0`, `research-gate-0.8.1`은 연구 모듈과 테스트까지 구현됐지만 앱 UI/API 실행 경로에는 활성화되지 않았다.
- 체지방 기반 연속 증량과 근육량별 고정 Hz 매핑은 임상적으로 검증되지 않았으므로 실장비 기준으로 사용하지 않는다.
- 모든 새 연구 모듈은 `command=null`, `realDeviceSendAllowed=false`를 유지한다.
- GitHub 테스트 통과는 코드 재현성을 뜻하며 임상 효과나 안전성의 증명이 아니다.

## Git에 포함하지 않는 것

```text
node_modules/  build/  .dart_tool/  .gradle/
.next/  .vinext/  dist/  .wrangler/
.env*  backend-api/.dev.vars  *.local.txt  state/
```

실제 FITRUS API 키, PIN 원문, 사용자 건강데이터, 장치 운영 비밀은 저장소에 넣지 않는다.
