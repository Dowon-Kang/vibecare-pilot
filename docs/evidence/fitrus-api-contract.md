# FITRUS API 연결 확인

확인일: 2026-09-06

## 제공된 엔드포인트

| 용도 | URL | 알고리즘 역할 |
|---|---|---|
| 혈압 | `https://api.thefitrus.com/fitrus-ml/measure/bp` | 안전 보조 입력 후보 |
| 심박 | `https://api.thefitrus.com/fitrus-ml/measure/hr` | 안전 보조 입력 후보 |
| 스트레스 | `https://api.thefitrus.com/fitrus-ml/measure/stress` | 상태 참고값 후보 |
| 체표면 온도 | `https://api.thefitrus.com/fitrus-ml/measure/bodytemp` | 안전 보조 입력 후보 |
| 체성분 | `https://api.thefitrus.com/fitrus-ml/measure/bodyfat` | BIA 4회 평균의 주 입력 |
| 스트레스 v2 | `https://api.thefitrus.com/fitrus-ml/measure/stress2` | `stress`와 비교 후 하나만 채택 |

## 직접 확인된 계약

- 여섯 URL 모두 `HEAD` 요청에 `405 Method Not Allowed`, `Allow: POST`를 반환했다.
- 빈 JSON을 API 키 없이 POST하면 `403 Forbidden`과 `x-api-key` 관련 오류를 반환했다.
- 사용자가 제공한 키를 메모리에서만 읽어 `/bodyfat`에 전송하자 인증을 통과해 `400 Bad Request / Failed to read request`가 반환되었다. 키 값은 로그·문서·프로젝트에 복사하지 않았다.
- 오류 응답 타입은 `application/problem+json`이다.
- 따라서 키는 Flutter 앱이나 저장소에 두지 않고 Workers 비밀값 `FITRUS_API_KEY`로만 주입한다.
- 일반적인 `/v3/api-docs`와 `/swagger-ui` 경로에서는 공개 스키마를 확인할 수 없었다.

## 아직 공급사에서 받아야 하는 항목

- 각 API의 요청 JSON 또는 바이너리 포맷과 필수 필드
- 성공 응답 JSON 예시와 단위
- `x-api-key` 발급·회전·허용 도메인/IP 정책
- 타임아웃, 호출 제한, 재시도 가능 오류코드
- `stress`와 `stress2`의 차이 및 권장 버전
- bodyfat 결과의 측정 ID, 사용자/기기 ID, 측정시각, 품질 플래그
- 개인정보 처리·보관·제3자 제공에 대한 계약 범위

요청/응답 예시는 실사용자 정보와 API 키를 제거한 형태로 저장한다. 명세가 확보되기 전에는 공급사 응답을 추측해 표준 BIA DTO로 변환하거나 실제 진동 실행에 사용하지 않는다.

## 키 보관 조치

현재 `E:\산학협력\산학협력api.txt`는 평문 키 파일이므로 개발 확인용으로만 취급한다. 운영 환경에서는 Workers/Sites의 암호화된 환경 비밀값 `FITRUS_API_KEY`로 등록하고, 등록·검증 후 평문 파일은 사용자 승인 아래 제거한다. 키를 Flutter 빌드, API 응답, 로그, Git, 문서에 포함하지 않는다.
