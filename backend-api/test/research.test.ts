import {readFileSync} from 'node:fs';
import {expect,it} from 'vitest';
import {calculateRecommendation,defaultRuleSet} from '../src/algorithm';
import {feedbackAdjustment} from '../src/feedback';
const f=JSON.parse(readFileSync(new URL('../../shared-contracts/fixtures/pilot-0.6.0-boundaries.json',import.meta.url),'utf8'));
type Case={id:string;sex:'female'|'male';age:number;bmi:number;muscles:number[];dizziness?:boolean;status:string;tier:'low'|'medium'|'reference'|null;executionStatus:string};
for(const c of f.cases as Case[]) it('shared precision and parity: '+c.id,()=>{
  const profile={participantId:'TEST',sex:c.sex,age:c.age,heightCm:f.heightCm};
  const measurements=c.muscles.map((m,i)=>({id:'M'+i,participantId:'TEST',deviceId:'BIA',qualityPassed:true,weightKg:c.bmi*4,bmi:c.bmi,bodyFatPct:25,fatMassKg:c.bmi,skeletalMuscleMassKg:m}));
  const safety={acutePain:false,dizziness:c.dizziness??false,clinicianHold:false};
  const server=calculateRecommendation({profile,measurements,safety});
  expect(server.status).toBe(c.status);expect(server.executionStatus).toBe(c.executionStatus);
  expect(server.muscleAssessment?.level??null).toBe(c.tier);
  expect(server.realDeviceSendAllowed).toBe(false);
  if(c.tier){const expected={low:[180,12,30],medium:[240,16,40],reference:[300,20,50]}[c.tier]!;
    expect([server.recommendation?.durationSec,server.recommendation?.frequencyHz,server.recommendation?.intensityPct]).toEqual(expected);}
});
it('fails closed for rule version, mutation, non-finite input and ownership',()=>{
  const profile={participantId:'T',sex:'female' as const,age:72,heightCm:150};
  const rows=Array.from({length:4},(_,i)=>({id:'M'+i,participantId:'T',deviceId:'D',qualityPassed:true,weightKg:45,bmi:20,bodyFatPct:25,fatMassKg:11.25,skeletalMuscleMassKg:18}));
  const safety={acutePain:false,dizziness:false,clinicianHold:false};
  for(const measurements of [rows.map(m=>({...m,deviceId:m.id})),rows.map(m=>({...m,participantId:'OTHER'})),rows.map(m=>({...m,id:'same'})),rows.map(m=>({...m,skeletalMuscleMassKg:NaN}))])
    expect(calculateRecommendation({profile,measurements,safety}).recommendation).toBeNull();
  for(const heightCm of [0,NaN,Infinity,99,251]) expect(calculateRecommendation({profile:{...profile,heightCm},measurements:rows,safety}).recommendation).toBeNull();
  for(const ruleSet of [{...defaultRuleSet,version:'pilot-0.5.0'},{...defaultRuleSet,enabled:false},{...defaultRuleSet,age:{threshold:70,factor:.9}}]) expect(calculateRecommendation({profile,measurements:rows,safety,ruleSet}).recommendation).toBeNull();
});
it('feedback decreases only intensity and holds other discomforts',()=>{
  const clear={rpe:2,pain:0,dizziness:false};
  expect(feedbackAdjustment({...clear,intensityRating:'strong'},50).intensityCap).toBe(45);
  expect(feedbackAdjustment({...clear,intensityRating:'weak'},50,40).intensityCap).toBe(40);
  for(const extra of [{durationRating:'strong'},{frequencyRating:'strong'},{earlyStopped:true},{pain:1},{dizziness:true}]) expect(feedbackAdjustment({...clear,...extra},50).requiresReview).toBe(true);
});
