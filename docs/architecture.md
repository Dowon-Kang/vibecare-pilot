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
    I -- 예 --> K[추천과 PILOT 보정 사유 표시]
    K --> L{상태가 READY?}
    L -- 아니오 --> F
    L -- 예 --> M[서버 실행 허가 요청]
    M --> N[기기 연결과 실행]
    N --> O[남은 시간·연결·즉시중지]
    O --> P[RPE·통증·어지럼 피드백]
```

## 앱·백엔드·기기 흐름

```mermaid
sequenceDiagram
    actor User as 참여자
    participant App as Flutter 앱
    participant API as Workers API
    participant DB as D1
    participant BIA as BIA 공급 API
    participant Dev as REST/BLE 기기

    App->>API: 측정 종류와 공급사 입력 전달
    API->>BIA: 서버 전용 API 키로 POST
    BIA-->>API: 공급사 원본 응답
    API->>API: 계약 확보 후 DTO 정규화·중복검사
    API->>DB: 원본과 표준값 저장
    User->>App: 코드+PIN 로그인
    App->>API: 최신 측정세트 요청
    API->>DB: 동일 참여자 최신 유효 4건 조회
    API-->>App: 측정 4건+규칙 버전
    App->>App: 로컬 평균·추천 미리보기
    User->>App: 안전 문진 후 실행 요청
    App->>API: 측정 ID 4개+문진+기기 ID
    API->>DB: 원본 재조회
    API->>API: authoritative 재계산
    alt READY와 교정된 기기
        API->>DB: 1회성 허가 저장
        API-->>App: 만료시각이 있는 실행 허가
        App->>Dev: 허가 결합 명령
        Dev-->>App: ACK와 상태
        App->>API: 세션 이벤트 기록
    else REVIEW/BLOCKED/불일치
        API-->>App: 실행 거부와 사유
    end
```

## 백엔드 경계

```mermaid
flowchart LR
    subgraph External[외부 시스템]
        BIA[BIA 공급사]
        DEVICE[진동 기기]
    end

    subgraph Worker[Cloudflare Workers]
        AUTH[PIN 인증·잠금]
        ADAPTER[BIA 정규화 어댑터]
        ENGINE[pilot-0.3.0 안전 엔진]
        AUTHORIZE[1회성 실행 허가]
        SESSION[세션·ACK·피드백 API]
    end

    subgraph Storage[D1]
        RAW[(BIA 원본)]
        RULES[(버전 규칙)]
        AUDIT[(추천·명령 감사로그)]
    end

    APP[Flutter 참여자 앱] --> AUTH
    BIA --> ADAPTER --> RAW
    APP --> ENGINE
    ENGINE --> RAW
    ENGINE --> RULES
    ENGINE --> AUTHORIZE --> AUDIT
    AUTHORIZE --> APP --> DEVICE
    DEVICE --> SESSION --> AUDIT
```

## 안전 상태 머신

```mermaid
stateDiagram-v2
    [*] --> REVIEW: 측정세트 미확정
    REVIEW --> READY: 4건·문진·교정 검증
    READY --> AUTHORIZED: 서버 1회성 허가
    AUTHORIZED --> RUNNING: 기기 ACK
    AUTHORIZED --> REVIEW: 허가 만료/불일치
    RUNNING --> STOPPING: 종료·사용자 중지·오류
    STOPPING --> COMPLETED: 중지 ACK
    STOPPING --> FAULT: 중지 ACK 없음
    REVIEW --> BLOCKED: 통증·어지럼·사용보류
    READY --> BLOCKED: 증상 발생
    RUNNING --> BLOCKED: 이상반응
    BLOCKED --> REVIEW: 다음 세션 재평가
```

실제 장비 명세 전에는 `MockDeviceGateway`만 선택된다. REST/BLE 구현은 공통 `DeviceGateway` 경계 뒤에 두므로 화면과 알고리즘을 다시 만들지 않고 공급사 어댑터만 교체할 수 있다.
