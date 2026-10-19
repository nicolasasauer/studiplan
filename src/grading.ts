// ECTS and grades the same way the Flutter app handles them: decimal comma,
// half (quarter) ECTS, and the plan's grade scale.

export type GradeScaleId = 'de' | 'at' | 'free';

export interface GradeScale {
  id: GradeScaleId;
  label: string;
  /** The grades to pick from; empty for the free scale. */
  steps: number[];
}

export const GRADE_SCALES: Record<GradeScaleId, GradeScale> = {
  de: {
    id: 'de',
    label: 'Deutschland',
    steps: [1.0, 1.3, 1.7, 2.0, 2.3, 2.7, 3.0, 3.3, 3.7, 4.0],
  },
  at: { id: 'at', label: 'Österreich', steps: [1, 2, 3, 4] },
  free: { id: 'free', label: 'Frei (Zehntelschritte)', steps: [] },
};

export const normalizeGradeScale = (value: unknown): GradeScaleId =>
  value === 'at' || value === 'free' ? value : 'de';

/** `5`, `1,5`, `7,25`: decimal comma, no trailing zeros. */
export const formatDecimal = (value: number, maxDecimals = 2): string =>
  String(Number(value.toFixed(maxDecimals))).replace('.', ',');

export const formatEcts = (ects: number): string => formatDecimal(ects);

/** `1,5` and `1.5` alike; null for anything that is not a number. */
export const parseDecimal = (text: string): number | null => {
  const normalized = text.trim().replace(',', '.');
  return /^\d+(\.\d+)?$/.test(normalized) ? Number(normalized) : null;
};

/** ECTS of one lecture: above 0, at most 30, in quarter steps. */
export const parseLectureEcts = (text: string): number | string => {
  const value = parseDecimal(text);
  if (value === null || value <= 0 || value > 30) {
    return 'ECTS: Zahl von 0,25 bis 30, z. B. 5 oder 1,5';
  }
  if (Math.round(value * 4) !== value * 4) {
    return 'ECTS nur in Viertel-Schritten, z. B. 1,5 oder 2,25';
  }
  return value;
};

/** A grade as the scale writes it: `2` in Austria, `2,0` elsewhere. */
export const formatGrade = (grade: number, scale: GradeScaleId): string =>
  scale === 'at' && Number.isInteger(grade)
    ? String(grade)
    : grade.toFixed(1).replace('.', ',');

/** The grade, or a message why the scale has no such grade. */
export const parseGrade = (text: string, scaleId: GradeScaleId): number | string => {
  const value = parseDecimal(text);
  if (value === null) return 'Bitte eine Note eingeben, z. B. 2,3';
  const scale = GRADE_SCALES[scaleId];
  if (scale.steps.length === 0) {
    if (value < 1 || value > 5 || Math.round(value * 10) !== value * 10) {
      return 'Note von 1,0 bis 5,0, eine Nachkommastelle';
    }
    return Math.round(value * 10) / 10;
  }
  const step = scale.steps.find((s) => Math.abs(s - value) < 0.001);
  if (step === undefined) {
    return `Gibt es in ${scale.label} nicht. Möglich: ${scale.steps
      .map((s) => formatGrade(s, scaleId))
      .join(', ')}`;
  }
  return step;
};

export const normalizeStartYear = (value: unknown): number | null =>
  typeof value === 'number' && Number.isFinite(value) &&
  value >= 1990 && value <= 2100
    ? Math.floor(value)
    : null;

/** `WS 2025/26`, `SS 2026`, or just `WS`/`SS` without a start year. */
export const termLabel = (
  number: number,
  season: 'winter' | 'summer',
  startSeason: 'winter' | 'summer',
  startYear: number | null | undefined,
): string => {
  const short = season === 'winter' ? 'WS' : 'SS';
  if (startYear == null) return short;
  // Half-years since year 0: summer of Y is 2Y, winter of Y is 2Y + 1.
  const half = 2 * startYear + (startSeason === 'winter' ? 1 : 0) + number - 1;
  const year = Math.floor(half / 2);
  return half % 2 === 1
    ? `${short} ${year}/${String((year + 1) % 100).padStart(2, '0')}`
    : `${short} ${year}`;
};

/**
 * `focusflow://studiplan?plan=…`: the semester in the plan layout, as the
 * Flutter app's "An Focus Flow übergeben" sends it.
 */
export const focusFlowLink = (json: string): string => {
  const bytes = new TextEncoder().encode(json);
  let binary = '';
  bytes.forEach((b) => {
    binary += String.fromCharCode(b);
  });
  const base64url = btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
  return `focusflow://studiplan?plan=${base64url}`;
};
