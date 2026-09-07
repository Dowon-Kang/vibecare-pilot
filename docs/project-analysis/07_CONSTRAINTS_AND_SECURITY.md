# 비기능 요구사항·보안·외부 시스템

## 성능·확장성

| 항목 | 확인된 사실 | 코드에 근거한 추론 / 확인 필요 |
|---|---|---|
| 예상 인원·동시요청 | 목표 수치 없음 | [확인 필요] 파일럿 규모·1인 빈도·동시기기수 |
| 로컬 계산 |4건×5/12항목의 작은 배열 계산 | [추론] 서버I/O보다 병목 가능성 작음. 측정된 latency는 없음 |
| 조회 | 이력20·vitals50 제한, participant 시간 인덱스 | [추론] device 필터가 늘면 복합인덱스 필요. limit의 정합성 오류 I-08 우선 |
| 인증 | PIN당 PBKDF2 120,000회, 실패5회 잠금 | [확인 필요] Worker CPU시간·동시 공격 시 부하. 이번 workerd 연산 지원은 통과 |
| snapshot | 세 API Future.wait 병렬 | [추론] 지연 최댓값에 지배되고 하나 오류면 전체 실패 |
| 저장량 | authorize·events·raw 누적, 정리작업 없음 | [추론] 반복 허가/무제한 payload가 저장량·비용 증가 |
| 캐시 | 웹 Service Worker network-first GET 캐시 | [사실] Flutter 측정/규칙 영속캐시·Worker cache 없음 |
| 대량 처리 | 배치 ingest·페이지네이션·집계 백그라운드 작업 없음 | [확인 필요] 장기 연구 규모·retention에 따른 설계 |

## 안정성

- [사실] Dio는 connectTimeout10초만 설정. 외부 FITRUS fetch에는 라우트가 AbortSignal을 전달하지 않으며 명시적 재시도도 없다. 서버 오류는 주로500으로 통합된다.
- [사실] D1 batch는 측정세트/추천 또는 세션/허가/이벤트 묶음에 사용된다. 허가 검증 SELECT가 트랜잭션보다 앞에 있고 race 시 UNIQUE 오류를 안정적인409로 매핑하는 코드가 없다. DB unique(authorization_id)는 같은 허가 중복 저장을 제한하므로 “같은 허가로 무조건 두 세션 생성”이라고 단정하지 않는다.
- [사실] 서버에 기기별 활성 세션 제한, heartbeat, 예약 종료 작업이 없다. COMPLETED 이벤트는 상태를 갱신하지 않는다.
- [사실] 앱 중지 실패는 타이머 취소→gateway error→UI isRunning false 흐름이다. session은 남지만 중지 CTA는 사라진다(I-05). 로그아웃은 stop 실패 뒤에도 토큰/로컬상태를 지울 수 있다.
- [사실] 앱 생명주기 paused/detached에서 중지를 요청한다. OS 강제종료·통신 불능에서 물리 정지를 보장하는 watchdog은 없다.
- [사실] Mock 모드는 완전 로컬이지만 서버 모드의 offline 동작은 일반 오류 표시이며 자동 Mock 대체는 없다. 웹 캐시의 HTML fallback은 JS/JSON 요청에도 적용될 수 있다.

## 보안 평가

이 평가는 저장소 코드와 격리 재현에 근거한 소프트웨어 분석이다. 법률 준수나 운영환경 침투검사 완료 판정이 아니다.

| 영역 | 구현 사실 | 위험·한계 |
|---|---|---|
| 인증 | 6자리PIN·salted PBKDF2·15분 access·30일 refresh | participant 발급·회전·폐기 절차 없음; 전역/IP rate limit 없음 |
| 계정 잠금 |5회 실패15분; 성공시 reset | read-update 방식 동시요청 검증 부족; 존재계정만 잠금되는 차이 |
| 토큰 검증 | HMAC·종류·만료·sub | issuer/audience 없음, claims 전체 스키마 없음; refresh_version은 access 검사 시 확인 안 함 |
| 인가 | 본인 BIA/vitals·ownedSession join | 멱등 세션 조회가 participant 범위를 누락(I-01, Critical) |
| 장치 권한 | 허가에 participant/device 결합 | 장비 registry/소유권·교정 DB 없음; BIA/진동기 ID 혼용 |
| 보안 저장 | 서버모드 secure storage | 자동 refresh/세션복원 없음, 로그아웃 서버 revoke 없음 |
| 전송 | FITRUS 기본URL HTTPS | VIBECARE_API_BASE_URL 임의문자열, HTTPS 강제검사 없음; 실제 TLS 배포 미확인 |
| secret | FITRUS_API_KEY·AUTH_TOKEN_SECRET, .dev.vars ignore | 상위 평문 키 보관은 기존 문서에 명시. 이번 값 미열람·미전송; 운영 회전 확인 필요 |
| 입력 | Zod 일부 타입/길이/숫자 범위, SQL bind | raw payload 크기·필드 allowlist 없음; participantCode/deviceId 길이상한 없음 |
| SQL injection | ID 목록도 placeholder, 값 bind | 검토한 라우트에 직접 사용자문자열 SQL 결합 없음. 이것만으로 전체 보안 인증 아님 |
| 웹 XSS/CSRF | React 텍스트·로컬 JSON 표시, 업무 인증은 Bearer | 검토한 app에 rawHTML 삽입 없음; CSP·CORS 구성은 별도 없음. 쿠키기반 인증 경로 아님 |
| 개인정보 | D1에 가명·신체값·문진 관련 경고·반응·raw JSON | 동의·보관기간·삭제·정정·운영 권한·백업 정책 미정 |
| 로그 | 이름/메시지만 console.error, command_events payload | PIN/key를 직접 로그하는 코드 없음; 자유 payload/error message 민감정보 가능성을 별도 통제해야 함 |
| 의존성 | lockfile와 설치 트리 있음 | 취약점 DB 조회·SBOM·전이 라이선스 감사 미실행, “취약점 없음” 판정 불가 |
| 릴리스 | 내부 release도 debug signing | 운영 서명·환경분리·배포 자동검증 미완성 |

## 환경 제약

- [사실] 웹 Node>=22.13, 이번 Node22.19.0. Flutter SDK 요구 Dart>=3.10<4.0. Android min24, compile/target Flutter SDK 의존. Java17 target. 이 PC에는 E:\flutter-sdk와 기존 E:\vibecare-pilot junction이 있다.
- [사실] 기존 toolchain-status는 C: 공간·한글 경로 제약을 기록한다. 이번 Flutter 분석/시험은 기존 영문 junction과 TEMP/TMP=E:\codex-flutter-temp에서 성공했다. 현재 디스크 여유 수치를 새로 측정하지 않았다.
- [사실] 주요 Flutter 버튼58dp, 본문 일부15/17px이며 design.md의 본문17px 일괄 기준과 완전히 같지 않다. 320×568 위젯은 통과했지만200% 글자·TalkBack·물리 터치 시험은 이번 미수행이다.
- [확인 필요] 최소 브라우저 버전, iOS 지원, 네트워크 오프라인 허용, 기기 CPU/RAM, FITRUS rate limit, Worker 요금제, 사용자 수, 일정·인력·예산.

## 저장소 밖 시스템 목록

| 외부 시스템 | 사용 목적 | 접근 방식 | 인증 정보(값 제외) | 호출 위치 | 장애 영향 | 로컬 대체 |
|---|---|---|---|---|---|---|
| FITRUS 측정 API | 공급사 체성분/생체 측정 | HTTPS POST6종 | FITRUS_API_KEY, Worker secret/.dev.vars 예정 | FitrusClient.measure | 원본 저장 실패;정규화는 원래 미구현 | MockFitrusRepository·fetch test double |
| Cloudflare Workers | 업무API 실행 | Flutter HTTPS JSON | access token; 운영 CLI 계정 별도 | Dio / wrangler | 서버모드 로그인·허가·중지 실패 | Mock 또는 Miniflare |
| Cloudflare D1 | 참여자·측정·감사저장 | env.DB binding | 플랫폼 binding, DB ID placeholder | index.ts SQL | DB routes500;health는200 가능 | 로컬D1, 이번 SQLite 어댑터 |
| Sites/Cloudflare 웹호스팅 | 웹 비교 화면 배포 | vite Sites/plugin | 기존 project_id, 호스팅 권한은 환경 관리 | vite.config.ts / hosting.json | 웹 접근/배포 영향;앱 API와 별개 | npm run dev/build |
| Google Fonts 계열 | Geist 폰트 선언 | next/font/google 호환 처리 | 없음 | app/layout.tsx, Vinext 빌드 | 폰트/빌드 환경 영향 가능 | 로컬/시스템 폰트 후보, 현재 미변경 |
| npm registry | JS 도구·패키지 설치 | npm install/ci | 공개 패키지; 사설설정 미조사 | package-lock.json | 깨끗한 환경 설치 영향 | 기존 node_modules/cache |
| pub.dev / Flutter SDK 배포 | Dart 패키지·도구 | Flutter/pub | 별도 제품키 없음 | pubspec.lock | 설치/빌드 영향 | 기존 SDK/pub cache |
| Google Maven/Maven Central/Gradle | Android 빌드 | Gradle repositories | 없음(확인된 구성) | settings.gradle.kts/wrapper | APK 빌드 영향 | 기존 Gradle cache |
| Android OS/secure storage | Activity·토큰 보관 | 플랫폼 plugin | OS 앱 저장영역 | main/manifest/auth_repository | 저장·lifecycle 실패 | MemorySessionStore·widget tester |
| 실제 REST/BLE 진동기 | 물리 출력 목표 | 미정 | 미정 | 구현 없음 | 전체 실출력 미완성 | MockDeviceGateway/Worker mock |
| 논문·GitHub 근거 링크 | 기술·연구 설명 | 문서 링크 | 없음 | docs/open-source-and-evidence.md | 런타임 영향 없음 | 저장된 문서 설명, 새 검증과 구분 |

[사실] 업무용 이메일·Slack·Notion·Drive·OpenAI AI API 연동은 주 저장소 코드에서 확인하지 못했다. 별도 설계보고서의 범용 런타임 기능을 VibeCare 제품 연동으로 세지 않았다.
