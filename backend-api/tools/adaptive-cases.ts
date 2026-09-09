import { readFileSync } from 'node:fs';

const fixture = JSON.parse(
  readFileSync(
    new URL(
      '../../shared-contracts/fixtures/adaptive-research-0.2.0.json',
      import.meta.url,
    ),
    'utf8',
  ),
);
export const baseInput = () => structuredClone(fixture.base);
type Scenario = {
  name: string;
  set: Record<string, unknown>;
  unset?: string[];
  decision: string;
  reason: string;
  stage: string | null;
};

export function cases() {
  const result = (fixture.cases as Scenario[]).map((scenario) => {
    const input = baseInput();
    for (const [path, value] of Object.entries(scenario.set)) {
      const parts = path.split('.');
      const key = parts.pop()!;
      const parent = parts.reduce((node, part) => node[part], input);
      parent[key] = structuredClone(value);
    }
    for (const path of scenario.unset ?? []) {
      const parts = path.split('.');
      const key = parts.pop()!;
      delete parts.reduce((node, part) => node[part], input)[key];
    }
    return { ...scenario, input };
  });
  // Exhaust the discrete response domain, not a random sample: 3*11*3^3=891.
  for (let rank = 0; rank < 3; rank++) {
    for (let rpe = 0; rpe <= 10; rpe++) {
      for (const duration of ['WEAK', 'OK', 'STRONG']) {
        for (const frequency of ['WEAK', 'OK', 'STRONG']) {
          for (const intensity of ['WEAK', 'OK', 'STRONG']) {
            const input = baseInput();
            input.context.currentStageId = `S${rank}`;
            for (const item of input.history)
              Object.assign(item, {
                stageId: `S${rank}`,
                rpe,
                durationFeeling: duration,
                frequencyFeeling: frequency,
                intensityFeeling: intensity,
              });
            const strong =
              [duration, frequency, intensity].includes('STRONG') || rpe > 6;
            const stable = rpe >= 2 && rpe <= 6;
            const weak =
              stable &&
              [duration, frequency, intensity].every((x) => x === 'WEAK');
            const decision = strong
              ? rank === 0
                ? 'HOLD'
                : 'STEP_DOWN_CANDIDATE'
              : weak && rank < 2
                ? 'STEP_UP_REVIEW'
                : 'KEEP_CANDIDATE';
            const reason = strong
              ? rank === 0
                ? 'LOWEST_STAGE_NOT_TOLERATED'
                : 'TOLERABILITY_STEP_DOWN'
              : weak
                ? rank === 2
                  ? 'HIGHEST_APPROVED_STAGE_REACHED'
                  : 'REPEATED_LOW_RESPONSE_WITHIN_TARGET_RPE'
                : stable
                  ? 'RESPONSE_ACCEPTABLE_KEEP_STAGE'
                  : 'MORE_STABLE_SESSIONS_REQUIRED';
            const stage =
              decision === 'HOLD'
                ? null
                : `S${rank + (strong ? -1 : weak && rank < 2 ? 1 : 0)}`;
            result.push({
              name: `grid ${rank}/${rpe}/${duration}/${frequency}/${intensity}`,
              set: {},
              input,
              decision,
              reason,
              stage,
            });
          }
        }
      }
    }
  }
  return result;
}
