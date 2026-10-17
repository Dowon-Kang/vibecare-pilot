import { describe, expect, it, vi } from 'vitest';
import { createMeasurementUploader, type ExternalMeasurement } from '../../shared-contracts/external-measurement-client.js';
const event: ExternalMeasurement = {schemaVersion:1,eventId:'00000000-0000-4000-8000-000000000001',
 sourceId:'SYNTHETIC-ONLY',deviceId:'SYNTHETIC-DEVICE',measuredAt:'2026-10-17T00:00:00Z',
 values:{weightKg:60,bodyFatPct:25,fatMassKg:15,muscleKg:20}};
const session={ownerId:'SYNTHETIC-ACCOUNT-A',accessToken:'SYNTHETIC-TOKEN'};
const receipt={measurementId:'EXT-SYNTHETIC-RECEIPT',duplicate:false,status:'stored'};
const config={supabaseUrl:'https://example.supabase.co',publishableKey:'sb_publishable_test'};
describe('external app uploader',()=>{
 it('binds upload to measurement-start owner and sends identity only in authorization',async()=>{
  let captured:RequestInit|undefined;
  const send=vi.fn(async(url:RequestInfo|URL,init?:RequestInit)=>{expect(String(url)).toBe('https://example.supabase.co/rest/v1/rpc/submit_external_measurement');captured=init;return Response.json(receipt);});
  const upload=createMeasurementUploader({...config,getSession:async()=>session,fetcher:send});
  expect(await upload(session.ownerId,event)).toEqual(receipt);
  expect(JSON.parse(String(captured?.body))).toEqual({p_payload:event});
  expect(captured?.redirect).toBe('error');
  expect(new Headers(captured?.headers).get('Authorization')).toBe('Bearer SYNTHETIC-TOKEN');
 });
 it('never sends a queued event under a new login',async()=>{
  const send=vi.fn();const upload=createMeasurementUploader({...config,getSession:async()=>({...session,ownerId:'B'}),fetcher:send});
  await expect(upload(session.ownerId,event)).rejects.toMatchObject({code:'ACCOUNT_CHANGED'});expect(send).not.toHaveBeenCalled();
 });
 it('discards a late response after logout',async()=>{
  let reads=0;const upload=createMeasurementUploader({...config,getSession:async()=>++reads===1?session:null,fetcher:async()=>Response.json(receipt)});
  await expect(upload(session.ownerId,event)).rejects.toMatchObject({code:'ACCOUNT_CHANGED'});
 });
 it('accepts a server duplicate receipt on explicit retry',async()=>{
  const upload=createMeasurementUploader({...config,getSession:async()=>session,fetcher:async()=>Response.json({...receipt,duplicate:true})});
  expect((await upload(session.ownerId,event)).duplicate).toBe(true);
 });
 it('exposes a safe configuration error with no automatic retry',async()=>{
  const send=vi.fn(async()=>Response.json({message:'SOURCE_NOT_READY',code:'PT503'},{status:503}));
  const upload=createMeasurementUploader({...config,getSession:async()=>session,fetcher:send});
  await expect(upload(session.ownerId,event)).rejects.toMatchObject({code:'SOURCE_NOT_READY',status:503});expect(send).toHaveBeenCalledTimes(1);
 });
 it('does not echo server payload or secrets',async()=>{
  const upload=createMeasurementUploader({...config,getSession:async()=>session,fetcher:async()=>Response.json({message:'private payload'},{status:500})});
  await expect(upload(session.ownerId,event)).rejects.toMatchObject({message:'UPLOAD_FAILED'});
 });
 it('rejects cancelled calls and insecure destinations before sending',async()=>{
  const send=vi.fn();const controller=new AbortController();controller.abort();
  const upload=createMeasurementUploader({...config,getSession:async()=>session,fetcher:send});
  await expect(upload(session.ownerId,event,controller.signal)).rejects.toMatchObject({code:'UPLOAD_CANCELLED'});expect(send).not.toHaveBeenCalled();
  expect(()=>createMeasurementUploader({...config,supabaseUrl:'http://example.com',getSession:async()=>session})).toThrow('INVALID_SERVER_URL');
 });
});
