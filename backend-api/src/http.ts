import { verifyToken } from './auth';
import type { AppContext } from './app-context';

export const jsonBody = async (context: AppContext): Promise<unknown> =>
  context.req.json().catch(() => null);

export async function accessParticipantId(context: AppContext): Promise<string | null> {
  const authorization = context.req.header('Authorization');
  if (
    !authorization?.startsWith('Bearer ') ||
    (context.env.AUTH_TOKEN_SECRET?.length ?? 0) < 32
  ) {
    return null;
  }
  const claims = await verifyToken(
    context.env.AUTH_TOKEN_SECRET,
    authorization.slice(7),
    'access',
  );
  return claims?.sub ?? null;
}
