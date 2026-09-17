# Fitrus ML Measurement API 상세 개발 가이드

이 문서는 Fitrus ML의 `/measure` API를 연동하는 개발자를 위한 요청·응답 및 오류 처리 규격을 설명한다.

## 1. 공통 사양

### 1.1 기본 경로

애플리케이션의 servlet context path는 `/fitrus-ml`이다.

```text
{BASE_URL}/fitrus-ml/measure/...
```

예를 들어 혈압 측정 API의 전체 경로는 다음과 같다.

```text
POST {BASE_URL}/fitrus-ml/measure/bp
```

이 문서의 엔드포인트 표기는 servlet context path를 제외한 `/measure/...` 형식을 사용한다.

### 1.2 공통 요청 헤더

| 이름 | 위치 | 형식 | 필수 | 설명 |
|---|---|---|---|---|
| `x-api-key` | Header | string | 필수 | 외부 인증 서버에서 검증하는 API 키 |
| `Content-Type` | Header | `application/json` | 권장 | 요청 본문에 사용을 권장하는 미디어 타입. 호환되는 JSON 미디어 타입도 처리될 수 있음 |
| `Accept` | Header | `application/json` | 권장 | 성공 응답은 JSON, 정의된 예외 응답은 `application/problem+json` |

`x-api-key`가 없거나 유효하지 않으면 `403 Forbidden`을 반환한다. 인증 처리 중 장애가 발생하면 `500 Internal Server Error`가 반환될 수 있다.

### 1.3 PPG `list` 형식

`/bp`, `/hr`, `/stress`, `/stress2`는 정수 배열인 `list`를 받는다. 서버는 배열을 인덱스의 `mod 6` 값에 따라 다음과 같이 세 채널로 분리한다.

| 채널 | 원본 배열 인덱스 |
|---|---|
| red | `0, 3, 6, 9, ...` |
| green | `1, 4, 7, 10, ...` |
| ir | `2, 5, 8, 11, ...` |

API는 배열의 최소/최대 길이와 각 값의 범위를 사전에 검증하지 않는다. 따라서 필요한 샘플 수와 값 범위는 연동하는 측정 장치 및 ML 서비스의 규격을 따라야 하며, 부적절한 데이터는 `500 Internal Server Error`로 이어질 수 있다.

이 문서에 사용한 6개 원소의 PPG 배열은 JSON 구조와 채널 배치만 보여 주는 축약 예시이다. 실제 ML 호출에 유효한 샘플 길이를 의미하지 않는다. 단위나 유효 범위가 별도로 정의되지 않은 숫자 예시는 응답 형태를 설명하기 위한 값일 뿐, 유효한 측정값을 보장하지 않는다.

### 1.4 필수 필드 전송 주의사항

요청 표에서 필수로 표시한 필드는 모두 명시적으로 전송해야 한다. `baseSystolic`, `baseDiastolic`, `age`, `height`, `weight`, `voltage`, `temp`를 누락하거나 `null`로 보내면 `0` 또는 `0.0`으로 처리될 수 있으므로 이 동작에 의존하면 안 된다. `list`와 `gender`를 누락하거나 `null`로 보내면 `400 Bad Request`를 반환한다.

### 1.5 성공 및 오류 응답 개요

| HTTP 코드 | 발생 조건 | 응답 형식 |
|---|---|---|
| `200 OK` | 인증 및 측정·저장 성공 | 엔드포인트별 JSON |
| `400 Bad Request` | JSON 문법 오류, 본문 누락, `list`/`gender` 누락 또는 null, 변환할 수 없는 타입, 지원하지 않는 `gender` 값 등 | `ProblemDetail` |
| `403 Forbidden` | `x-api-key` 누락 또는 유효하지 않은 API 키 | `ProblemDetail` |
| `405 Method Not Allowed` | 해당 경로에 지원하지 않는 HTTP 메서드 사용 | `ProblemDetail` |
| `406 Not Acceptable` | 지원하지 않는 `Accept` 값 전송 | `ProblemDetail` 또는 본문 없음 |
| `415 Unsupported Media Type` | 지원하지 않는 `Content-Type` 전송 | `ProblemDetail` |
| `500 Internal Server Error` | 인증 처리 장애, 측정 실패, 결과 저장 실패 또는 처리 중 오류 | 혈압 측정 실패는 `ProblemDetail`; 그 밖의 오류 본문 형식은 보장되지 않음 |

오류 응답은 일반적으로 `ProblemDetail` JSON을 사용한다.

```json
{
  "type": "about:blank",
  "title": "Forbidden",
  "status": 403,
  "detail": "오류 상세 메시지",
  "instance": "/fitrus-ml/measure/bp"
}
```

`detail`은 오류 상황에 따라 달라지므로 클라이언트 로직에서 고정 문자열로 비교하면 안 된다. 일부 `406` 및 `500` 응답은 본문이 없거나 `ProblemDetail` 형식이 아닐 수 있으므로 본문 파싱 실패에 대비해야 한다. 인증은 다른 요청 처리보다 먼저 수행되므로 요청에 따라서는 프로토콜 오류보다 인증 오류가 먼저 반환될 수 있다.

## 2. 엔드포인트 요약

| 기능 | 메서드 | 엔드포인트 | 요청 본문 | 성공 응답 |
|---|---|---|---|---|
| 혈압 측정 | `POST` | `/measure/bp` | JSON 객체 | 혈압 측정 결과 |
| 체지방 측정 | `POST` | `/measure/bodyfat` | JSON 객체 | 체성분 측정 결과 |
| 심박 측정 | `POST` | `/measure/hr` | JSON 객체 | 심박 측정 결과 |
| 스트레스 측정 | `POST` | `/measure/stress` | JSON 객체 | 스트레스 측정 결과 |
| 체온 저장 | `POST` | `/measure/bodytemp` | JSON 객체 | 입력한 체온 값 |
| 스트레스 확장 측정 | `POST` | `/measure/stress2` | JSON 객체 | 스트레스 확장 측정 결과 |

모든 엔드포인트에는 path parameter와 query parameter가 없다.

## 3. 혈압 측정

### `POST /measure/bp`

PPG 데이터와 기준 수축기·이완기 혈압을 사용해 혈압을 예측하고 결과를 저장한다.

#### 요청 본문

| 필드 | JSON 형식 | 필수 | 제약 및 설명 |
|---|---|---|---|
| `list` | integer array | 필수 | 인터리브된 PPG 측정값 |
| `baseSystolic` | number (double) | 필수 | 기준 수축기 혈압 |
| `baseDiastolic` | number (double) | 필수 | 기준 이완기 혈압 |

```json
{
  "list": [101, 201, 301, 102, 202, 302],
  "baseSystolic": 120.0,
  "baseDiastolic": 80.0
}
```

#### `200 OK` 응답

| 필드 | JSON 형식 | 설명 |
|---|---|---|
| `dbp` | number (double) | 예측 이완기 혈압 |
| `sbp` | number (double) | 예측 수축기 혈압 |

```json
{
  "dbp": 78.4,
  "sbp": 119.7
}
```

#### 엔드포인트별 예외

- 혈압 측정 또는 결과 저장에 실패하면 `500 Internal Server Error`를 반환한다.
- 혈압 측정 실패 응답은 `ProblemDetail` 형식이며 `detail`에 실패 원인이 포함된다.

## 4. 체지방 측정

### `POST /measure/bodyfat`

신체 정보와 전류 측정값을 사용해 체성분을 계산하고 결과를 저장한다.

#### 요청 본문

| 필드 | JSON 형식 | 필수 | 제약 및 설명 |
|---|---|---|---|
| `age` | integer (int32) | 필수 | 나이 |
| `height` | number (float) | 필수 | 신장 |
| `weight` | number (float) | 필수 | 체중 |
| `gender` | string | 필수 | `male` 또는 `female`, 대소문자 구분 없음. 누락/null은 400 |
| `voltage` | number (double) | 필수 | Fitrus BLE 장치의 전류 측정값 |
| `correct` | number (float) 또는 `null` | 선택 | 보정 백분율. 누락/`null`이면 `0` |

```json
{
  "age": 48,
  "height": 169.7,
  "weight": 68.6,
  "gender": "male",
  "voltage": 1.1296023,
  "correct": 0.0
}
```

#### `200 OK` 응답

| 필드 | JSON 형식 | Nullable | 설명 |
|---|---|---|---|
| `bfp` | number (float) | 예 | 체지방률 |
| `bfm` | number (float) | 예 | 체지방량 |
| `bmr` | number (float) | 예 | 기초대사량 |
| `smm` | number (float) | 예 | 골격근량 |
| `icw` | number (float) | 예 | 세포내수분 |
| `ecw` | number (float) | 예 | 세포외수분 |
| `protein` | number (float) | 예 | 단백질량 |
| `mineral` | number (float) | 예 | 무기질량 |
| `bodyAge` | integer (int32) | 예 | 신체 나이 |
| `createdAt` | string (date-time) | 아니요 | 결과 생성 시각 |

```json
{
  "bfp": 20.4,
  "bfm": 14.0,
  "bmr": 1542.7,
  "smm": 29.8,
  "icw": 24.1,
  "ecw": 14.7,
  "protein": 10.3,
  "mineral": 3.5,
  "bodyAge": 45,
  "createdAt": "2026-09-14T05:30:00.000+00:00"
}
```

#### 엔드포인트별 예외

- `gender`가 `male`/`female` 이외의 값이면 역직렬화에 실패하여 `400 Bad Request`이다.
- 체성분 측정 또는 결과 저장에 실패하면 `500 Internal Server Error`를 반환한다. 오류 본문 형식은 보장되지 않는다.

## 5. 심박 측정

### `POST /measure/hr`

PPG 데이터로 심박수, 심박변이도 및 산소포화도를 계산하고 결과를 저장한다.

#### 요청 본문

| 필드 | JSON 형식 | 필수 | 제약 및 설명 |
|---|---|---|---|
| `list` | integer array | 필수 | 인터리브된 PPG 측정값 |

```json
{
  "list": [101, 201, 301, 102, 202, 302]
}
```

#### `200 OK` 응답

| 필드 | JSON 형식 | 설명 |
|---|---|---|
| `hr` | number (double) | 심박수 |
| `hrv` | number (double) | 심박변이도 |
| `spo2` | number (double) | 산소포화도 |

```json
{
  "hr": 72.0,
  "hrv": 41.3,
  "spo2": 98.0
}
```

#### 엔드포인트별 예외

- 심박 측정 또는 결과 저장에 실패하면 `500 Internal Server Error`를 반환한다. 오류 본문 형식은 보장되지 않는다.

## 6. 스트레스 측정

### `POST /measure/stress`

PPG 데이터로 심박 관련 값을 구한 뒤 나이를 함께 사용해 스트레스 값과 등급을 계산한다.

#### 요청 본문

| 필드 | JSON 형식 | 필수 | 제약 및 설명 |
|---|---|---|---|
| `list` | integer array | 필수 | 인터리브된 PPG 측정값 |
| `age` | integer (int32) | 필수 | 나이 |

```json
{
  "list": [101, 201, 301, 102, 202, 302],
  "age": 48
}
```

#### `200 OK` 응답

| 필드 | JSON 형식 | 설명 |
|---|---|---|
| `hr` | integer (int32) | 심박수. ML의 실수 결과를 정수로 변환한 값 |
| `hrv` | integer (int32) | 심박변이도. ML의 실수 결과를 정수로 변환한 값 |
| `spo2` | integer (int32) | 산소포화도. ML의 실수 결과를 정수로 변환한 값 |
| `value` | integer (int32) | 스트레스 수치 |
| `level` | string | 스트레스 등급: `LOW`, `MID`, `HIGH` |

```json
{
  "hr": 72,
  "hrv": 41,
  "spo2": 98,
  "value": 35,
  "level": "MID"
}
```

#### 엔드포인트별 예외

- 스트레스 측정 또는 결과 저장에 실패하면 `500 Internal Server Error`를 반환한다. 오류 본문 형식은 보장되지 않는다.

## 7. 체온 저장

### `POST /measure/bodytemp`

전달받은 체온을 저장하고 입력 본문을 그대로 반환한다. 별도의 ML 예측은 수행하지 않는다.

#### 요청 본문

| 필드 | JSON 형식 | 필수 | 제약 및 설명 |
|---|---|---|---|
| `temp` | number (float) | 필수 | 저장할 체온 값 |

```json
{
  "temp": 36.6
}
```

#### `200 OK` 응답

```json
{
  "temp": 36.6
}
```

#### 엔드포인트별 예외

- 체온 저장에 실패하면 `500 Internal Server Error`를 반환한다. 오류 본문 형식은 보장되지 않는다.

## 8. 스트레스 확장 측정

### `POST /measure/stress2`

PPG 데이터로 기본 심박 지표와 시간·주파수 영역의 스트레스 관련 확장 지표를 계산하고 저장한다.

#### 요청 본문

| 필드 | JSON 형식 | 필수 | 제약 및 설명 |
|---|---|---|---|
| `list` | integer array | 필수 | 인터리브된 PPG 측정값 |

```json
{
  "list": [101, 201, 301, 102, 202, 302]
}
```

#### `200 OK` 응답

응답 JSON 필드명은 아래와 같이 소문자 또는 snake_case를 사용한다.

| 필드 | JSON 형식 | 설명 |
|---|---|---|
| `hr` | integer (int32) | 심박수 |
| `hrv` | integer (int32) | 심박변이도 |
| `sdnn` | integer (int32) | NN 간격의 표준편차 |
| `rmssd` | integer (int32) | 연속 NN 간격 차이의 제곱평균제곱근 |
| `sd1` | integer (int32) | Poincaré plot 단기 변동 지표 |
| `sd2` | integer (int32) | Poincaré plot 장기 변동 지표 |
| `pnn50` | integer (int32) | 50ms 이상 차이 나는 NN 간격의 비율 관련 지표 |
| `spo2` | integer (int32) | 산소포화도 |
| `errorcode` | integer (int32) | 하위 측정 모델 오류 코드 |
| `min_hr` | number (double) | 최소 심박수 |
| `max_hr` | number (double) | 최대 심박수 |
| `lf_power` | number (double) | 저주파 파워 |
| `hf_power` | number (double) | 고주파 파워 |
| `lf_hf_ratio` | number (double) | LF/HF 비율 |
| `sri` | number (double) | 스트레스 관련 지표 |
| `fatigue_index` | number (double) | 피로도 지표 |
| `health_index` | number (double) | 건강 지표 |

```json
{
  "hr": 72,
  "hrv": 41,
  "sdnn": 38,
  "rmssd": 31,
  "sd1": 22,
  "sd2": 49,
  "pnn50": 18,
  "spo2": 98,
  "errorcode": 0,
  "min_hr": 64.0,
  "max_hr": 83.0,
  "lf_power": 425.2,
  "hf_power": 318.7,
  "lf_hf_ratio": 1.33,
  "sri": 27.5,
  "fatigue_index": 21.0,
  "health_index": 78.0
}
```

#### 엔드포인트별 예외

- 스트레스 확장 측정 또는 결과 저장에 실패하면 `500 Internal Server Error`를 반환한다. 오류 본문 형식은 보장되지 않는다.
- `errorcode`는 HTTP 상태 코드와 별개의 측정 모델 상태 값이며, 값이 `0`이 아니어도 HTTP 응답은 `200 OK`일 수 있다.

## 9. 클라이언트 구현 시 주의사항

1. 모든 요청에 `x-api-key`를 포함하고 요청 본문에는 `Content-Type: application/json`을 사용한다.
2. 오류 판정은 HTTP 상태 코드로 수행하고, 가변적인 `detail` 문자열에 의존하지 않는다.
3. PPG 배열의 유효 길이·샘플 범위는 연동 장치 및 ML 규격에 맞춰야 한다.
4. `/measure/stress2` 응답 필드는 소문자 및 snake_case 이름을 사용한다.
5. 일부 `500` 응답은 `ProblemDetail` 형식이 아닐 수 있으므로 오류 본문 파싱 실패에도 대비한다.
6. 숫자형 요청 필드를 누락하거나 `null`로 보내면 0으로 처리될 수 있으므로 모든 필수 값을 명시한다.
