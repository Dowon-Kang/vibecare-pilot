# VibeCare 백엔드 API

Flutter와 FITRUS·데이터베이스·기기 게이트웨이 사이의 보안 경계다. 공개 계약은 `../shared-contracts/openapi.yaml`을 따른다.

현재 요청 처리 코드는 Cloudflare Workers/D1에서 로컬 검증하는 프로토타입이다. 앱은 `createApp()`과 `SqlDatabase` 포트로 런타임 경계를 분리했지만 AWS HTTP·DB 어댑터는 아직 없다. AWS 담당자는 `../deployment/aws/README.md`의 인수 조건을 따라야 하며, 기존 설정을 AWS 운영 구성으로 오해하지 않는다.

`GET /health`는 프로세스 생존만, `GET /ready`는 안전 설정과 DB 연결 준비 상태를 확인한다. 모든 응답에는 `X-Request-Id`가 포함되고 요청 메타데이터는 JSON 한 줄 로그로 기록된다. PIN·토큰·요청 본문·FITRUS 원문은 로그에 남기지 않는다.

## 로컬 실행과 검증

Node.js와 npm이 준비된 PowerShell에서 이 폴더로 이동한 뒤 잠금 파일 그대로 의존성을 설치한다.

```powershell
cd backend-api
npm ci
Copy-Item .dev.vars.example .dev.vars
```

`.dev.vars`에는 개발 전용 FITRUS 키와 32자 이상의 임의 `AUTH_TOKEN_SECRET`을 넣는다. 예제 파일의 대체 문자열이나 실제 운영 비밀값을 커밋하지 않는다. FITRUS 호출을 검증하지 않는 경우에도 인증 서버를 실행하려면 유효한 길이의 개발용 `AUTH_TOKEN_SECRET`이 필요하다.

로컬 D1 스키마를 먼저 적용한다.

```powershell
npx wrangler d1 migrations apply vibecare-dev --local --config local-runtime.jsonc
```

현재 저장소에는 참여자·PIN 개발 seed가 없다. 따라서 migration만 적용한 새 DB에서는 `/health`와 `/ready`를 확인할 수 있지만 PIN 로그인부터 시작하는 백엔드 종단간 흐름은 자동 재현할 수 없다. 기존 데이터베이스나 승인된 별도 테스트 데이터가 없는 상태에서 문서가 임의 계정을 약속해서는 안 된다.

서버를 실행한다.

```powershell
npm run dev
```

Wrangler가 출력한 로컬 주소를 기준으로 `GET /health`는 프로세스 생존, `GET /ready`는 설정과 DB 준비 상태를 확인한다. 기본 Wrangler 포트를 사용하는 경우 예시는 `http://localhost:8787/health`와 `http://localhost:8787/ready`다. 포트가 출력값과 다르면 출력된 주소를 사용한다.

Android 에뮬레이터의 `localhost`는 개발 PC가 아니라 에뮬레이터 자신을 가리킨다. 기본 포트가 8787이라면 Flutter 앱의 백엔드 주소는 `http://10.0.2.2:8787`로 설정한다. 실제 Android 기기에서는 개발 PC의 동일 네트워크 IP와 방화벽 설정이 별도로 필요하다.

공개 HTTP 계약은 [`../shared-contracts/openapi.yaml`](../shared-contracts/openapi.yaml)에서 확인한다.

코드 변경 후 다음 검증을 실행한다.

```powershell
npm test
npm run typecheck
```

`DEVICE_MODE=mock`에서는 D1에 Mock 세션과 ACK를 남기지만 실제 장비로 전송하지 않는다. `real` 모드는 공급사 프로토콜이 구현되지 않았으므로 의도적으로 `501 DEVICE_PROTOCOL_NOT_CONFIGURED`를 반환한다.

FITRUS 응답 정규화는 공급사 성공 응답과 단위 계약이 확보될 때까지 `normalized: false`로 남는다. 원본 응답을 임의로 해석하지 않는다.
