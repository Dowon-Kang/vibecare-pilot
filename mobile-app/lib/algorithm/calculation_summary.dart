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
      title: '1. 부위별 기준값',
      detail:
          '${setting.durationSec ~/ 60}분 · ${setting.frequencyHz}Hz · 출력 ${setting.baseIntensityPct}%에서 시작합니다.',
    ),
    (
      title: '2. 독립 보정계수',
      detail:
          '성별 ×${factors.genderCoefficient.toStringAsFixed(2)}, 연령 ×${factors.ageCoefficient.toStringAsFixed(2)}, 체지방 ×${factors.bodyFatCoefficient.toStringAsFixed(2)}, 근육량 ×${factors.muscleMassCoefficient.toStringAsFixed(2)}입니다.',
    ),
    (
      title: '3. 곱셈 결합',
      detail:
          '${setting.baseIntensityPct}% × ${factors.totalCoefficient.toStringAsFixed(4)} = ${factors.calculatedIntensityPct.toStringAsFixed(2)}%입니다. 감소를 단순 합산하지 않아 중복 조건에서도 비례적으로 줄어듭니다.',
    ),
    (
      title: '4. 제한과 반올림',
      detail:
          'Config의 허용 범위로 제한하고 반올림하여 자동 출력 ${setting.intensityPct}%를 표시합니다.',
    ),
    (
      title: '5. 최종 선택',
      detail:
          '자동 ${setting.intensityPct}% → 선택 ${selectedIntensityPct ?? setting.intensityPct}%. 모든 계수는 검증 전 프로토타입 가설이며 실제 기기 처방이 아닙니다.',
    ),
  ];
}
