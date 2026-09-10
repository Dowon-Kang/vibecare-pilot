# VibeCare 유스케이스와 시스템 설계

## 참여자 유스케이스

```mermaid
flowchart TD
    A[참여자 코드와 6자리 PIN] --> B{인증 성공?}
    B -- 아니오 --> C[오류와 잠금 남은 시간 표시]
    C --> A
    B -- 예 --> D[BIA 최신 4건 불러오기]
    D --> E{동일인·동일기기·유효 4건?}
    E -- 아니오 --> F[REVIEW: 실행 버튼 숨김]
    E -- 예 --> G[평균과 변동성 계산]
    G --> H[오늘 통증·어지럼 확인]
    H --> I{안전 문진 통과?}
    I -- 아니오 --> J[BLOCKED: 추천·전송 차단]
    I -- 예 --> K[근육지수 등급과 Mock preset 표시]
    K --> L{상태가 READY?}
    L -- 아니오 --> F
    L -- 예 --> M[Mock 실행 허가 요청]
    M --> N[로컬 또는 서버 시뮬레이션 시작]
    N --> O[남은 시간·시뮬레이션 상태·중지]
    O --> P[RPE·통증·어지럼 피드백]
```

## 현재 구현된 앱·백엔드 Mock 흐름

`VIBECARE_API_BASE_URL`이 없으면 앱 내부 Mock 저장소와 `MockDeviceGateway`를 사용한다. URL이 있으면 백엔드에 저장된 표준 측정값을 읽고 `BackendDeviceGateway`가 서버 시뮬레이터를 호출한다. 두 경로 모두 실제 진동 장치에는 연결되지 않는다.

```mermaid
sequenceDiagram
    actor User as 참여자
    participant App as Flutter 앱
    participant API as 백엔드 API
    participant DB as 데이터 저장소
    User->>App: 코드+PIN 로그인
    App->>API: 최신 측정세트 요청
    API->>DB: 동일 참여자 최신 유효 4건 조회
    API-->>App: 측정 4건+규칙 버전
    App->>App: 로컬 평균·추천 미리보기
    User->>App: 안전 문진 후 실행 요청
    App->>API: 측정 ID 4개+문진+기기 ID
    API->>DB: 원본 재조회
    API->>API: authoritative 재계산
    alt READY와 DEVICE_MODE=mock
        API->>DB: 1회성 Mock 허가 저장
        API-->>App: mode=mock과 만료시각 반환
        App->>API: Mock 세션 시작 요청
        API->>DB: 시뮬레이션 세션과 합성 ACK 기록
        API-->>App: mode=mock, RUNNING
    else REVIEW/BLOCKED/불일치
        API-->>App: 실행 거부와 사유
    end
```

FITRUS 프록시의 URL·인증 경계는 준비되어 있지만 공급사 성공 응답 계약과 정규화가 미완료다. 실제 REST/BLE 기기 어댑터도 없다. 두 외부 연동은 현재 흐름이 아니라 후속 작업이다.

`pilot-0.7.0`은 연령·성별·체지방 진동량 곱셈 보정을 사용하지 않는다. 성별은 확인된 ASM/SMM 정의별 연구 경계 선택, 체지방은 일관성 검사와 향후 연구 변수에 사용한다.

## 백엔드 경계

```mermaid
flowchart LR
    subgraph External[외부 시스템]
        BIA[BIA 공급사]
        DEVICE[진동 기기]
    end

    subgraph Backend[백엔드 API]
        AUTH[PIN 인증·잠금]
        ADAPTER[BIA 정규화 어댑터]
        ENGINE[pilot-0.7.0 연구용 계산 엔진]
        AUTHORIZE[1회성 Mock 허가]
        SESSION[시뮬레이션 세션·합성 ACK·피드백 API]
    end

    subgraph Storage[SqlDatabase 포트: 현재 D1, AWS adapter 미구현]
        RAW[(BIA 원본)]
        RULES[(버전 규칙)]
        AUDIT[(추천·명령 감사로그)]
    end

    APP[Flutter 참여자 앱] --> AUTH
    BIA -. 계약 확보 후 .-> ADAPTER --> RAW
    APP --> ENGINE
    ENGINE --> RAW
    ENGINE --> RULES
    ENGINE --> AUTHORIZE --> AUDIT
    AUTHORIZE --> APP --> SESSION --> AUDIT
    APP -. 실장비 어댑터 미구현 .-> DEVICE
```

## 안전 상태 머신

```mermaid
stateDiagram-v2
    [*] --> REVIEW: 측정세트 미확정
    REVIEW --> READY: 4건·문진·연구 규칙 검증
    READY --> AUTHORIZED: 1회성 Mock 허가
    AUTHORIZED --> RUNNING: 로컬/서버 시뮬레이션 ACK
    AUTHORIZED --> REVIEW: 허가 만료/불일치
    RUNNING --> STOPPING: 종료·사용자 중지·오류
    STOPPING --> COMPLETED: 중지 ACK
    STOPPING --> FAULT: 중지 ACK 없음
    REVIEW --> BLOCKED: 통증·어지럼·사용보류
    READY --> BLOCKED: 증상 발생
    RUNNING --> BLOCKED: 이상반응
    BLOCKED --> REVIEW: 다음 세션 재평가
```

현재 `DeviceGateway` 구현은 앱 내부 `MockDeviceGateway`와 서버 시뮬레이터를 호출하는 `BackendDeviceGateway`다. 어느 쪽도 물리 장치와 통신하지 않는다. REST/BLE 실장비 구현은 장치 명세·교정표·안전 승인을 확보한 뒤 같은 인터페이스 뒤에 별도 어댑터로 추가한다.

## 상태 어휘와 책임

| 범위 | 대표 상태 | 책임 |
|---|---|---|
| UI 추천 | `SIMULATION_READY`, `REVIEW`, `BLOCKED` | 입력과 안전 문진 결과를 표시한다. 준비 상태도 Mock 시뮬레이션 자격일 뿐이다. |
| 연구 실행 검토 | `CALIBRATION_REQUIRED`, `INSUFFICIENT_DATA` | 물리 실행을 막는 근거·교정·데이터 부족을 기록한다. |
| 장치 세션 | 연결, 허가, 전송, ACK 대기, 실행, 중지, 완료, 오류 | 현재는 Mock 또는 서버 시뮬레이션 수명주기만 관리한다. |

문헌의 `HOLD` 개념은 앱 추천 상태의 `BLOCKED`에 대응하지만 공개 API 상태값으로 혼용하지 않는다.
