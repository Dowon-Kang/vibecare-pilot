# AWS 배포 인수 조건

이 폴더는 AWS 리소스를 생성하거나 배포하지 않는다. 다음 담당자가 기존 API 계약과 안전 규칙을 보존하면서 AWS 런타임을 선택하고 구현할 수 있도록 필요한 경계만 정의한다.

배포 우선순위는 `mobile-app/`이 호출하는 `backend-api/`다. 루트 `app/`은 비교·시연용 웹 화면이며 `.openai/hosting.json`과 Sites 플러그인은 기존 웹 미리보기 설정일 뿐 AWS 운영 백엔드 구성이 아니다. 웹 화면까지 AWS에 배포할지는 별도로 결정한다.

## 그대로 재사용하는 부분

- `../../backend-api/src/`: 인증, FITRUS 프록시, 추천 재계산, 실행 허가와 세션 흐름
- `../../shared-contracts/openapi.yaml`: Flutter와 백엔드 사이의 HTTP 계약
- `../../backend-api/migrations/`: 현재 데이터 구조를 이해하기 위한 SQL 기준선
- `GET /health`: 로드밸런서와 배포 확인용 상태 경로
- `DEVICE_MODE=mock`, `REAL_DEVICE_ENABLED=false`: 실제 장비 명세가 확정되기 전의 안전 기본값

## AWS 담당자가 반드시 구현할 부분

1. 실행 방식을 결정한다. 장시간 연결과 향후 장치 통신을 고려하면 기본 후보는 `ECS Fargate + ALB`이며, 호출량이 매우 적고 요청 단위 처리만 필요하면 `Lambda + API Gateway`를 비교한다.
2. `D1Database` 직접 의존을 저장소 인터페이스로 분리하고 AWS 데이터베이스 어댑터를 연결한다. 운영 기본 후보는 RDS PostgreSQL이다. 현재 D1 SQL을 그대로 운영 SQL이라고 가정하지 않는다.
3. 선택한 런타임에 맞는 HTTP 진입점과 종료 처리를 추가한다. 현재 `backend-api/src/index.ts`는 Web Fetch 형식의 Hono 앱을 export한다.
4. `required-environment.example`의 비밀값을 코드·이미지·로그에 넣지 않고 Secrets Manager 또는 SSM Parameter Store에서 주입한다.
5. ECR 이미지 스캔, CloudWatch 로그·경보, HTTPS, CORS 허용 출처, 최소 권한 IAM, 개발/운영 환경 분리를 구성한다.
6. D1에서 AWS DB로 이동할 경우 데이터 변환·백업·롤백 절차를 작성한다.

## 배포 전 완료 기준

- `GET /health`가 ALB/API Gateway를 통해 200을 반환한다.
- `backend-api` 테스트와 타입검사가 통과한다.
- `shared-contracts/openapi.yaml`과 실제 요청·응답이 일치한다.
- API 키와 토큰 비밀값이 Git, 컨테이너 이미지, Flutter APK, 로그에 존재하지 않는다.
- `DEVICE_MODE=mock`에서 로그인→측정 조회→추천 허가→세션 시작→중지가 검증된다.
- 실제 진동기 명세와 안전 상한이 승인되기 전에는 `REAL_DEVICE_ENABLED=false`를 유지한다.
- DB 장애, FITRUS 타임아웃, 중복 요청, 장치 ACK 미수신 시 실패 상태와 감사 로그가 남는다.

## 현재 차단사항

- AWS 서비스(ECS/Lambda)와 데이터베이스가 아직 확정되지 않았다.
- 현재 백엔드는 `D1Database` 바인딩을 사용하므로 그대로 AWS에 실행할 수 없다.
- FITRUS 성공 응답의 공식 스키마와 실제 진동기 통신 명세가 없다.
- 운영 사용자 수, 호출량, 리전, 개인정보 보존기간과 네트워크 정책이 정해지지 않았다.

따라서 이 저장소를 현재 상태에서 “AWS 배포 완료” 또는 “AWS 실행 준비 완료”라고 표시하면 안 된다. 위 항목을 완료한 뒤 Mock 종단간 검증을 통과해야 배포 가능으로 판정한다.
