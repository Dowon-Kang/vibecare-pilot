# 외부 블루투스 측정 앱 연동 가이드

VibeCare 측정 수신 v1. 외부 앱/SDK/기기는 아직 선정되지 않았다. BLE 연결·장치 명령·FITRUS ML 호출은 외부 앱이나 해당 앱의 서버가 담당한다. 아래 수신 API, JSON Schema, TypeScript 전송 어댑터는 외부 앱을 정한 뒤 연결하는 경계다. 실제 기기 연동 완료나 기기 데이터의 진위 인증을 뜻하지 않는다.

## 흐름

1. 외부 앱이 **같은 VibeCare Supabase 프로젝트의 본인 계정**으로 인증한다. 별도 앱의 자체 로그인 토큰은 사용할 수 없다. 브라우저 로그인 세션이 다른 앱으로 자동 공유되는 구조가 아니다. 네이티브 앱을 선정하면 공식 Supabase Auth/PKCE와 리디렉션 허용 목록을 정한다.
2. BLE 측정 **시작 시점**의 로그인 사용자 ID를 외부 앱 내부에 고정한다. 완료 전에 로그아웃/계정 변경이 생기면 해당 결과를 다른 사용자로 보내지 않는다.
3. 외부 앱이 기기/공급사 응답을 아래 kg/% 값으로 정규화하고 이벤트마다 UUID를 한 번 발급한다. 재시도할 때 UUID와 payload를 그대로 재사용한다.
4. 본인 access token을 Authorization 헤더로 전송한다. 서버가 본인 참여자 연결과 활성 출처 등록을 확인해 원본 envelope·정규 기록·영수증을 원자적으로 저장한다.
5. 저장 성공 시 VibeCare 홈/측정 기록/식사·운동 안내는 활성 화면에서 최대 30초 이내 또는 앱 복귀 때 갱신된다. 동일 조건의 비교 가능 기록이 있으면 자동 후보가 바뀔 수 있다. 첫 기록에는 기본 조합이 표시되며 실제 운동 전 상태 확인은 유지한다.

## 호출 규격

운영 프로젝트 base URL: `https://jaekmjiupbsufxaevosf.supabase.co`

`POST /rest/v1/rpc/submit_external_measurement`

헤더: `apikey: <프로젝트 publishable key>`, `Authorization: Bearer <본인 access token>`, `Content-Type: application/json`.
`service_role`, DB 비밀번호, FITRUS 키는 외부 앱·브라우저에 넣지 않는다. 비밀번호/토큰을 URL·딥링크·QR·로그에 넣지 않는다. 원시 PPG/voltage와 개인정보는 이 API로 보내지 않는다.

본문의 최상위 키는 `p_payload` 하나다. 그 안은 [JSON Schema](../shared-contracts/external-measurement.schema.json)와 [OpenAPI](../shared-contracts/external-measurement.openapi.yaml)를 따른다.

| 필드 | 의미 |
|---|---|
| schemaVersion | 정수 1 |
| eventId | 측정 시작 때 생성한 UUID. 재전송 시 유지 |
| sourceId | 서버에 등록한 앱/장치/정의/프로토콜 버전 식별자. 비밀키가 아님 |
| deviceId | 앱이 부여한 불투명한 장치 ID. 이메일·이름·BLE MAC 주소 사용 금지 |
| measuredAt | 실제 측정 완료 시각, timezone 포함 ISO8601. 30일 이내/미래5분 이내 |
| values.weightKg | 실제 입력/측정 체중 kg. 체지방량/비율에서 역산해 대체하지 않음 |
| values.bodyFatPct | 체지방률 % |
| values.fatMassKg | 체지방량 kg |
| values.muscleKg | 공급사 정의/단위 확인된 전신 SMM kg. ASM/기타 지표 대체 금지 |

`userId`, `participantId`, 이메일, qualityPassed, 근육 정의/방법 근거를 본문으로 받지 않는다. BMI는 서버에 연결된 참여자 키에서 계산한다. 출처 근거는 관리자가 등록한 값만 사용한다. 체지방량과 체지방률의 차이는1%p 이내, 근육+지방량은 체중+0.5kg 이내여야 한다. 이는 입력 일관성 검사이며 임상 정상 범위 판정이 아니다. 허용된 미래 시각도 시간이 도달하기 전에는 기존 안내의 미래 측정 보류 규칙을 따른다.

성공 응답: `{ "measurementId": "EXT-…", "duplicate": false, "status": "stored" }`. 동일 계정+eventId+동일 envelope는 같은 ID와 `duplicate:true`를 반환한다. JSON 키 순서는 무관하지만 값/시각 문자열을 변경하면 충돌이다. 기존 영수증 재확인은 출처가 비활성화되거나 한도에 도달해도 가능하다.

| HTTP / message | 외부 앱의 처리 |
|---|---|
| 400 / INVALID_PAYLOAD, INVALID_MEASUREMENT_VALUES, INVALID_MEASUREMENT_TIME | 형식·단위·실제 측정 시각 확인. 임의 값으로 채우지 않음 |
| 401·403 / AUTH_REQUIRED 또는 JWT 권한 오류 | 본인 인증 재확인. 다른 계정으로 재전송 금지 |
| 409 / ACCOUNT_LINK_REQUIRED, ACCOUNT_LINK_AMBIGUOUS | 담당자가 본인 참여자 연결을 정확히 한 개로 확인 |
| 409 / PROFILE_REVIEW_REQUIRED | 연결된 프로필의 키 확인 |
| 409 / EVENT_CONFLICT | eventId를 다른 측정에 재사용하지 않았는지 확인 |
| 429 / UPLOAD_LIMIT | 계정당 최근1분10건/UTC일100건. 자동 즉시 재시도 금지 |
| 503 / SOURCE_NOT_READY | 앱/기기 출처 등록·활성화 필요 |
| 네트워크 실패·시간 초과·취소 | 저장됐을 수도 있음. 같은 계정·같은 eventId/payload로 명시적 재시도 |

## TypeScript 연결 예제

[전송 어댑터](../shared-contracts/external-measurement-client.ts)는 인증 SDK와 BLE 구현에 의존하지 않는다. Java/Kotlin/Swift/Flutter도 같은 HTTPS 계약을 사용할 수 있다.

```ts
const upload = createMeasurementUploader({
  supabaseUrl: 'https://jaekmjiupbsufxaevosf.supabase.co',
  publishableKey: config.vibecarePublishableKey,
  getSession: async () => {
    const { data, error } = await supabase.auth.getSession();
    if (error) throw error;
    return data.session ? {
      ownerId: data.session.user.id,
      accessToken: data.session.access_token,
    } : null;
  },
});
// 아래 값은 실제 BLE 시작/완료 콜백에서 준비한다. 예제값을 운영에 전송하지 않는다.
const ownerAtStart = currentSession.user.id;
const eventId = crypto.randomUUID();
// await BLE 측정 및 공급사 계산 (외부 앱이 구현)
await upload(ownerAtStart, {
  schemaVersion: 1, eventId,
  sourceId: config.registeredSourceId,
  deviceId: device.opaqueId,
  measuredAt: completedMeasurement.measuredAt,
  values: completedMeasurement.values,
});
```

어댑터는 송신 전과 응답 후 현재 사용자 ID를 확인한다. 계정 변경 후 응답은 로컬 화면에 적용하지 않는다. 이미 서버에 저장된 이전 계정의 측정을 취소/삭제한다는 뜻은 아니다. 로컬 재전송 큐도 측정 시작 사용자별로 나누고 토큰은 큐와 분리해 OS 보안 저장소/공식 SDK로 관리한다. 자동 재시도는 내장하지 않는다.

## 운영 등록 — 앱 선정 후 한 번

- 관리자가 기존 참여자와 Auth 계정을 정확히1:1로 연결하고 실제 프로필의 키를 확인한다. 이 API는 타인의 기존 참여자를 선택·연결하거나 참여자 프로필을 임의 생성하지 않는다.
- `vibecare.external_measurement_sources`에 앱/장치 버전별 sourceId와 SMM/kg 정의 근거, 측정법 근거, 획득 프로토콜, 검토 근거를 등록한다. 처음은 enabled=false로 두고 검토 후에만 활성화한다. 마이그레이션에는 운영 출처/실제 사용자/측정을 넣지 않는다.
- 이 등록은 클라이언트 테이블 쓰기 API가 아니다. 외부 앱에 관리자 키를 전달하지 않는다. 출처 ID만으로 기기 진위가 입증되지 않으며 추후 선정 앱에 서명/기기 attestation이 필요하면 별도 계약으로 추가한다.
- 합성 테스트는 분리된 시험 DB에서 한다. 운영 DB에 합성 사용자를 넣거나 실제 사용자 기록처럼 예제값을 등록하지 않는다.

## 검증과 현재 범위

인증/소유권, 익명/미연결/다중연결/공유 참여자 거부, idempotency, 입력 일관성, 출처 차단, quota, transaction rollback, 본인 조회까지 CI의 disposable PostgreSQL로 확인한다. TypeScript 어댑터는 합성 fetch 응답으로 계정 변경/취소/오류를 검증한다. 실제 외부 앱·BLE·FITRUS 응답·실제 두 계정 종단간 검증은 앱 선정 후 수행한다. 실시간 AI 생성/무료 Gemini 전송/실제 진동 출력은 포함하지 않는다.

권한 설계: 정규 측정 테이블에 client INSERT를 주지 않기 위해 `submit_external_measurement`만 제한된 security definer로 실행한다. auth.uid()/auth.users 확인, 서버 소유 대상·출처, 고정 빈 search_path, 익명 EXECUTE 회수와 strict 입력 검사로 경계를 제한한다. 새 private registry/receipt는 RLS를 켜고 client 직접 권한을 모두 회수한다. 기존 본인 읽기 RLS는 변경하지 않는다. [Supabase database functions](https://supabase.com/docs/guides/database/functions), [PostgREST custom errors](https://docs.postgrest.org/en/stable/references/errors.html#custom-errors)를 확인했다.


운영 준비 확인(2026-10-17): `20261017091402_external_measurement_intake` 적용 완료. 익명 HTTP 요청은401/42501로 차단됐고 authenticated EXECUTE만 허용된다. 활성 출처0/수신 영수증0/운영 측정0이며 실제 측정이나 합성 fixture는 운영에 넣지 않았다. 새 registry/receipt의 RLS 무정책은 직접 접근을 막기 위한 의도된 deny-all이다. authenticated definer 실행 advisory는 위의 제한된 쓰기 경계로 검토했으며 일반 INSERT 권한은 주지 않았다. [RLS 무정책 안내](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [definer 권한 안내](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). 기존 trigger search_path/Auth 설정/AI quota 경고는 이번 범위에서 바꾸지 않았다.
