import { z } from 'zod';

const positive = z.number().positive();
export const calibrationSchema = z.object({
  deviceId:z.string().min(1), calibrationVersion:z.string().min(1),
  approvedProtocolId:z.string().min(1), expiresAt:z.iso.datetime(),
  deviceType:z.literal('whole_body_platform'), waveform:z.literal('sinusoidal'),
  posture:z.string().min(1), contact:z.string().min(1),
  loadMinKg:positive, loadMaxKg:positive,
  limits:z.object({peakG:positive, rmsG:positive, durationSec:positive}),
  points:z.array(z.object({
    frequencyHz:positive, intensityPct:z.number().min(0).max(100),
    peakToPeakDisplacementMm:positive, measuredPeakG:positive, measuredRmsG:positive,
    uncertaintyG:z.number().nonnegative(),
  })).min(1),
}).refine(v=>v.loadMinKg <= v.loadMaxKg);

// A bench-calibration check, not clinical approval or a hardware start operation.
export function checkCalibration(raw:unknown, command:{deviceId:string;frequencyHz:number;intensityPct:number;durationSec:number},
  context:{now:string;posture:string;contact:string;loadKg:number}) {
  const reject=(reasonCode:string)=>({allowed:false as const,reasonCode});
  const parsed=calibrationSchema.safeParse(raw);
  if(!parsed.success) return reject('CALIBRATION_REQUIRED');
  const c=parsed.data;
  if(!Number.isFinite(Date.parse(context.now)) || Date.parse(c.expiresAt)<=Date.parse(context.now)) return reject('CALIBRATION_EXPIRED');
  if(c.deviceId!==command.deviceId || c.posture!==context.posture || c.contact!==context.contact ||
     !Number.isFinite(context.loadKg) || context.loadKg<c.loadMinKg || context.loadKg>c.loadMaxKg) return reject('CALIBRATION_CONTEXT_MISMATCH');
  if(!Number.isFinite(command.durationSec) || command.durationSec<=0 || command.durationSec>c.limits.durationSec) return reject('DURATION_LIMIT');
  const matches=c.points.filter(p=>p.frequencyHz===command.frequencyHz && p.intensityPct===command.intensityPct);
  if(matches.length!==1) return reject('CALIBRATION_POINT_MISSING_OR_AMBIGUOUS');
  const p=matches[0];
  const theoreticalPeakG=(2*Math.PI*p.frequencyHz)**2*(p.peakToPeakDisplacementMm/2000)/9.80665;
  const theoreticalRmsG=theoreticalPeakG/Math.sqrt(2);
  if(Math.abs(p.measuredPeakG-theoreticalPeakG)>p.uncertaintyG ||
     Math.abs(p.measuredRmsG-theoreticalRmsG)>p.uncertaintyG) return reject('CALIBRATION_INCONSISTENT');
  if(p.measuredPeakG+p.uncertaintyG>c.limits.peakG || p.measuredRmsG+p.uncertaintyG>c.limits.rmsG) return reject('ACCELERATION_LIMIT');
  return {allowed:true as const,reasonCode:'BENCH_CALIBRATION_ONLY',calibrationVersion:c.calibrationVersion,
    peakToPeakDisplacementMm:p.peakToPeakDisplacementMm,peakAccelerationG:p.measuredPeakG,
    rmsAccelerationG:p.measuredRmsG,uncertaintyG:p.uncertaintyG,theoreticalPeakG,theoreticalRmsG};
}
