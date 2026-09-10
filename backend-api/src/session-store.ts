import type { AppContext } from './app-context';

export async function ownedSession(
  context: AppContext,
  sessionId: string,
  participantId: string,
): Promise<Record<string, unknown> | null> {
  return context.env.DB.prepare(
    `SELECT ds.id, ds.status, ds.stopped_at, ds.completed_at FROM device_sessions ds
      JOIN execution_authorizations ea ON ea.id = ds.authorization_id
      WHERE ds.id = ? AND ea.participant_id = ?`,
  ).bind(sessionId, participantId).first<Record<string, unknown>>();
}
