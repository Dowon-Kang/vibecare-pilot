import type { AlgorithmRuleSet } from './algorithm';
import type { AppContext } from './app-context';
import { ruleSchema } from './rule-schema';

export async function loadRuleSet(context: AppContext): Promise<AlgorithmRuleSet | null> {
  const row = await context.env.DB.prepare(
    `SELECT version, rules_json FROM algorithm_rule_sets
      WHERE enabled = 1 AND active_from <= ?
      ORDER BY active_from DESC LIMIT 1`,
  ).bind(new Date().toISOString()).first<{ version: string; rules_json: string }>();
  if (!row) return null;

  try {
    const parsed = ruleSchema.safeParse(JSON.parse(row.rules_json));
    return parsed.success &&
      parsed.data.version === row.version &&
      Date.parse(parsed.data.activeFrom) <= Date.now()
      ? parsed.data
      : null;
  } catch {
    return null;
  }
}
