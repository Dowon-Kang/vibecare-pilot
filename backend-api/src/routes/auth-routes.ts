import { issueToken, verifyPin, verifyToken } from '../auth';
import { jsonBody } from '../http';
import { pinSchema, refreshSchema } from '../request-schemas';
import type { VibeCareApp } from '../app-context';

export function registerAuthRoutes(app: VibeCareApp): void {
  app.post('/v1/auth/pin', async (context) => {
    const parsed = pinSchema.safeParse(await jsonBody(context));
    if (!parsed.success) return context.json({ error: 'INVALID_REQUEST' }, 400);
    if ((context.env.AUTH_TOKEN_SECRET?.length ?? 0) < 32) {
      return context.json({ error: 'AUTH_NOT_CONFIGURED' }, 503);
    }

    const row = await context.env.DB.prepare(
      `SELECT p.id, p.participant_code, p.age, p.sex, p.height_cm,
              pc.salt, pc.pin_hash, pc.failed_attempts, pc.locked_until, pc.refresh_version
         FROM participants p JOIN pin_credentials pc ON pc.participant_id = p.id
        WHERE p.participant_code = ?`,
    ).bind(parsed.data.participantCode.trim().toUpperCase()).first<Record<string, unknown>>();
    if (!row) return context.json({ error: 'INVALID_CREDENTIALS' }, 401);
    if (typeof row.locked_until === 'string' && Date.parse(row.locked_until) > Date.now()) {
      return context.json({ error: 'ACCOUNT_LOCKED', lockedUntil: row.locked_until }, 423);
    }

    const valid = await verifyPin(parsed.data.pin, String(row.salt), String(row.pin_hash));
    if (!valid) {
      const failures = Number(row.failed_attempts) + 1;
      const lockedUntil = failures >= 5
        ? new Date(Date.now() + 15 * 60_000).toISOString()
        : null;
      await context.env.DB.prepare(
        'UPDATE pin_credentials SET failed_attempts = ?, locked_until = ? WHERE participant_id = ?',
      ).bind(failures >= 5 ? 0 : failures, lockedUntil, row.id).run();
      return context.json(
        { error: lockedUntil ? 'ACCOUNT_LOCKED' : 'INVALID_CREDENTIALS', lockedUntil },
        lockedUntil ? 423 : 401,
      );
    }

    await context.env.DB.prepare(
      'UPDATE pin_credentials SET failed_attempts = 0, locked_until = NULL WHERE participant_id = ?',
    ).bind(row.id).run();
    const refreshVersion = Number(row.refresh_version);
    const [accessToken, refreshToken] = await Promise.all([
      issueToken(context.env.AUTH_TOKEN_SECRET, String(row.id), 'access', refreshVersion),
      issueToken(context.env.AUTH_TOKEN_SECRET, String(row.id), 'refresh', refreshVersion),
    ]);
    return context.json({
      participant: {
        id: row.id,
        code: row.participant_code,
        age: row.age,
        sex: row.sex,
        heightCm: row.height_cm,
      },
      accessToken,
      refreshToken,
      expiresInSec: 900,
    });
  });

  app.post('/v1/auth/refresh', async (context) => {
    const parsed = refreshSchema.safeParse(await jsonBody(context));
    if (!parsed.success || (context.env.AUTH_TOKEN_SECRET?.length ?? 0) < 32) {
      return context.json({ error: 'INVALID_REQUEST' }, 400);
    }
    const claims = await verifyToken(
      context.env.AUTH_TOKEN_SECRET,
      parsed.data.refreshToken,
      'refresh',
    );
    if (!claims) return context.json({ error: 'INVALID_REFRESH_TOKEN' }, 401);
    const row = await context.env.DB.prepare(
      'SELECT refresh_version FROM pin_credentials WHERE participant_id = ?',
    ).bind(claims.sub).first<{ refresh_version: number }>();
    if (!row || Number(row.refresh_version) !== claims.refreshVersion) {
      return context.json({ error: 'REFRESH_TOKEN_REVOKED' }, 401);
    }
    return context.json({
      accessToken: await issueToken(
        context.env.AUTH_TOKEN_SECRET,
        claims.sub,
        'access',
        claims.refreshVersion,
      ),
      expiresInSec: 900,
    });
  });
}
