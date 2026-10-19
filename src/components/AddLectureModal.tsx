import React, { useState } from 'react';
import { X } from 'lucide-react';
import type { Lecture } from '../types';
import { COLORS } from '../types';
import { useStudyPlanStore } from '../store';
import {
  GRADE_SCALES,
  formatEcts,
  formatGrade,
  parseGrade,
  parseLectureEcts,
} from '../grading';

interface AddLectureModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialLecture?: Lecture;
}

const getInitialFormData = (initialLecture?: Lecture): Omit<Lecture, 'id'> => {
  if (initialLecture) {
    return {
      name: initialLecture.name,
      ects: initialLecture.ects,
      examDate: initialLecture.examDate,
      season: initialLecture.season,
      description: initialLecture.description,
      color: initialLecture.color,
      passed: initialLecture.passed,
      grade: initialLecture.grade,
      oralExam: initialLecture.oralExam,
    };
  }

  return {
    name: '',
    ects: 3,
    examDate: '',
    season: 'both',
    description: '',
    color: COLORS[0],
    passed: false,
    grade: undefined,
    oralExam: false,
  };
};

export const AddLectureModal: React.FC<AddLectureModalProps> = ({ isOpen, onClose, initialLecture }) => {
  const [formData, setFormData] = useState<Omit<Lecture, 'id'>>(() => getInitialFormData(initialLecture));
  const scaleId = useStudyPlanStore(state => state.gradeScale ?? 'de');
  const scale = GRADE_SCALES[scaleId];
  // Typed as text, so "1,5" and "2,3" work with a German keyboard.
  const [ectsText, setEctsText] = useState(() => formatEcts(formData.ects));
  const [gradeText, setGradeText] = useState(() =>
    formData.grade != null ? formatGrade(formData.grade, scaleId) : '');
  const [error, setError] = useState<string | null>(null);

  const addLecture = useStudyPlanStore(state => state.addLecture);
  const updateLecture = useStudyPlanStore(state => state.updateLecture);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.name) {
      setError('Bitte einen Namen eingeben');
      return;
    }

    const ects = parseLectureEcts(ectsText);
    if (typeof ects === 'string') {
      setError(ects);
      return;
    }

    let grade: number | undefined;
    if (formData.passed && gradeText.trim() !== '') {
      // A grade saved earlier (e.g. 2,1) stays valid as it is.
      const saved = initialLecture?.grade;
      const parsed = saved != null && gradeText.trim() === formatGrade(saved, scaleId)
        ? saved
        : parseGrade(gradeText, scaleId);
      if (typeof parsed === 'string') {
        setError(parsed);
        return;
      }
      grade = parsed;
    }

    if (initialLecture) {
      updateLecture(initialLecture.id, { ...formData, ects, grade });
    } else {
      const newLecture: Lecture = {
        id: crypto.randomUUID(),
        ...formData,
        ects,
        grade,
      };
      addLecture(newLecture);
    }

    onClose();
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4 overflow-y-auto">
      <div className="bg-slate-800 rounded-lg p-6 w-full max-w-md border border-slate-700 shadow-2xl my-auto overflow-y-auto max-h-[calc(100vh-2rem)]">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-2xl font-bold text-white">
            {initialLecture ? 'Veranstaltung bearbeiten' : 'Neue Veranstaltung'}
          </h2>
          <button
            onClick={onClose}
            className="p-1 text-gray-400 hover:text-white transition-colors"
          >
            <X size={24} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1">Name *</label>
            <input
              type="text"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              placeholder="z.B. Mathematik I"
              className="input-field"
              maxLength={200}
              required
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1">ECTS *</label>
              <input
                type="text"
                inputMode="decimal"
                value={ectsText}
                onChange={(e) => setEctsText(e.target.value)}
                placeholder="z.B. 5 oder 1,5"
                className="input-field"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1">Turnus der Veranstaltung</label>
              <select
                value={formData.season}
                onChange={(e) => setFormData({ ...formData, season: e.target.value as 'winter' | 'summer' | 'both' })}
                className="input-field"
              >
                <option value="winter">Wintersemester</option>
                <option value="summer">Sommersemester</option>
                <option value="both">Beide</option>
              </select>
              <p className="mt-1 text-xs text-slate-400">
                Hinweis: Das ist nur eine Empfehlung. Klausuren koennen trotzdem in jedem Semester geplant werden.
              </p>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1">Klausurdatum <span className="text-gray-500">(optional)</span></label>
            <input
              type="date"
              value={formData.examDate ?? ''}
              onChange={(e) => setFormData({ ...formData, examDate: e.target.value || undefined })}
              className="input-field"
            />
          </div>

          <div className="space-y-3">
            <div className="flex items-center gap-3">
              <input
                type="checkbox"
                id="passed"
                checked={!!formData.passed}
                onChange={(e) => {
                  const grade = e.target.checked
                    ? (formData.oralExam ? (formData.grade ?? 4.0) : formData.grade)
                    : undefined;
                  setFormData({ ...formData, passed: e.target.checked, grade });
                  setGradeText(grade != null ? formatGrade(grade, scaleId) : '');
                }}
                className="w-4 h-4 rounded accent-blue-500 cursor-pointer"
              />
              <label htmlFor="passed" className="text-sm font-medium text-gray-300 cursor-pointer">
                {formData.oralExam ? 'Mündliche Prüfung bestanden' : 'Klausur bestanden'}
              </label>
            </div>
            {formData.passed && (
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1">
                  {formData.oralExam ? 'Note Mündliche Prüfung' : 'Note'} <span className="text-gray-500">(optional, {scale.label})</span>
                </label>
                {scale.steps.length > 0 && (
                  <div className="flex flex-wrap gap-1.5 mb-2">
                    {scale.steps.map((step) => {
                      const text = formatGrade(step, scaleId);
                      const selected = gradeText.trim() === text;
                      return (
                        <button
                          key={step}
                          type="button"
                          onClick={() => setGradeText(text)}
                          className={`px-2.5 py-1 rounded text-sm transition-colors ${
                            selected
                              ? 'bg-purple-600 text-white'
                              : 'bg-slate-600 text-gray-300 hover:bg-slate-500'
                          }`}
                        >
                          {text}
                        </button>
                      );
                    })}
                  </div>
                )}
                <input
                  type="text"
                  inputMode="decimal"
                  value={gradeText}
                  onChange={(e) => setGradeText(e.target.value)}
                  placeholder={scaleId === 'at' ? 'z.B. 2' : 'z.B. 1,7'}
                  className="input-field"
                />
              </div>
            )}
            {!formData.passed && (
              <div className="flex items-center gap-3 pl-1">
                <input
                  type="checkbox"
                  id="oralExam"
                  checked={!!formData.oralExam}
                  onChange={(e) => setFormData({ ...formData, oralExam: e.target.checked })}
                  className="w-4 h-4 rounded accent-orange-500 cursor-pointer"
                />
                <label htmlFor="oralExam" className="text-sm text-gray-300 cursor-pointer">
                  Mündliche Prüfung
                </label>
              </div>
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1">Beschreibung</label>
            <textarea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              placeholder="Optionale Beschreibung..."
              className="input-field min-h-[80px] resize-none"
              maxLength={1000}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">Farbe</label>
            <div className="grid grid-cols-5 gap-2">
              {COLORS.map((color) => (
                <button
                  key={color}
                  type="button"
                  onClick={() => setFormData({ ...formData, color })}
                  className={`w-8 h-8 rounded-lg transition-transform ${
                    formData.color === color ? 'ring-2 ring-white scale-110' : ''
                  }`}
                  style={{ backgroundColor: color }}
                  title={color}
                />
              ))}
            </div>
          </div>

          {error && (
            <p className="text-sm text-red-400" role="alert">{error}</p>
          )}

          <div className="flex gap-3 mt-6">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 btn-secondary"
            >
              Abbrechen
            </button>
            <button
              type="submit"
              className="flex-1 btn-primary"
            >
              {initialLecture ? 'Aktualisieren' : 'Hinzufügen'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
