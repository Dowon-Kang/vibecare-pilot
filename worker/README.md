# VibeCare Worker API

Flutter와 FITRUS·D1·기기 게이트웨이 사이의 보안 경계다. 공개 계약은 `../contracts/openapi.yaml`을 따른다.

## 로컬 검증

```powershell
npm test
npm run typecheck
npx wrangler d1 migrations apply vibecare-dev --local
```

`.dev.vars.example`을 `.dev.vars`로 복사한 뒤 개발 전용 FITRUS 키와 32자 이상의 임의 `AUTH_TOKEN_SECRET`을 등록한다. 실제 비밀값은 Git에 추가하지 않는다.

`DEVICE_MODE=mock`에서는 D1에 Mock 세션과 ACK를 남기지만 실제 장비로 전송하지 않는다. `real` 모드는 공급사 프로토콜이 구현되지 않았으므로 의도적으로 `501 DEVICE_PROTOCOL_NOT_CONFIGURED`를 반환한다.

FITRUS 응답 정규화는 공급사 성공 응답과 단위 계약이 확보될 때까지 `normalized: false`로 남는다. 원본 응답을 임의로 해석하지 않는다.
