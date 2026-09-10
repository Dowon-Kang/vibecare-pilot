import type { AppContext } from './app-context';

export type FeedbackAdjustment = {
  intensityCap: number;
  requiresReview: boolean;
  reason: string;
  reasonCode: string;
  policyVersion: string;
  sourceSessionId: string;
};

export async function readFeedbackAdjustment(
  context: AppContext,
  participantId: string,
): Promise<FeedbackAdjustment | null> {
  const row = await context.env.DB.prepare(
    'SELECT * FROM feedback_adjustments WHERE participant_id = ?',
  ).bind(participantId).first<Record<string, unknown>>();
  return row
    ? {
        intensityCap: Number(row.intensity_cap),
        requiresReview: Number(row.requires_review) === 1,
        reason: String(row.reason),
        reasonCode: String(row.reason_code),
        policyVersion: String(row.policy_version),
        sourceSessionId: String(row.source_session_id),
      }
    : null;
}
