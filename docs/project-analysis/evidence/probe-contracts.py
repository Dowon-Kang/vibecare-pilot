"""Read-only schema checks on synthetic data and the checked-in fixture."""
import json
from pathlib import Path
from jsonschema import Draft202012Validator, FormatChecker

root = Path(__file__).resolve().parents[3]
contracts = root / 'contracts'
fixture = json.loads((contracts / 'fixtures/pilot-0.3.0.json').read_text(encoding='utf-8'))
validators = {}
for name in ('bia-measurement', 'vital-measurement', 'device-command', 'algorithm-rule-set'):
    schema = json.loads((contracts / f'{name}.schema.json').read_text(encoding='utf-8'))
    Draft202012Validator.check_schema(schema)
    validators[name] = Draft202012Validator(schema, format_checker=FormatChecker())
validators['algorithm-rule-set'].validate(fixture['ruleSet'])
for measurement in fixture['measurements']:
    validators['bia-measurement'].validate(measurement)
nullable = json.loads(json.dumps(fixture['measurements'][0]))
nullable['values']['proteinKg'] = None
null_errors = list(validators['bia-measurement'].iter_errors(nullable))
vital = {'id':'V1','kind':'heartRate','measuredAt':'2026-09-07T00:00:00Z','values':{'heartRate':68},'units':{'heartRate':'bpm'}}
vital_errors = list(validators['vital-measurement'].iter_errors(vital))
assert null_errors and vital_errors
print(json.dumps({'schemaDefinitions':4,'fixtureMeasurementsPassed':4,'fixtureRulePassed':True,'apiShapedNullBiaRejected':[e.message for e in null_errors],'apiShapedVitalRejected':[e.message for e in vital_errors]},ensure_ascii=False,indent=2))
