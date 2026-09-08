export type TokenKind = 'access' | 'refresh';

export type TokenClaims = {
  sub: string;
  kind: TokenKind;
  exp: number;
  refreshVersion: number;
};

const encoder = new TextEncoder();

const bytesToBase64Url = (bytes: Uint8Array) => {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
};

const base64UrlToBytes = (value: string) => {
  const base64 = value.replaceAll('-', '+').replaceAll('_', '/').padEnd(Math.ceil(value.length / 4) * 4, '=');
  const binary = atob(base64);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
};

export async function hashPin(pin: string, saltBase64Url: string): Promise<string> {
  const material = await crypto.subtle.importKey('raw', encoder.encode(pin), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', hash: 'SHA-256', salt: base64UrlToBytes(saltBase64Url), iterations: 120_000 },
    material,
    256,
  );
  return bytesToBase64Url(new Uint8Array(bits));
}

export async function verifyPin(pin: string, salt: string, expectedHash: string): Promise<boolean> {
  const actual = await hashPin(pin, salt);
  if (actual.length !== expectedHash.length) return false;
  let difference = 0;
  for (let index = 0; index < actual.length; index += 1) {
    difference |= actual.charCodeAt(index) ^ expectedHash.charCodeAt(index);
  }
  return difference === 0;
}

async function hmac(secret: string, payload: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return bytesToBase64Url(new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(payload))));
}

export async function issueToken(
  secret: string,
  participantId: string,
  kind: TokenKind,
  refreshVersion: number,
): Promise<string> {
  const lifetimeSeconds = kind === 'access' ? 15 * 60 : 30 * 24 * 60 * 60;
  const claims: TokenClaims = {
    sub: participantId,
    kind,
    exp: Math.floor(Date.now() / 1000) + lifetimeSeconds,
    refreshVersion,
  };
  const payload = bytesToBase64Url(encoder.encode(JSON.stringify(claims)));
  return `${payload}.${await hmac(secret, payload)}`;
}

export async function verifyToken(
  secret: string,
  token: string,
  expectedKind: TokenKind,
): Promise<TokenClaims | null> {
  const [payload, signature, extra] = token.split('.');
  if (!payload || !signature || extra) return null;
  const expectedSignature = await hmac(secret, payload);
  if (signature.length !== expectedSignature.length) return null;
  let difference = 0;
  for (let index = 0; index < signature.length; index += 1) {
    difference |= signature.charCodeAt(index) ^ expectedSignature.charCodeAt(index);
  }
  if (difference !== 0) return null;
  try {
    const claims = JSON.parse(new TextDecoder().decode(base64UrlToBytes(payload))) as TokenClaims;
    if (claims.kind !== expectedKind || claims.exp <= Math.floor(Date.now() / 1000) || !claims.sub) return null;
    return claims;
  } catch {
    return null;
  }
}
