import 'dart:math' as math;

import 'package:vibecare_pilot/algorithm/muscle_pathways.dart';

const protocolReadinessVersion = 'research-gate-0.8.1';

Map<String, dynamic> _object(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
bool _nonempty(Object? value) => value is String && value.trim().isNotEmpty;
bool _positive(Object? value) => value is num && value.isFinite && value > 0;
bool _timestamp(Object? value) =>
    value is String &&
    RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$').hasMatch(value) &&
    DateTime.tryParse(value)?.toUtc().toIso8601String() == value;
double _relativeErrorPct(num actual, num expected) =>
    ((actual - expected).abs() / expected) * 100;

/// Evidence, physical-output and governance gate for a standing WBV study.
/// This evaluator never creates or authorizes a device command.
Map<String, dynamic> evaluateProtocolReadiness(Object? raw) {
  final input = _object(raw);
  Map<String, dynamic> finish(
    String state,
    List<String> reasonCodes, [
    Map<String, dynamic>? assessment,
    Map<String, dynamic>? protocol,
    Map<String, dynamic>? mechanics,
  ]) => {
    'algorithmVersion': protocolReadinessVersion,
    'state': state,
    'reasonCodes': reasonCodes,
    'assessment': assessment,
    'selectedProtocol': protocol,
    'mechanics': mechanics,
    'evidence': {
      'muscleAssociation': 'INDIRECT',
      'muscleToDoseMapping': 'UNVALIDATED',
      'bodyFatToDoseMapping': 'NOT_SUPPORTED',
      'analyticalValidation': state == 'INDEPENDENT_REVIEW_REQUIRED'
          ? 'CANDIDATE'
          : 'INCOMPLETE',
      'clinicalValidation': 'ABSENT',
    },
    'command': null,
    'realDeviceSendAllowed': false,
  };

  final safety = _object(input['safety']);
  const safetyKeys = ['acutePain', 'dizziness', 'clinicianHold'];
  if (safetyKeys.any((key) => safety[key] == true)) {
    return finish('SAFETY_BLOCKED', ['SAFETY_HOLD']);
  }
  if (safetyKeys.any((key) => safety[key] is! bool)) {
    return finish('DATA_REVIEW', ['SAFETY_INCOMPLETE']);
  }

  final acquisition = _object(input['acquisition']);
  if (acquisition['standardized'] != true ||
      acquisition['measurementDefinitionVerified'] != true ||
      !_nonempty(acquisition['protocolRef'])) {
    return finish('DATA_REVIEW', [
      acquisition['measurementDefinitionVerified'] == true
          ? 'ACQUISITION_NOT_STANDARDIZED'
          : 'MEASUREMENT_DEFINITION_UNVERIFIED',
    ]);
  }

  final base = calculateMusclePathway({
    'profile': input['profile'],
    'measurements': input['measurements'],
    'safety': safety,
  });
  if (base['status'] == 'BLOCKED') {
    return finish('SAFETY_BLOCKED', ['SAFETY_HOLD']);
  }
  if (base['status'] != 'READY' || base['assessment'] == null) {
    return finish('DATA_REVIEW', [
      'MUSCLE_ASSESSMENT_REVIEW',
      ...(base['reasonCodes'] as List).cast<String>(),
    ], base['assessment'] == null ? null : _object(base['assessment']));
  }
  final assessment = _object(base['assessment']);
  if (assessment['definitionRef'] != acquisition['protocolRef']) {
    return finish('DATA_REVIEW', [
      'MEASUREMENT_DEFINITION_REFERENCE_MISMATCH',
    ], assessment);
  }

  final catalog = input['protocolCatalog'] is List
      ? (input['protocolCatalog'] as List).map(_object).toList()
      : <Map<String, dynamic>>[];
  final matching = catalog
      .where(
        (candidate) =>
            candidate['targetCategory'] == assessment['category'] &&
            (!input.containsKey('requestedProtocolId') ||
                candidate['id'] == input['requestedProtocolId']),
      )
      .toList();
  if (matching.isEmpty) {
    return finish('PROTOCOL_REQUIRED', [
      'NO_PROTOCOL_FOR_MUSCLE_CATEGORY',
    ], assessment);
  }
  if (matching.length != 1) {
    return finish('PROTOCOL_REVIEW', [
      'AMBIGUOUS_PROTOCOL_FOR_MUSCLE_CATEGORY',
    ], assessment);
  }
  final protocol = matching.single;
  bool integerPositive(Object? value) =>
      _positive(value) && value is num && value == value.round();
  if (!_nonempty(protocol['id']) ||
      !_nonempty(protocol['deviceId']) ||
      !_nonempty(protocol['sourceRef']) ||
      !['VERTICAL', 'SIDE_ALTERNATING'].contains(protocol['platformMode']) ||
      protocol['waveform'] != 'SINUSOIDAL' ||
      !_nonempty(protocol['posture']) ||
      !_positive(protocol['frequencyHz']) ||
      !_positive(protocol['peakToPeakDisplacementMm']) ||
      !integerPositive(protocol['boutDurationSec']) ||
      !integerPositive(protocol['restDurationSec']) ||
      !integerPositive(protocol['bouts'])) {
    return finish('PROTOCOL_REVIEW', [
      'PHYSICAL_PROTOCOL_INCOMPLETE',
    ], assessment);
  }

  final amplitudeM = protocol['peakToPeakDisplacementMm'] / 2 / 1000;
  final frequencyHz = (protocol['frequencyHz'] as num).toDouble();
  final predictedPeakAccelerationG =
      math.pow(2 * math.pi * frequencyHz, 2) * amplitudeM / 9.80665;
  final mechanics = <String, dynamic>{
    'predictedPeakAccelerationG': predictedPeakAccelerationG,
    'predictedRmsAccelerationG': predictedPeakAccelerationG / math.sqrt(2),
    'calculationScope': 'IDEAL_SINUSOID_SINGLE_AXIS_NOT_MEASURED_BODY_DOSE',
    'totalActiveDurationSec': protocol['boutDurationSec'] * protocol['bouts'],
    'totalRestDurationSec':
        protocol['restDurationSec'] * math.max(0, protocol['bouts'] - 1),
    'formula': 'aPeak=(2*pi*f)^2*(peakToPeakDisplacement/2)',
    'uiPercentUsedAsPhysicalDose': false,
  };
  bool safeInteger(Object? value) =>
      value is num &&
      value.isFinite &&
      value == value.round() &&
      value.abs() <= 9007199254740991;
  if (!_positive(predictedPeakAccelerationG) ||
      !_positive(mechanics['predictedRmsAccelerationG']) ||
      !safeInteger(mechanics['totalActiveDurationSec']) ||
      !safeInteger(mechanics['totalRestDurationSec'])) {
    return finish('PROTOCOL_REVIEW', [
      'PHYSICAL_CALCULATION_OUT_OF_RANGE',
    ], assessment);
  }

  if (!_nonempty(protocol['approvalId'])) {
    return finish(
      'APPROVAL_REQUIRED',
      ['INVESTIGATOR_PROTOCOL_APPROVAL_MISSING'],
      assessment,
      protocol,
      mechanics,
    );
  }

  final calibration = _object(input['calibration']);
  if (calibration.isEmpty) {
    return finish(
      'CALIBRATION_REQUIRED',
      ['DEVICE_CALIBRATION_MISSING'],
      assessment,
      protocol,
      mechanics,
    );
  }
  if (!_nonempty(input['evaluatedAt']) ||
      !_timestamp(input['evaluatedAt']) ||
      !_nonempty(calibration['calibrationId']) ||
      calibration['deviceId'] != protocol['deviceId'] ||
      !_timestamp(calibration['validUntil']) ||
      DateTime.parse(
            calibration['validUntil'],
          ).compareTo(DateTime.parse(input['evaluatedAt'])) <=
          0 ||
      !_positive(calibration['measuredFrequencyHz']) ||
      !_positive(calibration['measuredPeakToPeakDisplacementMm']) ||
      !_positive(calibration['measuredPeakAccelerationG'])) {
    return finish(
      'CALIBRATION_REVIEW',
      ['DEVICE_CALIBRATION_INVALID'],
      assessment,
      protocol,
      mechanics,
    );
  }

  final acceptance = _object(input['engineeringAcceptance']);
  if (!_nonempty(acceptance['approvalRef']) ||
      !_positive(acceptance['frequencyTolerancePct']) ||
      !_positive(acceptance['displacementTolerancePct']) ||
      !_positive(acceptance['accelerationTolerancePct'])) {
    return finish(
      'CALIBRATION_REVIEW',
      ['ENGINEERING_ACCEPTANCE_CRITERIA_MISSING'],
      assessment,
      protocol,
      mechanics,
    );
  }
  final tolerances = {
    'frequencyPct': acceptance['frequencyTolerancePct'] as num,
    'displacementPct': acceptance['displacementTolerancePct'] as num,
    'accelerationPct': acceptance['accelerationTolerancePct'] as num,
  };
  final errors = {
    'frequencyPct': _relativeErrorPct(
      calibration['measuredFrequencyHz'],
      protocol['frequencyHz'],
    ),
    'displacementPct': _relativeErrorPct(
      calibration['measuredPeakToPeakDisplacementMm'],
      protocol['peakToPeakDisplacementMm'],
    ),
    'accelerationPct': _relativeErrorPct(
      calibration['measuredPeakAccelerationG'],
      predictedPeakAccelerationG,
    ),
  };
  if (errors.values.any((value) => !value.isFinite)) {
    return finish(
      'CALIBRATION_REVIEW',
      ['CALIBRATION_CALCULATION_OUT_OF_RANGE'],
      assessment,
      protocol,
      mechanics,
    );
  }
  mechanics.addAll({
    'calibrationId': calibration['calibrationId'],
    'calibrationErrorsPct': errors,
    'engineeringTolerancesPct': tolerances,
    'toleranceApprovalRef': acceptance['approvalRef'],
  });
  if (errors['frequencyPct']! > tolerances['frequencyPct']! ||
      errors['displacementPct']! > tolerances['displacementPct']! ||
      errors['accelerationPct']! > tolerances['accelerationPct']!) {
    return finish(
      'CALIBRATION_REVIEW',
      ['DEVICE_OUTPUT_OUTSIDE_ENGINEERING_TOLERANCE'],
      assessment,
      protocol,
      mechanics,
    );
  }

  return finish(
    'INDEPENDENT_REVIEW_REQUIRED',
    [
      'MUSCLE_TO_DOSE_RELATION_UNVALIDATED',
      'CLINICAL_VALIDATION_REQUIRED',
      'REAL_OUTPUT_DISABLED',
    ],
    assessment,
    protocol,
    mechanics,
  );
}
