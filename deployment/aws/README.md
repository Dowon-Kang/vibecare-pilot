# AWS 배포 인수 조건

이 폴더는 AWS 리소스를 생성하거나 배포하지 않는다. 다음 담당자가 기존 API 계약과 안전 규칙을 보존하면서 AWS 런타임을 선택하고 구현할 수 있도록 필요한 경계만 정의한다.

배포 대상은 `mobile-app/`이 호출하는 `backend-api/`다. 웹 비교판과 Sites 설정은 저장소 단순화를 위해 제거했다.

## 그대로 재사용하는 부분

- `../../backend-api/src/`: 인증, FITRUS 프록시, 추천 재계산, 실행 허가와 세션 흐름
- `../../shared-contracts/openapi.yaml`: Flutter와 백엔드 사이의 HTTP 계약
- `../../backend-api/migrations/`: 현재 데이터 구조를 이해하기 위한 SQL 기준선
- `GET /health`: 로드밸런서와 배포 확인용 상태 경로
- `DEVICE_MODE=mock`, `REAL_DEVICE_ENABLED=false`: 실제 장비 명세가 확정되기 전의 안전 기본값

## AWS 담당자가 반드시 구현할 부분

1. 실행 방식을 결정한다. 장시간 연결과 향후 장치 통신을 고려하면 기본 후보는 `ECS Fargate + ALB`이며, 호출량이 매우 적고 요청 단위 처리만 필요하면 `Lambda + API Gateway`를 비교한다.
2. `backend-api/src/app-context.ts`의 `SqlDatabase` 포트에 AWS 데이터베이스 어댑터를 연결한다. 포트 분리는 완료됐지만 구현체는 D1뿐이며 운영 기본 후보인 RDS PostgreSQL 어댑터는 아직 없다. 현재 D1/SQLite SQL을 그대로 운영 SQL이라고 가정하지 않는다.
3. 선택한 런타임에 맞는 HTTP 어댑터와 종료 처리를 추가한다. `createApp()`은 Web Fetch 형식의 Hono 앱 팩토리이므로 도메인·Route 코드를 복제하지 않는다.
4. `required-environment.example`의 비밀값을 코드·이미지·로그에 넣지 않고 Secrets Manager 또는 SSM Parameter Store에서 주입한다.
5. ECR 이미지 스캔, CloudWatch 로그·경보, HTTPS, CORS 허용 출처, 최소 권한 IAM, 개발/운영 환경 분리를 구성한다.
6. D1에서 AWS DB로 이동할 경우 데이터 변환·백업·롤백 절차를 작성한다. 아래의 `런타임·저장소 계약`을 충족하는 통합 테스트를 배포 전에 추가한다.

## 런타임·저장소 계약

- HTTP: `createApp()`이 반환하는 Fetch 앱을 Lambda/API Gateway 또는 Node 컨테이너 어댑터가 감싼다. 런타임 전용 코드는 별도 진입점에 두고 Route에 AWS SDK를 주입하지 않는다.
- DB: `SqlDatabase` 포트는 파라미터 바인딩과 `first/all/run/batch` 형태의 경계를 정의할 뿐 PostgreSQL 호환성을 보장하지 않는다. AWS 어댑터는 이 계약을 구현하고 `batch` 전체 성공 또는 전체 롤백의 원자성을 보장해야 한다. 현재 migration과 Route SQL의 `ON CONFLICT`, `MIN/MAX`, `?` placeholder, SQLite 날짜·BOOLEAN 표현은 PostgreSQL 문법과 타입으로 아직 이식되지 않았다.
- 상태 확인: `/health`는 프로세스 생존 확인, `/ready`는 설정과 DB 쿼리 확인이다. ALB/ECS는 `/ready`를 readiness 대상으로 사용하되 재시작 판단은 플랫폼 정책과 함께 검토한다.
- 요청 추적: 신뢰 가능한 `X-Request-Id`를 전달하거나 서버 생성값을 사용한다. JSON 로그에는 요청 ID·경로·상태·처리시간만 남기며 토큰, PIN, FITRUS 원문은 남기지 않는다.
- CORS: `ALLOWED_ORIGINS`의 쉼표 구분 allowlist만 허용한다. 모바일 네이티브 호출은 CORS 대상이 아니지만 브라우저 클라이언트가 생길 경우 와일드카드를 사용하지 않는다.

### 선택지별 최소 어댑터

| 선택 | 추가할 경계 | 적합 조건 | 아직 필요한 결정 |
|---|---|---|---|
| Lambda + API Gateway | Hono Lambda handler, DB 연결/프록시 어댑터 | 낮은 호출량, 짧은 요청 | 콜드스타트, RDS Proxy, 요청 제한 |
| ECS Fargate + ALB | Node HTTP server, SIGTERM graceful shutdown | 장시간 연결·지속 프로세스 | 태스크 크기, 오토스케일, 드레이닝 |

둘 중 하나가 확정되기 전에는 양쪽 IaC를 동시에 추가하지 않는다. AWS 담당자가 리전·네트워크·DB·트래픽 요구사항을 승인한 후 최소 스택 하나만 구현한다.

## 배포 전 완료 기준

- `GET /health`가 ALB/API Gateway를 통해 200을 반환하고 `GET /ready`가 DB 장애 시 503을 반환한다.
- `backend-api` 테스트와 타입검사가 통과한다.
- `shared-contracts/openapi.yaml`과 실제 요청·응답이 일치한다.
- 인증 갱신, 장치 세션 생성·이벤트·중지, 불편감 피드백을 포함한 현행 OpenAPI request body와 오류 응답을 배포 어댑터 통합 테스트로 검증한다.
- API 키와 토큰 비밀값이 Git, 컨테이너 이미지, Flutter APK, 로그에 존재하지 않는다.
- `DEVICE_MODE=mock`에서 로그인→측정 조회→추천 허가→세션 시작→중지가 검증된다.
- 실제 진동기 명세와 안전 상한이 승인되기 전에는 `REAL_DEVICE_ENABLED=false`를 유지한다.
- DB 장애, FITRUS 타임아웃, 중복 요청, 장치 ACK 미수신 시 실패 상태와 감사 로그가 남는다.

## 현재 차단사항

- AWS 서비스(ECS/Lambda)와 데이터베이스가 아직 확정되지 않았다.
- 애플리케이션은 `SqlDatabase` 포트로 분리됐지만 AWS DB 어댑터와 D1/SQLite SQL의 PostgreSQL 이식이 없으므로 그대로 AWS에 실행할 수 없다.
- FITRUS 성공 응답의 공식 스키마와 실제 진동기 통신 명세가 없다.
- 운영 사용자 수, 호출량, 리전, 개인정보 보존기간과 네트워크 정책이 정해지지 않았다.

따라서 이 저장소를 현재 상태에서 “AWS 배포 완료” 또는 “AWS 실행 준비 완료”라고 표시하면 안 된다. 위 항목을 완료한 뒤 Mock 종단간 검증을 통과해야 배포 가능으로 판정한다.
