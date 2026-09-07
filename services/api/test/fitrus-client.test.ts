import { describe, expect, it } from 'vitest';
import { FitrusApiError, FitrusClient } from '../src/fitrus-client';

describe('FitrusClient', () => {
  it('keeps the API key server-side and calls the bodyfat POST endpoint', async () => {
    let requestUrl = '';
    let requestInit: RequestInit | undefined;
    const fetcher: typeof fetch = async (input, init) => {
      requestUrl = input instanceof Request ? input.url : input.toString();
      requestInit = init;
      return new Response(
        JSON.stringify({ bodyFatPct: 18.8 }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      );
    };
    const client = new FitrusClient('server-secret', undefined, fetcher);

    const response = await client.measure('bodyFat', { vendorInput: 'sample' }, {
      requestId: 'request-1',
    });

    expect(response).toEqual({ bodyFatPct: 18.8 });
    expect(requestUrl).toBe('https://api.thefitrus.com/fitrus-ml/measure/bodyfat');
    expect(requestInit?.method).toBe('POST');
    expect(new Headers(requestInit?.headers).get('x-api-key')).toBe('server-secret');
  });

  it('returns a typed error without exposing the API key', async () => {
    const fetcher: typeof fetch = async () => new Response(
      JSON.stringify({ status: 403 }),
      { status: 403, headers: { 'content-type': 'application/problem+json' } },
    );
    const client = new FitrusClient('do-not-log-this', undefined, fetcher);

    await expect(client.measure('heartRate', {})).rejects.toMatchObject({
      status: 403,
    } satisfies Partial<FitrusApiError>);
    await expect(client.measure('heartRate', {})).rejects.not.toThrow('do-not-log-this');
  });
});
