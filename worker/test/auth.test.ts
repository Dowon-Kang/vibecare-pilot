import { describe, expect, it } from 'vitest';
import { hashPin, issueToken, verifyPin, verifyToken } from '../src/auth';

describe('PIN and token security', () => {
  it('hashes and verifies a PIN without storing the original value', async () => {
    const salt = 'c2FtcGxlLXNhbHQ';
    const hash = await hashPin('123456', salt);
    expect(hash).not.toContain('123456');
    await expect(verifyPin('123456', salt, hash)).resolves.toBe(true);
    await expect(verifyPin('654321', salt, hash)).resolves.toBe(false);
  });

  it('issues signed, purpose-bound tokens', async () => {
    const secret = 'test-secret-at-least-32-characters';
    const token = await issueToken(secret, 'USER-001', 'access', 2);
    await expect(verifyToken(secret, token, 'access')).resolves.toMatchObject({
      sub: 'USER-001',
      kind: 'access',
      refreshVersion: 2,
    });
    await expect(verifyToken('wrong-secret-at-least-32-characters', token, 'access')).resolves.toBeNull();
    await expect(verifyToken(secret, token, 'refresh')).resolves.toBeNull();
  });
});
