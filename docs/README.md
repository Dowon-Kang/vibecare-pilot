# 문서 안내

문서의 계획과 실제 실행 코드를 구분합니다. 구현 상태는 코드와 테스트 결과를 우선합니다.

1. [프로젝트 개요](project-overview.md): 목적, 사용자 흐름, 책임과 구현 상태
2. [아키텍처](architecture.md): 앱·백엔드·외부 시스템 데이터 흐름
3. [제품·디자인 규약](../design.md): Mock 표시, 상태 문구, 접근성 기준
4. [알고리즘 설계 검토](algorithm/pilot-0.6.0-design-review.md): 수식, 근거 수준과 한계
5. [ASM/SMM 해석](algorithm/asm-smm-pathways.md): 하나의 공급사 필드를 두 기준으로 비교하는 이유
6. [상세 안전 명세](algorithm/evidence-based-wbv-algorithm-spec.md): 향후 실장비 승격을 포함한 입력·안전 요구사항
7. [근육량·진동 문헌 검토](evidence/muscle-driven-vibration-review-2026-09-09.md): 논문과 오픈소스 조사 결과
8. [FITRUS 계약 확인](evidence/fitrus-api-contract.md): 확인된 내용과 아직 필요한 공급사 정보
9. [개발도구 검증 기록](evidence/toolchain-status.md): 특정 시점의 로컬 빌드 증거와 재현 주의사항
10. [AWS 인계](../deployment/aws/README.md): 다음 배포 담당자의 작업 범위
11. [구현 계획](../plan.md): 현재 범위와 후속 단계
12. [체크리스트](../checklist.md): 완료, 부분 완료, 차단 상태

`pilot-0.6.0`은 연구용 시뮬레이션입니다. 테스트 통과는 코드 재현성을 뜻하며 임상 효과나 실장비 안전을 증명하지 않습니다.
