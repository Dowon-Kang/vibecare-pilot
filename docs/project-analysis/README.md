# VibeCare 인수 분석 문서

> 이 폴더는 개선 전 인수 분석 기록입니다. 승인 후 반영한 내용과 최신 검증 결과는 [품질 개선 기록](../QUALITY_UPGRADE.md)을 보세요.

분석일: 2026-09-07 (Asia/Seoul). 대상: `E:\산학협력\vibration-control-app`. 애플리케이션 소스·설정·기존 테스트는 수정하지 않았다. 이 폴더에 분석 문서와 격리 재현 스크립트만 추가했다. 웹 빌드와 Flutter 테스트는 생성 디렉터리를 갱신할 수 있다.

## 읽는 순서

| 순서 | 문서 | 역할 |
|---|---|---|
| 1 | [00_EXECUTIVE_SUMMARY.md](00_EXECUTIVE_SUMMARY.md) | 현재 완성도, 위험, 우선순위 |
| 2 | [01_PROJECT_BRIEF.md](01_PROJECT_BRIEF.md) | 목적, 사용자, 범위와 성공 기준 |
| 3 | [02_REQUIREMENTS.md](02_REQUIREMENTS.md) | FR 요구사항, 사용자 흐름, 수용 기준 |
| 4 | [03_ARCHITECTURE.md](03_ARCHITECTURE.md) | 실제 시스템·계층·기술 선택 |
| 5 | [04_COMPONENT_RESPONSIBILITIES.md](04_COMPONENT_RESPONSIBILITIES.md) | 파일별 책임과 의존성 |
| 6 | [05_CONTRACTS.md](05_CONTRACTS.md) | 전체 HTTP·DB·내부 연결 계약 |
| 7 | [06_AI_AND_DATA.md](06_AI_AND_DATA.md) | 규칙 알고리즘, 데이터와 평가 범위 |
| 8 | [07_CONSTRAINTS_AND_SECURITY.md](07_CONSTRAINTS_AND_SECURITY.md) | 성능·안정성·보안·외부 연동 |
| 9 | [08_VERIFICATION.md](08_VERIFICATION.md) | 실행 결과, 추적표, 재현 가능한 문제 목록 |
| 10 | [09_DECISIONS_AND_QUESTIONS.md](09_DECISIONS_AND_QUESTIONS.md) | 결정 기록, 가정, 제약과 질문 |
| 11 | [10_TASKS_AND_ROADMAP.md](10_TASKS_AND_ROADMAP.md) | 개선 작업, 완료 조건, 운영 명령 |

## 사실과 추론의 구분

- **[사실] 확인된 사실**: 조사한 소스·설정·테스트·이번 실행 결과에 근거한다. 기존 문서의 진술을 확인한 경우에는 “기존 문서 기록”이라고 명시한다.
- **[추론] 코드에 근거한 추론**: 구조로부터 예상되는 영향·개선안이며 실제 운영 검증 결과가 아니다.
- **[확인 필요]**: 담당자의 승인, 공급사 명세, 배포 환경 또는 실기기 검증이 필요하다.
- FR은 기존 요구 문서를 바탕으로 복원한 식별자다. 고객이 새로 승인한 요구사항이 아니다. 개선 수용 기준은 제안임을 구분한다.
- 파일 경로는 별도 표시가 없으면 위 저장소 루트 기준이다. 함수·클래스 이름을 근거로 함께 표시한다. 기존 문서의 미래형 다이어그램을 구현 사실로 간주하지 않는다.

## 조사 범위와 한계

[사실] `git ls-files`로 추적 파일 전체를 목록화하고 앱·Worker·Flutter 소스, 계약, 마이그레이션, 설정, 기존 문서, 테스트를 조사했다. `.git` 이력은 두 커밋의 제목과 현재 기준점을 확인했다. `node_modules`, 빌드 바이너리, `.wrangler` 내부 데이터, 기존 `output/`, `tmp/`, `apps/mobile/.android/`, `.tmp/`는 소스 구현으로 집계하지 않았다. 해당 미추적 폴더는 작업 시작 전부터 존재했다. 의존성은 선언·잠금 파일·설치 목록·실행 가능 여부 중심으로 확인했고 모든 전이 패키지 소스를 보안 감사하지는 않았다.

[사실] 상위 작업 폴더는 Git 루트가 아니다. 별도 `vibration-design-report`는 React 기반 연구·설계 보고서 산출물이다. 그 폴더의 `AGENTS.md`, 패키지·파일 목록, 보고서 본문·데이터를 보조 맥락으로 확인했다. VibeCare 앱이 해당 보고서 런타임을 import하거나 호출하는 경로는 찾지 못했다. 보고서의 모든 공유 런타임을 이번 앱 인수 분석의 별도 제품으로 감사하지는 않았다.

[사실] 상위 폴더의 일부 LibreOffice 임시 디렉터리는 검색 시 접근 거부였다. 주 저장소 추적 소스 조사에는 지장이 없었다. 상위 논문·HWP·PDF 전체를 재해석하거나 의료적 타당성을 새로 검증한 작업이 아니다. 평문 키 파일은 기존 문서의 보관 위치 진술과 파일 존재만 확인했고 값은 열람·복사·출력하지 않았다. 운영 API·운영 D1·물리 장비는 호출하지 않았다.

## 재현 자료

- [evidence/probe-worker.mjs](evidence/probe-worker.mjs): 실제 Hono 핸들러와 메모리 SQLite를 연결하는 분석 전용 검사. D1 형태의 어댑터이며 실제 D1 통합 시험과 구분한다. 합성 참여자·임시 키만 사용하고 DB를 파일로 저장하지 않는다.
- [evidence/probe-workerd.mjs](evidence/probe-workerd.mjs): 설치된 Worker용 Miniflare/workerd에서 120,000회 PBKDF2 지원 여부 검사.
- [evidence/probe-contracts.py](evidence/probe-contracts.py): JSON Schema 문법·공통 fixture와 API 형태 응답의 계약 불일치 확인.
- [evidence/results.json](evidence/results.json): 이번 도구 출력에서 옮긴 주요 관측값. 원본 애플리케이션 테스트나 생산 준비 완료 인증서가 아니다.
- [evidence/source-inventory.json](evidence/source-inventory.json): 추적 파일 경로·크기·SHA-256 기준점. 분석 후 코드 불변 확인용.

수정 담당자는 먼저 문제 ID와 FR을 선택하고 별도 변경에서 회귀 테스트를 추가해야 한다. 재현 스크립트 일부 assertion은 **현재의 잘못된 동작을 확인**한다. 그것이 통과한다고 요구사항을 충족하는 것은 아니다.
