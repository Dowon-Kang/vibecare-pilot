# 문서 안내

문서의 계획과 실제 실행 코드를 구분합니다. 구현 상태는 코드와 테스트 결과를 우선합니다.

1. [프로젝트 개요](project-overview.md): 목적, 사용자 흐름, 책임과 구현 상태
2. [아키텍처](architecture.md): 앱·백엔드·외부 시스템 데이터 흐름
3. [제품·디자인 규약](../design.md): Mock 표시, 상태 문구, 접근성 기준
4. [알고리즘 설계 검토](algorithm/pilot-0.6.0-design-review.md): 현재 구현의 기준 문서—수식, 근거 수준과 한계
5. [ASM/SMM 해석](algorithm/asm-smm-pathways.md): 현재 UI 선택과 계산 경로를 설명하는 짧은 사용 안내
6. [상세 안전 명세](algorithm/evidence-based-wbv-algorithm-spec.md): 향후 실장비 승격을 위한 목표 명세와 의사결정 기록
7. [근육량·진동 문헌 검토](evidence/muscle-driven-vibration-review-2026-09-09.md): 기준 문서의 근거가 된 조사 이력—논문과 오픈소스 검토
8. [FITRUS 계약 확인](evidence/fitrus-api-contract.md): 확인된 내용과 아직 필요한 공급사 정보
9. [개발도구 검증 기록](evidence/toolchain-status.md): 과거 로컬 빌드 이력과 최신 CI 판정 기준
10. [AWS 인계](../deployment/aws/README.md): 다음 배포 담당자의 작업 범위
11. [구현 계획](../plan.md): 현재 범위와 후속 단계
12. [체크리스트](../checklist.md): 완료, 부분 완료, 차단 상태
13. [실제 진동기 연동 준비도](device-integration-readiness.md): 현재 시뮬레이터 경계와 실장비 전 필수 명세·시험 조건

`pilot-0.6.0`은 연구용 시뮬레이션입니다. 테스트 통과는 코드 재현성을 뜻하며 임상 효과나 실장비 안전을 증명하지 않습니다.
