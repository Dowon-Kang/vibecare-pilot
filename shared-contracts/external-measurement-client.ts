/** Future app adapter: no BLE, provider keys, token persistence or automatic retries. */
export interface ExternalMeasurement {
  schemaVersion: 1; eventId: string; sourceId: string; deviceId: string; measuredAt: string;
  values: { weightKg: number; bodyFatPct: number; fatMassKg: number; muscleKg: number };
}
export interface MeasurementSession { ownerId: string; accessToken: string }
export interface MeasurementReceipt { measurementId: string; duplicate: boolean; status: 'stored' }
export class MeasurementUploadError extends Error {
  constructor(readonly code: string, readonly status?: number) { super(code); }
}
interface Options {
  supabaseUrl: string; publishableKey: string;
  getSession: () => Promise<MeasurementSession | null>;
  fetcher?: typeof fetch;
}
const serverErrors = new Set(['AUTH_REQUIRED','INVALID_PAYLOAD','INVALID_MEASUREMENT_TIME',
  'INVALID_MEASUREMENT_VALUES','EVENT_CONFLICT','ACCOUNT_LINK_REQUIRED','ACCOUNT_LINK_AMBIGUOUS',
  'PROFILE_REVIEW_REQUIRED','SOURCE_NOT_READY','UPLOAD_LIMIT']);
export function createMeasurementUploader(options: Options) {
  const base = new URL(options.supabaseUrl);
  if (base.protocol !== 'https:' || base.pathname !== '/' || base.search || base.hash || base.username || base.password) {
    throw new MeasurementUploadError('INVALID_SERVER_URL');
  }
  const endpoint = new URL('/rest/v1/rpc/submit_external_measurement', base).href;
  return async (expectedOwnerId: string, event: ExternalMeasurement, signal?: AbortSignal): Promise<MeasurementReceipt> => {
    const session = await options.getSession();
    if (!expectedOwnerId || !session?.accessToken) throw new MeasurementUploadError('AUTH_REQUIRED');
    if (session.ownerId !== expectedOwnerId) throw new MeasurementUploadError('ACCOUNT_CHANGED');
    const controller = new AbortController();
    const abort = () => controller.abort();
    signal?.addEventListener('abort', abort, {once:true});
    if (signal?.aborted) controller.abort();
    const timeout = setTimeout(abort, 25000);
    try {
      if (controller.signal.aborted) throw new MeasurementUploadError('UPLOAD_CANCELLED');
      const response = await (options.fetcher ?? fetch)(endpoint, {
        method:'POST', redirect:'error', signal:controller.signal,
        headers:{ apikey:options.publishableKey, Authorization:'Bearer '+session.accessToken, 'Content-Type':'application/json' },
        body:JSON.stringify({p_payload:event}),
      });
      const text = await response.text();
      if (text.length > 4096) throw new MeasurementUploadError('INVALID_RESPONSE');
      let body: Record<string,unknown>;
      try { body = JSON.parse(text) as Record<string,unknown>; }
      catch { throw new MeasurementUploadError('INVALID_RESPONSE'); }
      if (!body || typeof body !== 'object' || Array.isArray(body)) throw new MeasurementUploadError('INVALID_RESPONSE');
      if (controller.signal.aborted) throw new MeasurementUploadError('UPLOAD_CANCELLED');
      if ((await options.getSession())?.ownerId !== expectedOwnerId) throw new MeasurementUploadError('ACCOUNT_CHANGED');
      if (!response.ok) {
        const code = typeof body.message === 'string' && serverErrors.has(body.message) ? body.message : 'UPLOAD_FAILED';
        throw new MeasurementUploadError(code, response.status);
      }
      if (body.status !== 'stored' || typeof body.measurementId !== 'string' || !body.measurementId.startsWith('EXT-') ||
        body.measurementId.length > 128 || typeof body.duplicate !== 'boolean') throw new MeasurementUploadError('INVALID_RESPONSE');
      return {measurementId:body.measurementId,duplicate:body.duplicate,status:'stored'};
    } catch (error) {
      if (error instanceof MeasurementUploadError) throw error;
      throw new MeasurementUploadError(controller.signal.aborted ? 'UPLOAD_CANCELLED' : 'UPLOAD_UNAVAILABLE');
    } finally {
      clearTimeout(timeout); signal?.removeEventListener('abort',abort);
    }
  };
}
