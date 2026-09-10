import { Hono } from 'hono';
import type { AppEnvironment } from './app-context';
import { FitrusApiError, FitrusNetworkError, FitrusTimeoutError } from './fitrus-client';
import { registerAuthRoutes } from './routes/auth-routes';
import { registerFeedbackRoutes } from './routes/feedback-routes';
import { registerMeasurementRoutes } from './routes/measurement-routes';
import { registerRecommendationRoutes } from './routes/recommendation-routes';
import { registerSessionRoutes } from './routes/session-routes';

const app = new Hono<AppEnvironment>();

app.get('/health', (context) => context.json({
  ok: true,
  service: 'vibecare-api',
  deviceMode: context.env.DEVICE_MODE ?? 'mock',
}));

registerAuthRoutes(app);
registerMeasurementRoutes(app);
registerRecommendationRoutes(app);
registerSessionRoutes(app);
registerFeedbackRoutes(app);

app.onError((error, context) => {
  if (error instanceof FitrusTimeoutError) {
    return context.json({ error: 'FITRUS_TIMEOUT' }, 504);
  }
  if (error instanceof FitrusApiError) {
    return context.json({ error: 'FITRUS_REJECTED', providerStatus: error.status }, 502);
  }
  if (error instanceof FitrusNetworkError) {
    return context.json({ error: 'FITRUS_NETWORK_ERROR' }, 502);
  }
  if (error.message.includes('DEVICE_BUSY')) {
    return context.json({ error: 'DEVICE_BUSY' }, 409);
  }
  if (error.message.includes('UNIQUE constraint failed: device_sessions')) {
    return context.json({ error: 'SESSION_CONFLICT' }, 409);
  }
  console.error('request_failed', { name: error.name, message: error.message });
  return context.json({ error: 'INTERNAL_ERROR' }, 500);
});

export default app;
