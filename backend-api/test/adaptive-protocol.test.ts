import { describe, expect, it } from 'vitest';
import { selectAdaptiveProtocol } from '../src/adaptive-protocol';
import { cases, baseInput } from '../tools/adaptive-cases.ts';

describe('adaptive-research-0.2.0 shared regressions', () => {
  for (const scenario of cases()) {
    it(scenario.name, () => {
      const result = selectAdaptiveProtocol(scenario.input);
      expect(result.decision).toBe(scenario.decision);
      expect(result.reasonCodes).toContain(scenario.reason);
      expect(result.selectedStage?.id ?? null).toBe(scenario.stage);
      expect(result.requiresIndependentReview).toBe(
        result.selectedStage !== null,
      );
      expect(result.command).toBeNull();
      expect(result.realDeviceSendAllowed).toBe(false);
    });
  }
  it('does not mutate input or expose the selected stage by reference', () => {
    const input = baseInput();
    const before = structuredClone(input);
    const result = selectAdaptiveProtocol(input);
    result.selectedStage!.id = 'MUTATED';
    expect(input).toEqual(before);
  });
  it('history ordering cannot change the decision', () => {
    const input = baseInput();
    const result = selectAdaptiveProtocol(input);
    input.history.reverse();
    expect(selectAdaptiveProtocol(input)).toEqual(result);
  });
});
