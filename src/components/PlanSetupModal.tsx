import React, { useState } from 'react';
import type { SemesterSeason } from '../types';

interface PlanSetupModalProps {
  isOpen: boolean;
  onSubmit: (values: { planName: string; regularSemesters: number; startSeason: SemesterSeason }) => void;
}

export const PlanSetupModal: React.FC<PlanSetupModalProps> = ({ isOpen, onSubmit }) => {
  const [planName, setPlanName] = useState('Mein Studienplan');
  const [regularSemesters, setRegularSemesters] = useState(6);
  const [startSeason, setStartSeason] = useState<SemesterSeason>('winter');

  if (!isOpen) {
    return null;
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const normalizedRegularSemesters = Number.isFinite(regularSemesters)
      ? Math.max(1, Math.min(20, Math.floor(regularSemesters)))
      : 6;

    onSubmit({
      planName: planName.trim() || 'Mein Studienplan',
      regularSemesters: normalizedRegularSemesters,
      startSeason,
    });
  };

  return (
    <div className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="w-full max-w-xl rounded-2xl border border-slate-700 bg-slate-800 p-6 shadow-2xl">
        <h2 className="text-2xl font-bold text-white">Plan einrichten</h2>
        <p className="mt-2 text-sm text-slate-300">
          Lege Planname und Regelstudienzeit fest. Standard ist 6 Semester.
        </p>

        <form className="mt-6 space-y-4" onSubmit={handleSubmit}>
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-1">Planname</label>
            <input
              className="input-field"
              type="text"
              value={planName}
              onChange={(e) => setPlanName(e.target.value)}
              placeholder="z.B. Informatik B.Sc."
              maxLength={80}
              required
            />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1">Regelstudienzeit (Semester)</label>
              <input
                className="input-field"
                type="number"
                min={1}
                max={20}
                value={regularSemesters}
                onChange={(e) => {
                  const value = Number(e.target.value);
                  setRegularSemesters(Number.isFinite(value) ? value : 1);
                }}
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-300 mb-1">Startsemester</label>
              <select
                className="input-field"
                value={startSeason}
                onChange={(e) => setStartSeason(e.target.value as SemesterSeason)}
              >
                <option value="winter">Wintersemester</option>
                <option value="summer">Sommersemester</option>
              </select>
            </div>
          </div>

          <button type="submit" className="btn-primary w-full">
            Plan starten
          </button>
        </form>
      </div>
    </div>
  );
};
