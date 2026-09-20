type SeedPolicyInput = {
  environment: string | undefined;
  allowSeed: string | undefined;
  databaseUrl: string | undefined;
};

export function assertDevelopmentSeedAllowed(input: SeedPolicyInput): void {
  if (input.environment !== 'development') {
    throw new Error('Development seed is allowed only in the development environment');
  }
  if (input.allowSeed !== 'true') {
    throw new Error('ALLOW_DEVELOPMENT_SEED=true is required');
  }
  let url: URL;
  try {
    url = new URL(input.databaseUrl ?? '');
  } catch {
    throw new Error('A valid loopback DATABASE_URL is required');
  }
  if (!['127.0.0.1', 'localhost', '::1'].includes(url.hostname)) {
    throw new Error('Development seed is restricted to a loopback database');
  }
}
