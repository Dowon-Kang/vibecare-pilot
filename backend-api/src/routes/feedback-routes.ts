import { feedbackAdjustment } from '../feedback';
import { readFeedbackAdjustment } from '../feedback-store';
import { accessParticipantId, jsonBody } from '../http';
import { feedbackSchema } from '../request-schemas';
import { ownedSession } from '../session-store';
import type { VibeCareApp } from '../app-context';

export function registerFeedbackRoutes(app: VibeCareApp): void {
  app.get('/v1/feedback-adjustment', async (context) => {
    const participantId = await accessParticipantId(context);
    if (!participantId) return context.json({ error: 'UNAUTHORIZED' }, 401);
    return context.json({
      adjustment: await readFeedbackAdjustment(context, participantId),
    });
  });

  app.post('/v1/session-feedback', async (context) => {
    const participantId = await accessParticipantId(context);
    if (!participantId) return context.json({ error: 'UNAUTHORIZED' }, 401);
    const parsed = feedbackSchema.safeParse(await jsonBody(context));
    if (!parsed.success) return context.json({ error: 'INVALID_REQUEST' }, 400);
    const session = await ownedSession(context, parsed.data.sessionId, participantId);
    if (!session) return context.json({ error: 'SESSION_NOT_FOUND' }, 404);
    if (!['STOPPED', 'COMPLETED'].includes(String(session.status))) {
      return context.json({ error: 'SESSION_NOT_FINISHED' }, 409);
    }

    const existing = await context.env.DB.prepare(
      'SELECT * FROM session_feedback WHERE session_id = ?',
    ).bind(session.id).first<Record<string, unknown>>();
    const earlyStopped = session.status === 'STOPPED' || parsed.data.earlyStopped === true;
    const execution = {
      earlyStopped,
      actualDurationSec: parsed.data.actualDurationSec ?? null,
      measuredPeakG: parsed.data.measuredPeakG ?? null,
      measuredRmsG: parsed.data.measuredRmsG ?? null,
      source: 'participant_report',
    };
    if (existing) {
      if (
        existing.execution_json &&
        existing.execution_json !== JSON.stringify(execution)
      ) {
        return context.json({ error: 'FEEDBACK_ALREADY_SAVED' }, 409);
      }
      if (
        existing.rpe !== parsed.data.rpe ||
        existing.pain !== parsed.data.pain ||
        Number(existing.dizziness) !== Number(parsed.data.dizziness) ||
        (existing.intensity_rating ?? null) !== (parsed.data.intensityRating ?? null) ||
        (existing.duration_rating ?? null) !== (parsed.data.durationRating ?? null) ||
        (existing.frequency_rating ?? null) !== (parsed.data.frequencyRating ?? null) ||
        (existing.discomfort ?? null) !== (parsed.data.discomfort ?? null)
      ) {
        return context.json({ error: 'FEEDBACK_ALREADY_SAVED' }, 409);
      }
      return context.json({
        saved: true,
        adjustment: await readFeedbackAdjustment(context, participantId),
      });
    }

    const commandRow = await context.env.DB.prepare(
      'SELECT command_json FROM device_sessions WHERE id = ?',
    ).bind(session.id).first<{ command_json: string }>();
    if (!commandRow) return context.json({ error: 'SESSION_NOT_FOUND' }, 404);
    const command = JSON.parse(commandRow.command_json) as { intensityPct: number };
    const previous = await readFeedbackAdjustment(context, participantId);
    const adjustment = feedbackAdjustment(
      { ...parsed.data, earlyStopped },
      command.intensityPct,
      previous?.intensityCap,
      previous?.requiresReview,
    );
    await context.env.DB.batch([
      context.env.DB.prepare(
        `INSERT INTO session_feedback(
          session_id, rpe, pain, dizziness, intensity_rating, duration_rating,
          frequency_rating, discomfort, execution_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      ).bind(
        session.id,
        parsed.data.rpe,
        parsed.data.pain,
        Number(parsed.data.dizziness),
        parsed.data.intensityRating ?? null,
        parsed.data.durationRating ?? null,
        parsed.data.frequencyRating ?? null,
        parsed.data.discomfort ?? null,
        JSON.stringify(execution),
      ),
      context.env.DB.prepare(
        `INSERT INTO feedback_adjustments(
          participant_id, source_session_id, intensity_cap, requires_review,
          reason, policy_version, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(participant_id) DO UPDATE SET
          source_session_id = excluded.source_session_id,
          intensity_cap = MIN(feedback_adjustments.intensity_cap, excluded.intensity_cap),
          requires_review = MAX(feedback_adjustments.requires_review, excluded.requires_review),
          reason = excluded.reason,
          policy_version = excluded.policy_version,
          updated_at = excluded.updated_at`,
      ).bind(
        participantId,
        session.id,
        adjustment.intensityCap,
        Number(adjustment.requiresReview),
        adjustment.reason,
        adjustment.policyVersion,
        new Date().toISOString(),
      ),
      context.env.DB.prepare(
        'UPDATE feedback_adjustments SET reason_code = ? WHERE participant_id = ?',
      ).bind(adjustment.reasonCode, participantId),
    ]);
    return context.json({
      saved: true,
      adjustment: await readFeedbackAdjustment(context, participantId),
    });
  });
}
