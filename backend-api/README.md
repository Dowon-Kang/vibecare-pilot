# VibeCare 백엔드 API

Flutter와 FITRUS·데이터베이스·기기 게이트웨이 사이의 보안 경계다. 공개 계약은 `../shared-contracts/openapi.yaml`을 따른다.

현재 요청 처리 코드는 Cloudflare Workers/D1에서 로컬 검증하는 프로토타입이다. 앱은 `createApp()`과 `SqlDatabase` 포트로 런타임 경계를 분리했지만 AWS HTTP·DB 어댑터는 아직 없다. AWS 담당자는 `../deployment/aws/README.md`의 인수 조건을 따라야 하며, 기존 설정을 AWS 운영 구성으로 오해하지 않는다.

`GET /health`는 프로세스 생존만, `GET /ready`는 안전 설정과 DB 연결 준비 상태를 확인한다. 모든 응답에는 `X-Request-Id`가 포함되고 요청 메타데이터는 JSON 한 줄 로그로 기록된다. PIN·토큰·요청 본문·FITRUS 원문은 로그에 남기지 않는다.

## 로컬 검증

```powershell
npm test
npm run typecheck
npx wrangler d1 migrations apply vibecare-dev --local --config local-runtime.jsonc
```

`.dev.vars.example`을 `.dev.vars`로 복사한 뒤 개발 전용 FITRUS 키와 32자 이상의 임의 `AUTH_TOKEN_SECRET`을 등록한다. 실제 비밀값은 Git에 추가하지 않는다.

`DEVICE_MODE=mock`에서는 D1에 Mock 세션과 ACK를 남기지만 실제 장비로 전송하지 않는다. `real` 모드는 공급사 프로토콜이 구현되지 않았으므로 의도적으로 `501 DEVICE_PROTOCOL_NOT_CONFIGURED`를 반환한다.

FITRUS 응답 정규화는 공급사 성공 응답과 단위 계약이 확보될 때까지 `normalized: false`로 남는다. 원본 응답을 임의로 해석하지 않는다.
