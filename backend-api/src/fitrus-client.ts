export const fitrusPaths = {
  bloodPressure: '/bp',
  heartRate: '/hr',
  stress: '/stress',
  bodyTemperature: '/bodytemp',
  bodyFat: '/bodyfat',
  stressV2: '/stress2',
} as const;

export type FitrusMeasurementKind = keyof typeof fitrusPaths;
export type FitrusPayload = Record<string, unknown>;

export class FitrusApiError extends Error {
  constructor(
    readonly status: number,
    readonly responseBody: string,
  ) {
    super(`FITRUS API request failed with status ${status}`);
    this.name = 'FitrusApiError';
  }
}

export class FitrusTimeoutError extends Error {
  constructor(readonly timeoutMs: number) {
    super(`FITRUS API request timed out after ${timeoutMs}ms`);
    this.name = 'FitrusTimeoutError';
  }
}

export class FitrusNetworkError extends Error {
  constructor(readonly cause: unknown) {
    super('FITRUS API network request failed');
    this.name = 'FitrusNetworkError';
  }
}

export class FitrusClient {
  constructor(
    private readonly apiKey: string,
    private readonly baseUrl = 'https://api.thefitrus.com/fitrus-ml/measure',
    private readonly fetcher: typeof fetch = fetch,
  ) {
    if (!apiKey.trim()) throw new Error('FITRUS_API_KEY is required');
  }

  async measure(
    kind: FitrusMeasurementKind,
    payload: FitrusPayload,
    options: { requestId?: string; signal?: AbortSignal; timeoutMs?: number } = {},
  ): Promise<FitrusPayload> {
    const timeoutMs = options.timeoutMs ?? 10_000;
    if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
      throw new RangeError('timeoutMs must be a positive finite number');
    }
    const controller = new AbortController();
    let timedOut = false;
    const abortFromCaller = () => controller.abort(options.signal?.reason);
    options.signal?.addEventListener('abort', abortFromCaller, { once: true });
    if (options.signal?.aborted) abortFromCaller();
    const timeout = setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, timeoutMs);

    let response: Response;
    try {
      response = await this.fetcher(`${this.baseUrl}${fitrusPaths[kind]}`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-api-key': this.apiKey,
          ...(options.requestId ? { 'x-request-id': options.requestId } : {}),
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
    } catch (error) {
      if (timedOut) throw new FitrusTimeoutError(timeoutMs);
      if (options.signal?.aborted) throw error;
      throw new FitrusNetworkError(error);
    } finally {
      clearTimeout(timeout);
      options.signal?.removeEventListener('abort', abortFromCaller);
    }

    if (!response.ok) {
      throw new FitrusApiError(response.status, await response.text());
    }

    const contentType = response.headers.get('content-type') ?? '';
    if (!contentType.includes('json')) {
      throw new FitrusApiError(response.status, 'Expected a JSON response');
    }
    return (await response.json()) as FitrusPayload;
  }
}
