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
    options: { requestId?: string; signal?: AbortSignal } = {},
  ): Promise<FitrusPayload> {
    const response = await this.fetcher(`${this.baseUrl}${fitrusPaths[kind]}`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': this.apiKey,
        ...(options.requestId ? { 'x-request-id': options.requestId } : {}),
      },
      body: JSON.stringify(payload),
      signal: options.signal,
    });

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
