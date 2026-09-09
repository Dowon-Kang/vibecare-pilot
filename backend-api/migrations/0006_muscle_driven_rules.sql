UPDATE algorithm_rule_sets SET enabled = 0 WHERE enabled = 1;

INSERT INTO algorithm_rule_sets
  (version, enabled, active_from, rules_json, change_reason, evidence_reference, approved_by)
VALUES (
  'pilot-0.5.0',
  1,
  '2026-09-08T00:00:00Z',
  '{"version":"pilot-0.5.0","activeFrom":"2026-09-08T00:00:00Z","enabled":true,"base":{"durationSec":300,"frequencyHz":20,"intensityPct":50},"age":{"threshold":70,"factor":0.9},"sex":{"femaleFactor":1.0,"maleFactor":1.0},"bodyFat":{"female":{"minimum":20,"maximum":35},"male":{"minimum":10,"maximum":28},"outsideRangeFactor":1.0},"muscle":{"female":{"lowMaximum":5.75,"mediumMaximum":6.75},"male":{"lowMaximum":8.5,"mediumMaximum":10.75},"protocols":{"low":{"durationSec":180,"frequencyHz":12,"intensityPct":30},"medium":{"durationSec":240,"frequencyHz":16,"intensityPct":40},"reference":{"durationSec":300,"frequencyHz":20,"intensityPct":50}}},"output":{"minimumPct":20,"maximumPct":70}}',
  '전신 골격근지수를 주 변수로 기본 진동 프로토콜을 선택하는 연구용 규칙. 장치 보정 및 전문가 승인 전 Mock/미리보기 전용.',
  'Janssen 2000/2004; Wei 2017; Wu 2020; van Heuvelen 2021',
  NULL
);
