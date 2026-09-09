import 'dart:math' as math;

const musclePathwayVersion = 'pilot-0.7.0';
Map<String, dynamic> _object(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
bool _nonempty(Object? value) => value is String && value.trim().isNotEmpty;
bool _positive(Object? value) => value is num && value.isFinite && value > 0;
// Machine precision only; this is not a clinical measurement tolerance.
int _compare(double a, double b) =>
    (a - b).abs() <=
        8 * 2.220446049250313e-16 * math.max(1, math.max(a.abs(), b.abs()))
    ? 0
    : a < b
    ? -1
    : 1;
bool _timestamp(Object? value) =>
    value is String &&
    RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$').hasMatch(value) &&
    DateTime.tryParse(value)?.toUtc().toIso8601String() == value;

/// JSON contract for explicit ASM/SMM research comparisons. Never creates a command.
Map<String, dynamic> calculateMusclePathway(Object? raw) {
  final input = _object(raw),
      profile = _object(_object(raw)['profile']),
      safety = _object(_object(raw)['safety']);
  final rows = input['measurements'] is List
      ? (input['measurements'] as List).map(_object).toList()
      : <Map<String, dynamic>>[];
  Map<String, dynamic> finish(
    String status,
    List<String> codes, [
    Map<String, dynamic>? assessment,
    Map<String, dynamic>? protocol,
  ]) => {
    'algorithmVersion': musclePathwayVersion,
    'realDeviceSendAllowed': false,
    'command': null,
    'evidence': {
      'indexDefinition': 'EVIDENCE',
      'thresholdTransfer': 'INDIRECT',
      'simulationProtocol': 'PILOT',
      'variabilityGate': 'PILOT',
    },
    'personalization': {'status': 'NOT_FITTED', 'appliedFactor': null},
    'status': status,
    'executionStatus': status == 'BLOCKED'
        ? 'BLOCKED'
        : codes.contains('INSUFFICIENT_DATA')
        ? 'INSUFFICIENT_DATA'
        : status == 'REVIEW'
        ? 'REVIEW'
        : 'CALIBRATION_REQUIRED',
    'assessment': assessment,
    'simulationProtocol': protocol,
    'reasonCodes': [
      ...codes,
      'INPUT_DEFINITION_ASSUMED',
      'PILOT_PROTOCOL',
      'SIMULATION_ONLY',
      'CALIBRATION_REQUIRED',
    ],
  };
  const keys = ['acutePain', 'dizziness', 'clinicianHold'];
  if (keys.any((k) => safety[k] == true)) {
    return finish('BLOCKED', ['SAFETY_HOLD']);
  }
  if (rows.length != 4) return finish('REVIEW', ['INSUFFICIENT_DATA']);
  if (keys.any((k) => safety[k] is! bool)) {
    return finish('REVIEW', ['SAFETY_INCOMPLETE']);
  }
  final age = profile['age'], height = profile['heightCm'];
  if (!_nonempty(profile['participantId']) ||
      !['female', 'male'].contains(profile['sex']) ||
      age is! num ||
      !age.isFinite ||
      age != age.round() ||
      age < 18 ||
      age > 100 ||
      !_positive(height) ||
      height < 100 ||
      height > 250) {
    return finish('REVIEW', ['PROFILE_INVALID']);
  }
  final heightM = (height as num).toDouble() / 100,
      heightSquared = heightM * heightM;
  const fields = ['weightKg', 'bmi', 'bodyFatPct', 'fatMassKg'];
  for (final r in rows) {
    final m = _object(r['muscle']);
    if (!_nonempty(r['id']) ||
        !_nonempty(r['deviceId']) ||
        r['qualityPassed'] != true ||
        !_nonempty(r['measuredAt']) ||
        !_timestamp(r['measuredAt']) ||
        fields.any((k) => !_positive(r[k])) ||
        !_positive(m['massKg'])) {
      return finish('REVIEW', ['MEASUREMENT_INVALID']);
    }
    if (r['bodyFatPct'] > 100 ||
        r['fatMassKg'] > r['weightKg'] ||
        m['massKg'] > r['weightKg'] ||
        (r['fatMassKg'] / r['weightKg'] * 100 - r['bodyFatPct']).abs() > 1 ||
        (r['weightKg'] / heightSquared - r['bmi']).abs() > 0.6) {
      return finish('REVIEW', ['MEASUREMENT_INCONSISTENT']);
    }
    if (r['participantId'] != profile['participantId']) {
      return finish('REVIEW', ['PARTICIPANT_MISMATCH']);
    }
  }
  if (rows.map((r) => r['id']).toSet().length != 4) {
    return finish('REVIEW', ['DUPLICATE_MEASUREMENT']);
  }
  if (rows.map((r) => r['deviceId']).toSet().length != 1) {
    return finish('REVIEW', ['DEVICE_MISMATCH']);
  }
  final muscles = rows.map((r) => _object(r['muscle'])).toList();
  if (muscles.any(
    (m) =>
        !['ASM', 'SMM'].contains(m['kind']) || !_nonempty(m['definitionRef']),
  )) {
    return finish('REVIEW', ['MUSCLE_DEFINITION_UNKNOWN']);
  }
  if ([
    'kind',
    'method',
    'definitionRef',
  ].any((k) => muscles.map((m) => m[k]).toSet().length != 1)) {
    return finish('REVIEW', ['MUSCLE_DEFINITION_MIXED']);
  }
  final kind = muscles[0]['kind'], method = muscles[0]['method'];
  if (!['BIA', 'DXA'].contains(method) || (kind == 'SMM' && method != 'BIA')) {
    return finish('REVIEW', ['METHOD_UNSUPPORTED']);
  }
  final female = profile['sex'] == 'female';
  if (age < (kind == 'ASM' ? 50 : 60)) {
    return finish('REVIEW', ['REFERENCE_OUT_OF_SCOPE']);
  }
  final asmCutoffs = age < 65
      ? {
          'BIA': [7.6, 5.7],
          'DXA': [7.2, 5.5],
        }
      : {
          'BIA': [7.0, 5.7],
          'DXA': [7.0, 5.4],
        };
  final double lower = kind == 'ASM'
      ? asmCutoffs[method]![female ? 1 : 0]
      : female
      ? 5.75
      : 8.5;
  final double? upper = kind == 'SMM'
      ? female
            ? 6.75
            : 10.75
      : null;
  String classify(double total, int n) => kind == 'ASM'
      ? _compare(total, lower * heightSquared * n) < 0
            ? 'LOW'
            : 'NOT_LOW'
      : _compare(total, lower * heightSquared * n) <= 0
      ? 'LOW'
      : _compare(total, upper! * heightSquared * n) <= 0
      ? 'MIDDLE'
      : 'REFERENCE';
  final values = muscles.map((m) => (m['massKg'] as num).toDouble()).toList();
  final sum = values.reduce((a, b) => a + b), mean = sum / 4;
  final sd = math.sqrt(
        values.map((b) => (b - mean) * (b - mean)).reduce((a, b) => a + b) / 3,
      ),
      category = classify(sum, 4);
  final assessment = <String, dynamic>{
    'kind': kind,
    'method': method,
    'definitionRef': muscles[0]['definitionRef'],
    'measurementIds': rows.map((r) => r['id']).toList(),
    'measurementTimes': rows.map((r) => r['measuredAt']).toList(),
    'reference': kind == 'ASM' ? 'AWGS_2025_HEIGHT' : 'JANSSEN_2004_TOTAL_BIA',
    'indexName': kind == 'ASM' ? 'ASMI' : 'SMMI',
    'indexKgM2': (mean / heightSquared * 100).round() / 100,
    'meanMassKg': mean,
    'sdKg': sd,
    'cvPct': 100 * sd / mean,
    'minimumKg': values.reduce(math.min),
    'maximumKg': values.reduce(math.max),
    'lowerCutoff': lower,
    'upperCutoff': upper,
    'lowComparison': kind == 'ASM' ? '<' : '<=',
    'category': category,
  };
  final reasons = <String>[];
  if (values.map((v) => classify(v, 1)).toSet().length > 1) {
    reasons.add('MUSCLE_TIER_UNSTABLE');
  }
  if (rows.map((r) => (r['bmi'] as num).toDouble()).reduce((a, b) => a + b) /
          4 <
      18.5) {
    reasons.add('BMI_REVIEW');
  }
  if (reasons.isNotEmpty) return finish('REVIEW', reasons, assessment);
  final protocol = category == 'LOW'
      ? {'id': 'P1', 'durationSec': 180, 'frequencyHz': 12, 'intensityPct': 30}
      : category == 'REFERENCE'
      ? {'id': 'P3', 'durationSec': 300, 'frequencyHz': 20, 'intensityPct': 50}
      : {'id': 'P2', 'durationSec': 240, 'frequencyHz': 16, 'intensityPct': 40};
  return finish('READY', [], assessment, protocol);
}
