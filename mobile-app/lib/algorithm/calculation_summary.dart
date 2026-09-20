import '../models/models.dart';

List<({String title, String detail})> calculationSummary({
  required AlgorithmResult result,
  required ParticipantProfile profile,
  required int? selectedIntensityPct,
}) {
  if (result.status == RecommendationStatus.blocked) {
    return [(title: '사용 보류', detail: '통증·어지럼 또는 전문가 보류 상태이므로 설정을 만들지 않습니다.')];
  }
  final factors = result.factors;
  final setting = result.recommendation;
  if (factors == null || setting == null || result.measurementIds.length != 4) {
    return [(title: '측정값 확인 필요', detail: '같은 사람·기기의 유효한 SMM 측정 4건이 필요합니다.')];
  }
  return [
    (
      title: '1. 교수님 확정 기준값',
      detail:
          '${setting.durationSec ~/ 60}분 · ${setting.frequencyHz}Hz · 출력 ${setting.baseIntensityPct}%에서 시작합니다.',
    ),
    (
      title: '2. 체지방 등급',
      detail: '최신 API 체지방률을 ${factors.bodyFatBand} 등급으로 분류했습니다.',
    ),
    (
      title: '3. 고정 매핑 적용',
      detail: '등급과 선택 부위에 정해진 시간·Hz·강도를 추가 보정 없이 적용합니다.',
    ),
    (
      title: '4. 추천 설정',
      detail:
          '${setting.durationSec ~/ 60}분 · ${setting.frequencyHz}Hz · 강도 ${setting.intensityPct}%입니다.',
    ),
    (
      title: '5. 최종 선택',
      detail:
          '기준 ${setting.intensityPct}% → 선택 ${selectedIntensityPct ?? setting.intensityPct}%. 연구용 시뮬레이션 값이며 실제 기기 처방이 아닙니다.',
    ),
  ];
}
