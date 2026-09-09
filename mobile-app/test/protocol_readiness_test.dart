import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/algorithm/protocol_readiness.dart';
import 'package:vibecare_pilot/algorithm/adaptive_protocol.dart';

Map<String, dynamic> baseInput() {
  final peakG = math.pow(2 * math.pi * 16, 2) * 0.001 / 9.80665;
  return {
    'evaluatedAt': '2026-09-09T00:00:00.000Z',
    'profile': {
      'participantId': 'P-001',
      'sex': 'female',
      'age': 70,
      'heightCm': 160,
    },
    'acquisition': {
      'standardized': true,
      'measurementDefinitionVerified': true,
      'protocolRef': 'FITRUS-SMM-DEFINITION-APPROVED-001',
    },
    'safety': {'acutePain': false, 'dizziness': false, 'clinicianHold': false},
    'measurements': List.generate(4, (index) {
      return {
        'id': 'M-${index + 1}',
        'participantId': 'P-001',
        'deviceId': 'BIA-001',
        'measuredAt': '2026-09-0${index + 1}T09:00:00.000Z',
        'qualityPassed': true,
        'weightKg': 60,
        'bmi': 23.44,
        'bodyFatPct': 30,
        'fatMassKg': 18,
        'muscle': {
          'kind': 'SMM',
          'method': 'BIA',
          'definitionRef': 'FITRUS-SMM-DEFINITION-APPROVED-001',
          'massKg': 16,
        },
      };
    }),
    'protocolCatalog': [
      {
        'id': 'STUDY-MIDDLE-01',
        'deviceId': 'WBV-001',
        'targetCategory': 'MIDDLE',
        'sourceRef': 'IRB-PROTOCOL-001',
        'approvalId': 'APPROVAL-001',
        'platformMode': 'VERTICAL',
        'waveform': 'SINUSOIDAL',
        'posture': 'KNEE_FLEXED_DEFINED_IN_PROTOCOL',
        'frequencyHz': 16,
        'peakToPeakDisplacementMm': 2,
        'boutDurationSec': 30,
        'restDurationSec': 30,
        'bouts': 8,
      },
    ],
    'calibration': {
      'calibrationId': 'CAL-001',
      'deviceId': 'WBV-001',
      'validUntil': '2027-09-09T00:00:00.000Z',
      'measuredFrequencyHz': 16,
      'measuredPeakToPeakDisplacementMm': 2,
      'measuredPeakAccelerationG': peakG,
    },
    'engineeringAcceptance': {
      'approvalRef': 'ENGINEERING-REVIEW-001',
      'frequencyTolerancePct': 5,
      'displacementTolerancePct': 10,
      'accelerationTolerancePct': 15,
    },
  };
}

void main() {
  test('selects exact protocol id within a muscle category', () {
    final input = baseInput();
    input['protocolCatalog'].add(<String, Object>{
      ...input['protocolCatalog'][0],
      'id': 'ANOTHER',
    });
    expect(evaluateProtocolReadiness(input)['state'], 'PROTOCOL_REVIEW');
    input['requestedProtocolId'] = 'ANOTHER';
    expect(
      evaluateProtocolReadiness(input)['selectedProtocol']['id'],
      'ANOTHER',
    );
    input['requestedProtocolId'] = 'MISSING';
    expect(evaluateProtocolReadiness(input)['state'], 'PROTOCOL_REQUIRED');
  });
  test(
    'physical acceleration obeys squared frequency and linear displacement',
    () {
      final original = evaluateProtocolReadiness(baseInput())['mechanics'];
      final frequency = baseInput();
      frequency['protocolCatalog'][0]['frequencyHz'] *= 2;
      final displacement = baseInput();
      displacement['protocolCatalog'][0]['peakToPeakDisplacementMm'] *= 2;
      final peak = original['predictedPeakAccelerationG'];
      expect(
        evaluateProtocolReadiness(
          frequency,
        )['mechanics']['predictedPeakAccelerationG'],
        closeTo(peak * 4, 1e-12),
      );
      expect(
        evaluateProtocolReadiness(
          displacement,
        )['mechanics']['predictedPeakAccelerationG'],
        closeTo(peak * 2, 1e-12),
      );
      expect(
        original['predictedRmsAccelerationG'],
        closeTo(peak / math.sqrt(2), 1e-12),
      );
    },
  );
  test('rejects arithmetic overflow and underflow', () {
    for (final hz in [1e308, 1e-300]) {
      final input = baseInput();
      input['protocolCatalog'][0]['frequencyHz'] = hz;
      final result = evaluateProtocolReadiness(input);
      expect(
        result['reasonCodes'],
        contains('PHYSICAL_CALCULATION_OUT_OF_RANGE'),
      );
      expect(result['mechanics'], isNull);
    }
  });
  test('composes measurement assessment, adaptation and physical protocol', () {
    final readinessInput = baseInput();
    final adaptationInput = jsonDecode(
      File(
        '../shared-contracts/fixtures/adaptive-research-0.2.0.json',
      ).readAsStringSync(),
    )['base'];
    adaptationInput['context']['participantId'] = 'P-001';
    adaptationInput['context']['deviceId'] = 'WBV-001';
    adaptationInput['context']['currentStageId'] = null;
    adaptationInput['history'] = [];
    adaptationInput['muscleAssessment']['category'] = 'LOW';
    adaptationInput['policy']['stages'][1]['protocolId'] = 'STUDY-MIDDLE-01';
    final input = {
      'readinessInput': readinessInput,
      'adaptationInput': adaptationInput,
    };
    final result = evaluateAdaptiveResearch(input);
    expect(result['adaptation']['selectedStage']['id'], 'S1');
    expect(result['readiness']['state'], 'INDEPENDENT_REVIEW_REQUIRED');
    expect(result['readiness']['selectedProtocol']['id'], 'STUDY-MIDDLE-01');
    expect(result['command'], isNull);
    expect(result['realDeviceSendAllowed'], isFalse);
    adaptationInput['context']['deviceId'] = 'OTHER';
    expect(
      evaluateAdaptiveResearch(input)['readiness']['reasonCodes'],
      contains('DEVICE_CONTEXT_MISMATCH'),
    );
    adaptationInput['context']['participantId'] = 'OTHER';
    expect(evaluateAdaptiveResearch(input)['adaptation'], isNull);
    readinessInput['safety']['dizziness'] = true;
    expect(
      evaluateAdaptiveResearch(input)['readiness']['state'],
      'SAFETY_BLOCKED',
    );
  });
  test('complete candidate still requires independent review', () {
    final result = evaluateProtocolReadiness(baseInput());
    expect(result['state'], 'INDEPENDENT_REVIEW_REQUIRED');
    expect(result['assessment']['category'], 'MIDDLE');
    expect(result['selectedProtocol']['id'], 'STUDY-MIDDLE-01');
    expect(result['mechanics']['totalActiveDurationSec'], 240);
    expect(result['mechanics']['uiPercentUsedAsPhysicalDose'], isFalse);
    expect(result['command'], isNull);
    expect(result['realDeviceSendAllowed'], isFalse);
  });

  test('safety hold blocks before assessment', () {
    final input = baseInput();
    input['safety']['dizziness'] = true;
    final result = evaluateProtocolReadiness(input);
    expect(result['state'], 'SAFETY_BLOCKED');
    expect(result['assessment'], isNull);
  });

  test('unverified acquisition remains data review', () {
    final input = baseInput();
    input['acquisition']['measurementDefinitionVerified'] = false;
    expect(evaluateProtocolReadiness(input)['state'], 'DATA_REVIEW');
  });

  test('definition reference must match all measurements', () {
    final input = baseInput();
    input['acquisition']['protocolRef'] = 'OTHER-DEFINITION';
    expect(
      evaluateProtocolReadiness(input)['reasonCodes'],
      contains('MEASUREMENT_DEFINITION_REFERENCE_MISMATCH'),
    );
  });

  test('missing category protocol is not invented', () {
    final input = baseInput();
    input['protocolCatalog'] = [];
    expect(evaluateProtocolReadiness(input)['state'], 'PROTOCOL_REQUIRED');
  });

  test('approval and calibration are separate gates', () {
    final unapproved = baseInput();
    unapproved['protocolCatalog'][0]['approvalId'] = '';
    expect(evaluateProtocolReadiness(unapproved)['state'], 'APPROVAL_REQUIRED');

    final uncalibrated = baseInput();
    uncalibrated['calibration'] = <String, dynamic>{};
    expect(
      evaluateProtocolReadiness(uncalibrated)['state'],
      'CALIBRATION_REQUIRED',
    );
  });

  test('measured acceleration outside tolerance is rejected', () {
    final input = baseInput();
    input['calibration']['measuredPeakAccelerationG'] *= 1.5;
    final result = evaluateProtocolReadiness(input);
    expect(result['state'], 'CALIBRATION_REVIEW');
    expect(
      result['reasonCodes'],
      contains('DEVICE_OUTPUT_OUTSIDE_ENGINEERING_TOLERANCE'),
    );
  });

  test('engineering tolerances must carry an approval reference', () {
    final input = baseInput();
    input['engineeringAcceptance']['approvalRef'] = '';
    expect(
      evaluateProtocolReadiness(input)['reasonCodes'],
      contains('ENGINEERING_ACCEPTANCE_CRITERIA_MISSING'),
    );
  });
}
