'use client';

import { useEffect, useMemo, useState, type CSSProperties } from 'react';
import {
  AlertTriangle,
  Check,
  ChevronDown,
  CircleStop,
  Database,
  FileJson,
  Info,
  Minus,
  Plus,
  ShieldCheck,
  UserRound,
  WifiOff,
} from 'lucide-react';
import {
  ALGORITHM_VERSION,
  PILOT_RULES,
  averageMeasurements,
  calculateVibrationRecommendation,
  createMockCommand,
  type BodyCompositionMeasurement,
  type Profile,
  type SafetyAnswers,
} from '@/app/algorithm/vibration-algorithm';

const mockMeasurements: BodyCompositionMeasurement[] = [
  { id: 'M-001', userId: 'USER-001', measuredAt: '2026-08-22T23:20:00+09:00', deviceId: 'FITRUS-PLUS-01', qualityPassed: true, weightKg: 42, bmi: 18.7, bodyFatPct: 18.8, fatMassKg: 7.9, skeletalMuscleMassKg: 18.1, basalMetabolicRateKcal: 1106.1, bodyWaterPct: 59.7, proteinKg: 6.7, mineralKg: 2.4, ecwRatio: 0.38, waistCm: 61.8, visceralFatLevel: 8.51 },
  { id: 'M-002', userId: 'USER-001', measuredAt: '2026-08-23T09:10:00+09:00', deviceId: 'FITRUS-PLUS-01', qualityPassed: true, weightKg: 42.2, bmi: 18.8, bodyFatPct: 18.7, fatMassKg: 7.9, skeletalMuscleMassKg: 18, basalMetabolicRateKcal: 1108, bodyWaterPct: 59.5, proteinKg: 6.7, mineralKg: 2.4, ecwRatio: 0.381, waistCm: 61.9, visceralFatLevel: 8.5 },
  { id: 'M-003', userId: 'USER-001', measuredAt: '2026-08-24T09:05:00+09:00', deviceId: 'FITRUS-PLUS-01', qualityPassed: true, weightKg: 41.9, bmi: 18.6, bodyFatPct: 19.1, fatMassKg: 8, skeletalMuscleMassKg: 18.2, basalMetabolicRateKcal: 1105, bodyWaterPct: 59.4, proteinKg: 6.7, mineralKg: 2.4, ecwRatio: 0.379, waistCm: 61.7, visceralFatLevel: 8.54 },
  { id: 'M-004', userId: 'USER-001', measuredAt: '2026-08-25T09:12:00+09:00', deviceId: 'FITRUS-PLUS-01', qualityPassed: true, weightKg: 42.1, bmi: 18.7, bodyFatPct: 18.9, fatMassKg: 8, skeletalMuscleMassKg: 18.1, basalMetabolicRateKcal: 1107, bodyWaterPct: 59.6, proteinKg: 6.7, mineralKg: 2.4, ecwRatio: 0.38, waistCm: 61.8, visceralFatLevel: 8.52 },
];

type SafetyDraft = Record<keyof SafetyAnswers, boolean | null>;
type SafetyKey = keyof SafetyAnswers;

const safeAnswers: SafetyAnswers = { acutePain: false, dizziness: false, clinicianHold: false };
const safetyQuestions: { key: SafetyKey; title: string; hint: string }[] = [
  { key: 'acutePain', title: '심한 통증이 있습니까?', hint: '평소와 다른 통증 포함' },
  { key: 'dizziness', title: '어지럽거나 중심 잡기가 어렵습니까?', hint: '잠깐의 어지럼 포함' },
  { key: 'clinicianHold', title: '담당자가 사용을 미루라고 했습니까?', hint: '의료진·연구 담당자 안내' },
];

const formatNumber = (value: number | null | undefined) =>
  value == null ? '—' : new Intl.NumberFormat('ko-KR', { maximumFractionDigits: 1 }).format(value);

const formatDate = (value: string) =>
  new Intl.DateTimeFormat('ko-KR', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' }).format(new Date(value));

export default function Home() {
  const [profile, setProfile] = useState<Profile>({ userId: 'USER-001', age: 72, sex: 'female', heightCm: 150 });
  const [safetyDraft, setSafetyDraft] = useState<SafetyDraft>({ acutePain: null, dizziness: null, clinicianHold: null });
  const [commandPreview, setCommandPreview] = useState('');
  const [largeText, setLargeText] = useState(false);

  const aggregation = useMemo(() => averageMeasurements(profile, mockMeasurements), [profile]);
  const calculation = useMemo(
    () => calculateVibrationRecommendation(profile, mockMeasurements, safeAnswers),
    [profile],
  );
  const safetyComplete = Object.values(safetyDraft).every((value) => value !== null);
  const safety = useMemo<SafetyAnswers>(() => ({
    acutePain: safetyDraft.acutePain === true,
    dizziness: safetyDraft.dizziness === true,
    clinicianHold: safetyDraft.clinicianHold === true,
  }), [safetyDraft.acutePain, safetyDraft.dizziness, safetyDraft.clinicianHold]);
  const execution = useMemo(
    () => calculateVibrationRecommendation(profile, mockMeasurements, safety),
    [profile, safety],
  );

  useEffect(() => {
    if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').catch(() => undefined);
  }, []);

  const preview = execution.status === 'BLOCKED' ? null : calculation.recommendation;
  const adjustments = calculation.adjustments;
  const ageFactor = adjustments.find((item) => item.id === 'AGE_70_PILOT')?.factor ?? 1;
  const sexFactor = adjustments.find((item) => item.id === 'SEX_RESPONSE_PILOT')?.factor ?? 1;
  const bodyFatFactor = adjustments.find((item) => item.id === 'BODY_FAT_RANGE_PILOT')?.factor ?? 1;
  const status = execution.status === 'BLOCKED' ? 'BLOCKED' : !safetyComplete ? 'REVIEW' : execution.status;
  const canCreateCommand = safetyComplete && execution.status === 'READY' && Boolean(execution.recommendation);
  const unansweredCount = Object.values(safetyDraft).filter((value) => value === null).length;

  const statusText = status === 'READY'
    ? { label: '사용 가능', description: '안전 문진과 데이터 검증을 통과했습니다.', icon: <Check aria-hidden="true" /> }
    : status === 'BLOCKED'
      ? { label: '사용 중지', description: '위험 응답이 있어 명령 생성을 차단했습니다.', icon: <CircleStop aria-hidden="true" /> }
      : { label: '안전 확인 전', description: safetyComplete ? '측정값을 담당자가 확인해야 합니다.' : `문진 ${unansweredCount}개에 답해야 실행할 수 있습니다.`, icon: <AlertTriangle aria-hidden="true" /> };

  const setSafetyAnswer = (key: SafetyKey, value: boolean) => {
    setSafetyDraft((current) => ({ ...current, [key]: value }));
    setCommandPreview('');
  };

  const updateProfile = (nextProfile: Profile) => {
    setProfile(nextProfile);
    setCommandPreview('');
  };

  const createPreview = () => {
    if (!canCreateCommand) return;
    setCommandPreview(JSON.stringify(createMockCommand(profile, execution), null, 2));
  };

  return (
    <main className={largeText ? 'product-shell large-text' : 'product-shell'}>
      <a className="skip-link" href="#calculator">계산 화면으로 바로가기</a>

      <header className="app-bar">
        <div className="app-bar-inner">
          <div className="product-identity">
            <span className="product-symbol" aria-hidden="true">V</span>
            <div><strong>VibeCare</strong><span>오늘의 진동 설정</span></div>
          </div>
          <div className="app-utilities">
            <span className="demo-state"><i aria-hidden="true"></i>시연 데이터</span>
            <span className="participant">참여자 {profile.userId}</span>
            <div className="font-size-control" aria-label="글자 크기">
              <button type="button" aria-label="기본 글자" aria-pressed={!largeText} onClick={() => setLargeText(false)}><Minus aria-hidden="true" /></button>
              <button type="button" aria-label="큰 글자" aria-pressed={largeText} onClick={() => setLargeText(true)}><Plus aria-hidden="true" /></button>
            </div>
          </div>
        </div>
      </header>

      <div className="page-heading">
        <div><p>2026년 8월 25일</p><h1>진동 설정 계산</h1></div>
        <p className="connection-state"><WifiOff aria-hidden="true" />실제 기기 미연결</p>
      </div>

      <div id="calculator" className="calculator-grid">
        <section className="calculation-card" aria-labelledby="calculation-title">
          <div className="section-title-row">
            <div><p className="eyebrow">실시간 알고리즘</p><h2 id="calculation-title">입력값이 바뀌면 바로 계산됩니다</h2></div>
            <span className="version">{ALGORITHM_VERSION}</span>
          </div>

          <div className="formula" aria-label={`기본 강도 ${PILOT_RULES.base.intensityPct}% 곱하기 연령계수 ${ageFactor.toFixed(2)} 곱하기 성별계수 ${sexFactor.toFixed(2)} 곱하기 체지방계수 ${bodyFatFactor.toFixed(2)}`}>
            <FormulaItem label="기본 강도" value={`${PILOT_RULES.base.intensityPct}%`} detail="파일럿 시작값" />
            <FormulaOperator />
            <FormulaItem label="연령" value={`× ${ageFactor.toFixed(2)}`} detail={`${profile.age}세`} adjusted={ageFactor < 1} />
            <FormulaOperator />
            <FormulaItem label="성별" value={`× ${sexFactor.toFixed(2)}`} detail={profile.sex === 'female' ? '여성' : '남성'} adjusted={sexFactor < 1} />
            <FormulaOperator />
            <FormulaItem label="체지방" value={`× ${bodyFatFactor.toFixed(2)}`} detail={`${formatNumber(aggregation.averagedValues?.bodyFatPct)}% 평균`} adjusted={bodyFatFactor < 1} />
          </div>

          <details className="profile-editor">
            <summary><div className="mini-section-heading"><UserRound aria-hidden="true" /><div><h3 id="profile-title">계산 조건 수정</h3><p>{profile.age}세 · {profile.sex === 'female' ? '여성' : '남성'} · {profile.heightCm}cm</p></div></div><span>열기 <ChevronDown aria-hidden="true" /></span></summary>
            <div className="profile-fields">
              <label htmlFor="profile-age">나이<InputWithUnit id="profile-age" value={profile.age} unit="세" min={18} max={110} onChange={(age) => updateProfile({ ...profile, age })} /></label>
              <label htmlFor="profile-sex">성별<select id="profile-sex" value={profile.sex} onChange={(event) => updateProfile({ ...profile, sex: event.target.value as Profile['sex'] })}><option value="female">여성</option><option value="male">남성</option></select></label>
              <label htmlFor="profile-height">키<InputWithUnit id="profile-height" value={profile.heightCm} unit="cm" min={120} max={220} onChange={(heightCm) => updateProfile({ ...profile, heightCm })} /></label>
            </div>
          </details>
        </section>

        <aside className={`result-card result-${status.toLowerCase()}`} aria-labelledby="result-title">
          <output className="safety-status" aria-live="polite">
            <span>{statusText.icon}</span><div><strong>{statusText.label}</strong><p>{statusText.description}</p></div>
          </output>
          <div className="result-heading"><p>계산 미리보기</p><h2 id="result-title">권장 진동 세기</h2></div>
          {preview ? (
            <>
              <div className="intensity-gauge" style={{ '--intensity': `${preview.intensityPct}%` } as CSSProperties} aria-label={`권장 진동 세기 ${preview.intensityPct}%`}>
                <div><strong>{preview.intensityPct}</strong><span>%</span></div>
              </div>
              <p className="formula-summary">50 × {ageFactor.toFixed(2)} × {sexFactor.toFixed(2)} × {bodyFatFactor.toFixed(2)} = <strong>{preview.intensityPct}%</strong></p>
              <dl className="secondary-results"><div><dt>사용 시간</dt><dd>{preview.durationSec / 60}<span>분</span></dd></div><div><dt>주파수</dt><dd>{preview.frequencyHz}<span>Hz</span></dd></div></dl>
            </>
          ) : (
            <div className="result-unavailable"><AlertTriangle aria-hidden="true" /><p>입력 데이터 검토가 필요해 계산값을 표시할 수 없습니다.</p></div>
          )}
          <p className="preview-caution"><Info aria-hidden="true" />계산값은 실행 허가가 아니며 연구용 파일럿 기준입니다.</p>
          <button type="button" className="command-button" disabled={!canCreateCommand || Boolean(commandPreview)} onClick={createPreview}>
            <FileJson aria-hidden="true" />{commandPreview ? 'Mock 명령 생성됨' : canCreateCommand ? 'Mock 명령 확인하기' : '안전 확인 후 사용할 수 있습니다'}
          </button>
        </aside>
      </div>

      <div className="support-grid">
        <section className="data-section" aria-labelledby="measurement-title">
          <div className="section-title-row compact-title">
            <div className="mini-section-heading"><Database aria-hidden="true" /><div><p className="eyebrow">API 입력</p><h2 id="measurement-title">최근 측정 4건 평균</h2></div></div>
            <span className="data-valid"><Check aria-hidden="true" />4건 검증 완료</span>
          </div>
          <div className="measurement-summary">
            <Metric label="체중" value={formatNumber(aggregation.averagedValues?.weightKg)} unit="kg" />
            <Metric label="체지방률" value={formatNumber(aggregation.averagedValues?.bodyFatPct)} unit="%" accent />
            <Metric label="골격근량" value={formatNumber(aggregation.averagedValues?.skeletalMuscleMassKg)} unit="kg" />
            <Metric label="BMI" value={formatNumber(aggregation.averagedValues?.bmi)} unit="" />
          </div>
          <details className="details-block">
            <summary>평균에 사용한 원본 4건 보기 <ChevronDown aria-hidden="true" /></summary>
            <div className="table-scroll"><table><caption className="sr-only">평균 계산에 사용한 Mock 체성분 측정값</caption><thead><tr><th>측정</th><th>체중</th><th>체지방</th><th>골격근</th><th>BMI</th></tr></thead><tbody>{mockMeasurements.map((item) => <tr key={item.id}><th>{formatDate(item.measuredAt)}</th><td>{item.weightKg} kg</td><td>{item.bodyFatPct}%</td><td>{item.skeletalMuscleMassKg} kg</td><td>{item.bmi}</td></tr>)}</tbody></table></div>
          </details>
        </section>

        <section className="safety-section" aria-labelledby="safety-title">
          <div className="mini-section-heading"><ShieldCheck aria-hidden="true" /><div><p className="eyebrow">실행 전 확인</p><h2 id="safety-title">오늘 몸 상태</h2></div></div>
          <p className="section-description">세 문항에 모두 답해야 Mock 명령을 만들 수 있습니다.</p>
          <div className="safety-list">
            {safetyQuestions.map((question) => (
              <fieldset key={question.key}>
                <legend>{question.title}<span>{question.hint}</span></legend>
                <div className="radio-pair">
                  <label><input type="radio" name={question.key} checked={safetyDraft[question.key] === false} onChange={() => setSafetyAnswer(question.key, false)} /><span>아니요</span></label>
                  <label><input type="radio" name={question.key} checked={safetyDraft[question.key] === true} onChange={() => setSafetyAnswer(question.key, true)} /><span>예</span></label>
                </div>
              </fieldset>
            ))}
          </div>
        </section>
      </div>

      {commandPreview && (
        <output className="command-preview" aria-live="polite">
          <div><span><Check aria-hidden="true" /></span><div><h2>Mock 명령을 만들었습니다</h2><p>외부 서버나 실제 진동기로 전송하지 않았습니다.</p></div></div>
          <details className="details-block"><summary>개발 확인용 JSON <ChevronDown aria-hidden="true" /></summary><pre>{commandPreview}</pre></details>
        </output>
      )}

      {(calculation.dataWarnings.length > 0 || (safetyComplete && execution.safetyWarnings.length > 0)) && (
        <div className="warning-area" role="alert">{[...calculation.dataWarnings, ...(safetyComplete ? execution.safetyWarnings : [])].map((warning) => <p key={warning}><AlertTriangle aria-hidden="true" />{warning}</p>)}</div>
      )}

      <footer className="app-footer"><p><strong>VibeCare Pilot</strong> · 실제 FITRUS 및 진동기 연동 전 화면</p><p>알고리즘 {ALGORITHM_VERSION}</p></footer>
    </main>
  );
}

function FormulaItem({ label, value, detail, adjusted = false }: { label: string; value: string; detail: string; adjusted?: boolean }) {
  return <div className={adjusted ? 'formula-item adjusted' : 'formula-item'}><span>{label}</span><strong>{value}</strong><small>{detail}</small></div>;
}

function FormulaOperator() {
  return <span className="formula-operator" aria-hidden="true">×</span>;
}

function InputWithUnit({ id, value, unit, min, max, onChange }: { id: string; value: number; unit: string; min: number; max: number; onChange: (value: number) => void }) {
  return <span className="input-with-unit"><input id={id} type="number" min={min} max={max} value={value} onChange={(event) => onChange(Number(event.target.value))} /><span>{unit}</span></span>;
}

function Metric({ label, value, unit, accent = false }: { label: string; value: string; unit: string; accent?: boolean }) {
  return <div className={accent ? 'metric accent' : 'metric'}><span>{label}</span><p><strong>{value}</strong>{unit && <small>{unit}</small>}</p></div>;
}
