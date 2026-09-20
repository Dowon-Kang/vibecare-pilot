import 'package:dio/dio.dart';

import '../models/models.dart';
import '../algorithm/vibration_algorithm.dart';

abstract interface class FitrusRepository {
  Future<MeasurementSnapshot> loadSnapshot({
    required ParticipantProfile participant,
    required String deviceId,
  });
}

class MockFitrusRepository implements FitrusRepository {
  @override
  Future<MeasurementSnapshot> loadSnapshot({
    required ParticipantProfile participant,
    required String deviceId,
  }) async {
    final base = DateTime.utc(2026, 8, 22, 23, 20);
    final history = <BiaMeasurement>[
      _body(
        'M-005',
        participant.id,
        deviceId,
        base.add(const Duration(minutes: 4)),
        42.0,
        18.7,
        18.8,
        7.9,
        18.1,
        1106.1,
        59.7,
        6.7,
        2.4,
        0.38,
        61.8,
        8.5,
      ),
      _body(
        'M-004',
        participant.id,
        deviceId,
        base.add(const Duration(minutes: 3)),
        42.2,
        18.8,
        18.7,
        7.9,
        18.0,
        1108.0,
        59.5,
        6.8,
        2.4,
        0.38,
        61.6,
        8.4,
      ),
      _body(
        'M-003',
        participant.id,
        deviceId,
        base.add(const Duration(minutes: 2)),
        41.9,
        18.6,
        19.1,
        8.0,
        18.2,
        1104.0,
        59.9,
        6.6,
        2.5,
        0.39,
        61.9,
        8.6,
      ),
      _body(
        'M-002',
        participant.id,
        deviceId,
        base.add(const Duration(minutes: 1)),
        42.1,
        18.7,
        18.9,
        8.0,
        18.1,
        1107.0,
        59.6,
        6.7,
        2.4,
        0.38,
        61.7,
        8.5,
      ),
      _body(
        'M-001',
        participant.id,
        deviceId,
        base,
        41.8,
        18.6,
        18.5,
        7.7,
        18.0,
        1102.0,
        59.8,
        6.6,
        2.4,
        0.38,
        61.5,
        8.3,
      ),
    ];
    final selected = selectLatestValidMeasurements(
      participantId: participant.id,
      deviceId: deviceId,
      candidates: history,
    );
    final vitals = <VitalMeasurement>[
      VitalMeasurement(
        id: 'BP-001',
        kind: VitalKind.bloodPressure,
        measuredAt: base.add(const Duration(minutes: 5)),
        values: const {'sbp': 118, 'dbp': 76},
        units: const {'sbp': 'mmHg', 'dbp': 'mmHg'},
      ),
      VitalMeasurement(
        id: 'HR-001',
        kind: VitalKind.heartRate,
        measuredAt: base.add(const Duration(minutes: 6)),
        values: const {'hr': 68, 'hrv': 41, 'spo2': 98},
        units: const {'hr': 'bpm', 'hrv': '', 'spo2': '%'},
      ),
      VitalMeasurement(
        id: 'STRESS-001',
        kind: VitalKind.stress,
        measuredAt: base.add(const Duration(minutes: 7)),
        values: const {'hr': 68, 'hrv': 41, 'spo2': 98, 'value': 32},
        units: const {'hr': 'bpm', 'hrv': '', 'spo2': '%', 'value': '점'},
        level: 'LOW',
      ),
      VitalMeasurement(
        id: 'STRESS2-001',
        kind: VitalKind.stressV2,
        measuredAt: base.add(const Duration(minutes: 7)),
        values: const {
          'hr': 68,
          'hrv': 41,
          'sdnn': 38,
          'rmssd': 31,
          'sd1': 22,
          'sd2': 49,
          'pnn50': 18,
          'spo2': 98,
          'errorcode': 0,
          'min_hr': 64,
          'max_hr': 83,
          'lf_power': 425.2,
          'hf_power': 318.7,
          'lf_hf_ratio': 1.33,
          'sri': 27.5,
          'fatigue_index': 21,
          'health_index': 78,
        },
        units: const {'hr': 'bpm', 'spo2': '%'},
      ),
      VitalMeasurement(
        id: 'TEMP-001',
        kind: VitalKind.bodyTemperature,
        measuredAt: base.add(const Duration(minutes: 8)),
        values: const {'temp': 36.5},
        units: const {'temp': '°C'},
      ),
    ];
    return MeasurementSnapshot(
      bodyCompositionHistory: history,
      selectedMeasurements: selected,
      vitals: vitals,
      syncedAt: DateTime.now(),
      ruleSet: pilotRuleSet,
    );
  }
}

/// Consumes VibeCare's canonical backend API contract. It never calls FITRUS or
/// carries the FITRUS API key in the mobile app.
class BackendFitrusRepository implements FitrusRepository {
  BackendFitrusRepository(this._dio);

  final Dio _dio;

  @override
  Future<MeasurementSnapshot> loadSnapshot({
    required ParticipantProfile participant,
    required String deviceId,
  }) async {
    final responses = await Future.wait([
      _dio.get<Map<String, dynamic>>(
        '/v1/participants/me/measurement-set/current',
        queryParameters: {'deviceId': deviceId},
      ),
      _dio.get<Map<String, dynamic>>('/v1/participants/me/vitals'),
      _dio.get<Map<String, dynamic>>('/v1/algorithm-rules/current'),
    ]);
    final measurementJson = responses[0].data ?? const {};
    final vitalJson = responses[1].data ?? const {};
    final ruleJson = responses[2].data ?? const {};
    final history = ((measurementJson['history'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(_parseBodyMeasurement)
        .toList(growable: false);
    final selectedIds =
        ((measurementJson['selectedMeasurementIds'] as List?) ?? const [])
            .map((value) => value.toString())
            .toSet();
    final selected =
        history.where((item) => selectedIds.contains(item.id)).toList()
          ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return MeasurementSnapshot(
      bodyCompositionHistory: history,
      selectedMeasurements: selected,
      vitals: ((vitalJson['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(parseBackendVitalMeasurement)
          .toList(growable: false),
      syncedAt: DateTime.parse(measurementJson['syncedAt'] as String),
      ruleSet: parseAlgorithmRuleSet(ruleJson),
    );
  }

  static AlgorithmRuleSet parseAlgorithmRuleSet(Map<String, dynamic> json) {
    final research = json['research'] as Map<String, dynamic>?;
    if (json['version'] != algorithmVersion ||
        research?['mode'] != 'simulation_only' ||
        research?['protocolEvidence'] != 'HYPOTHESIS_UNVALIDATED' ||
        research?['physicalExecution'] != 'PROHIBITED') {
      throw const FormatException('지원되지 않거나 불완전한 계산 규칙입니다.');
    }
    final measurementPolicy = json['measurementPolicy'] as Map<String, dynamic>;
    final output = json['output'] as Map<String, dynamic>;
    final baselinesJson = json['baselines'] as Map<String, dynamic>;
    final correction = json['correctionPolicy'] as Map<String, dynamic>;
    final gender = correction['gender'] as Map<String, dynamic>;
    final age = correction['age'] as Map<String, dynamic>;
    final fat = correction['bodyFat'] as Map<String, dynamic>;
    final femaleFat = fat['female'] as Map<String, dynamic>;
    final maleFat = fat['male'] as Map<String, dynamic>;
    final muscle = correction['muscleMass'] as Map<String, dynamic>;
    final femaleMuscle = muscle['female'] as Map<String, dynamic>;
    final maleMuscle = muscle['male'] as Map<String, dynamic>;
    VibrationBaseSetting baseline(BodyPart part) {
      final value = baselinesJson[part.name] as Map<String, dynamic>;
      return VibrationBaseSetting(
        durationMin: (value['durationMin'] as num).toDouble(),
        frequencyHz: (value['frequencyHz'] as num).toInt(),
        intensityPct: (value['intensityPct'] as num).toDouble(),
      );
    }

    return AlgorithmRuleSet(
      version: json['version'] as String,
      enabled: json['enabled'] as bool,
      baselines: {for (final part in BodyPart.values) part: baseline(part)},
      femaleCoefficient: (gender['female'] as num).toDouble(),
      maleCoefficient: (gender['male'] as num).toDouble(),
      ageUnder60Coefficient: (age['under60'] as num).toDouble(),
      ageSixtiesCoefficient: (age['sixties'] as num).toDouble(),
      ageSeventiesCoefficient: (age['seventies'] as num).toDouble(),
      ageEightyPlusCoefficient: (age['eightyPlus'] as num).toDouble(),
      femaleBodyFat: BodyFatThresholds(
        lowPct: (femaleFat['lowThresholdPct'] as num).toDouble(),
        highPct: (femaleFat['highThresholdPct'] as num).toDouble(),
      ),
      maleBodyFat: BodyFatThresholds(
        lowPct: (maleFat['lowThresholdPct'] as num).toDouble(),
        highPct: (maleFat['highThresholdPct'] as num).toDouble(),
      ),
      femaleMuscleIndex: MuscleIndexThresholds(
        lowMaximum: (femaleMuscle['lowMaximum'] as num).toDouble(),
        mediumMaximum: (femaleMuscle['mediumMaximum'] as num).toDouble(),
      ),
      maleMuscleIndex: MuscleIndexThresholds(
        lowMaximum: (maleMuscle['lowMaximum'] as num).toDouble(),
        mediumMaximum: (maleMuscle['mediumMaximum'] as num).toDouble(),
      ),
      lowBodyFatCoefficient: (fat['lowCoefficient'] as num).toDouble(),
      normalBodyFatCoefficient: (fat['normalCoefficient'] as num).toDouble(),
      highBodyFatCoefficient: (fat['highCoefficient'] as num).toDouble(),
      muscleMassCoefficient: (muscle['neutralCoefficient'] as num).toDouble(),
      minimumPct: (output['minimumPct'] as num).toDouble(),
      maximumPct: (output['maximumPct'] as num).toDouble(),
      maximumAgeDays: measurementPolicy['maximumAgeDays'] as int,
      maximumFutureSkewMinutes:
          measurementPolicy['maximumFutureSkewMinutes'] as int,
      policyBasis: measurementPolicy['policyBasis'] as String,
      physicalExecution: research!['physicalExecution'] as String,
    );
  }

  static BiaMeasurement _parseBodyMeasurement(Map<String, dynamic> json) {
    final values = json['values'] as Map<String, dynamic>;
    double number(String key) => (values[key] as num).toDouble();
    double? optional(String key) => (values[key] as num?)?.toDouble();
    return BiaMeasurement(
      id: json['id'] as String,
      participantId: json['participantId'] as String,
      deviceId: json['deviceId'] as String,
      measuredAt: DateTime.parse(json['measuredAt'] as String),
      qualityPassed: json['qualityPassed'] as bool,
      muscleDefinition: MuscleMassBasis.values.byName(
        (json['muscleDefinition'] as String).toLowerCase(),
      ),
      muscleMeasurementMethod:
          json['muscleMeasurementMethod'] as String? ?? 'UNKNOWN',
      methodEvidenceRef: json['methodEvidenceRef'] as String? ?? '',
      muscleMassUnit: json['muscleMassUnit'] as String? ?? 'kg',
      definitionRef: json['definitionRef'] as String? ?? '',
      acquisitionProtocolRef:
          json['acquisitionProtocol'] as String? ?? 'UNKNOWN',
      values: BiaValues(
        weightKg: number('weightKg'),
        bmi: number('bmi'),
        bodyFatPct: number('bodyFatPct'),
        fatMassKg: number('fatMassKg'),
        skeletalMuscleMassKg: number('skeletalMuscleMassKg'),
        basalMetabolicRateKcal: optional('basalMetabolicRateKcal'),
        bodyWaterPct: optional('bodyWaterPct'),
        proteinKg: optional('proteinKg'),
        mineralKg: optional('mineralKg'),
        ecwRatio: optional('ecwRatio'),
        waistCm: optional('waistCm'),
        visceralFatLevel: optional('visceralFatLevel'),
        obesityIndex: optional('obesityIndex'),
        abdomenIndex: optional('abdomenIndex'),
        dailyCalorie: optional('dailyCalorie'),
        intracellularWater: optional('intracellularWater'),
        extracellularWater: optional('extracellularWater'),
        bodyAge: optional('bodyAge'),
      ),
    );
  }
}

VitalMeasurement parseBackendVitalMeasurement(Map<String, dynamic> json) {
  final rawValues = json['values'] as Map<String, dynamic>;
  return VitalMeasurement(
    id: json['id'] as String,
    kind: VitalKind.values.byName(json['kind'] as String),
    measuredAt: DateTime.parse(json['measuredAt'] as String),
    values: {
      for (final entry in rawValues.entries)
        if (entry.value is num) entry.key: (entry.value as num).toDouble(),
    },
    units: Map<String, String>.from(json['units'] as Map),
    level: rawValues['level']?.toString(),
  );
}

BiaMeasurement _body(
  String id,
  String participantId,
  String deviceId,
  DateTime measuredAt,
  double weight,
  double bmi,
  double bodyFat,
  double fatMass,
  double muscle,
  double bmr,
  double water,
  double protein,
  double mineral,
  double ecw,
  double waist,
  double visceral,
) => BiaMeasurement(
  id: id,
  participantId: participantId,
  deviceId: deviceId,
  measuredAt: measuredAt,
  qualityPassed: true,
  muscleDefinition: MuscleMassBasis.smm,
  muscleMeasurementMethod: 'BIA_SAMPLE',
  methodEvidenceRef: 'SYNTHETIC-METHOD-EVIDENCE-V1',
  muscleMassUnit: 'kg',
  definitionRef: 'SYNTHETIC-SMM-DEMO-V1',
  acquisitionProtocolRef: 'SYNTHETIC-STANDARD-V1',
  values: BiaValues(
    weightKg: weight,
    bmi: bmi,
    bodyFatPct: bodyFat,
    fatMassKg: fatMass,
    skeletalMuscleMassKg: muscle,
    basalMetabolicRateKcal: bmr,
    bodyWaterPct: water,
    proteinKg: protein,
    mineralKg: mineral,
    ecwRatio: ecw,
    waistCm: waist,
    visceralFatLevel: visceral,
  ),
);
