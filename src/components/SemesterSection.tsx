import React, { useState } from 'react';
import { Droppable } from 'react-beautiful-dnd';
import { ChevronDown, Trash2, ArrowDown, ArrowUp, CheckCircle2, Send } from 'lucide-react';
import type { Semester } from '../types';
import { useStudyPlanStore } from '../store';
import { LectureCard } from './LectureCard';
import { focusFlowLink, formatEcts, termLabel } from '../grading';

interface SemesterSectionProps {
  semester: Semester;
  onEdit: (lectureId: string) => void;
  externalCollapsed?: boolean | null;
}

export const SemesterSection: React.FC<SemesterSectionProps> = ({ semester, onEdit, externalCollapsed }) => {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [prevExternalCollapsed, setPrevExternalCollapsed] = useState(externalCollapsed);
  const [sortBy, setSortBy] = useState<'date' | 'ects' | null>(null);

  // Sync external collapse command without useEffect (derived-state pattern)
  if (externalCollapsed !== prevExternalCollapsed && externalCollapsed != null) {
    setPrevExternalCollapsed(externalCollapsed);
    setIsCollapsed(externalCollapsed);
  }
  const removeSemester = useStudyPlanStore(state => state.removeSemester);
  const sortSemesterLectures = useStudyPlanStore(state => state.sortSemesterLectures);
  const planName = useStudyPlanStore(state => state.planName);
  const startSeason = useStudyPlanStore(state => state.startSeason);
  const startYear = useStudyPlanStore(state => state.startYear ?? null);
  const [handoffLink, setHandoffLink] = useState<string | null>(null);

  const totalEcts = semester.lectures.reduce((sum, lecture) => sum + lecture.ects, 0);
  const passedLectures = semester.lectures.filter(l => l.passed);
  const passedEcts = passedLectures.reduce((sum, l) => sum + l.ects, 0);
  const gradedLectures = passedLectures.filter(l => l.grade !== undefined);
  const avgGrade = gradedLectures.length > 0
    ? gradedLectures.reduce((sum, l) => sum + (l.grade ?? 0), 0) / gradedLectures.length
    : null;

  const handleSort = (type: 'date' | 'ects') => {
    if (sortBy === type) {
      setSortBy(null);
    } else {
      setSortBy(type);
      sortSemesterLectures(semester.id, type);
    }
  };

  const handleDelete = () => {
    if (confirm(`Möchten Sie Semester ${semester.number} wirklich löschen? Die Veranstaltungen werden in den Parkplatz verschoben.`)) {
      removeSemester(semester.id);
    }
  };

  const seasonLabel = termLabel(semester.number, semester.season, startSeason, startYear);

  // Same as the Flutter app's "An Focus Flow übergeben": the semester goes
  // to the clipboard (Focus Flow › Einstellungen › Fächer › „Aus StudiPlan
  // übernehmen“), and a link opens Focus Flow where it is installed.
  const handOverToFocusFlow = async () => {
    const plan = {
      planName,
      startSeason,
      ...(startYear != null ? { startYear } : {}),
      semesters: [semester],
    };
    const json = JSON.stringify(plan, null, 2);
    try {
      await navigator.clipboard.writeText(json);
    } catch {
      // No clipboard access (e.g. plain http): the link still works.
    }
    setHandoffLink(focusFlowLink(JSON.stringify({
      planName,
      startSeason,
      ...(startYear != null ? { startYear } : {}),
      semesters: [{
        number: semester.number,
        season: semester.season,
        lectures: semester.lectures.map((l) => ({
          name: l.name,
          color: l.color,
          passed: !!l.passed,
          ...(l.examDate ? { examDate: l.examDate } : {}),
        })),
      }],
    })));
  };

  return (
    <div className="card-hover">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-4">
          <button
            onClick={() => setIsCollapsed(!isCollapsed)}
            className="p-2 hover:bg-slate-600 rounded transition-colors"
          >
            <ChevronDown
              size={20}
              className={`transition-transform ${isCollapsed ? '-rotate-90' : ''}`}
            />
          </button>
          <div>
            <h2 className="text-2xl font-bold text-white">Semester {semester.number}</h2>
            <div className="flex flex-wrap items-center gap-x-3 gap-y-1 mt-0.5">
              <p className="text-sm text-gray-400">
                {semester.lectures.length} Veranstaltung{semester.lectures.length !== 1 ? 'en' : ''} · {formatEcts(totalEcts)} ECTS · {seasonLabel}
              </p>
              {passedEcts > 0 && (
                <span className="flex items-center gap-1 text-xs bg-green-500/20 text-green-400 px-2 py-0.5 rounded-full">
                  <CheckCircle2 size={11} />
                  {formatEcts(passedEcts)} bestanden
                </span>
              )}
              {avgGrade !== null && (
                <span className="text-xs bg-blue-500/20 text-blue-400 px-2 py-0.5 rounded-full">
                  Ø {avgGrade.toFixed(1).replace('.', ',')}
                </span>
              )}
            </div>
          </div>
        </div>
        <div className="flex items-center gap-1">
          <button
            onClick={handOverToFocusFlow}
            disabled={semester.lectures.length === 0}
            className="p-2 text-gray-400 hover:text-white hover:bg-slate-600 rounded transition-colors disabled:opacity-40"
            title="An Focus Flow übergeben"
          >
            <Send size={18} />
          </button>
          <button
            onClick={handleDelete}
            className="p-2 text-red-400 hover:text-red-300 hover:bg-red-500/20 rounded transition-colors"
            title="Semester löschen"
          >
            <Trash2 size={20} />
          </button>
        </div>
      </div>

      {handoffLink && (
        <div className="mb-4 flex flex-wrap items-center gap-x-3 gap-y-1 rounded bg-slate-700/60 px-3 py-2 text-sm text-gray-300">
          <span>
            Semester kopiert – in Focus Flow unter Einstellungen › Fächer ›
            „Aus StudiPlan übernehmen“ einfügen.
          </span>
          <a href={handoffLink} className="text-blue-400 hover:underline">
            In Focus Flow öffnen
          </a>
          <button
            onClick={() => setHandoffLink(null)}
            className="text-gray-500 hover:text-gray-300"
            title="Schließen"
          >
            ×
          </button>
        </div>
      )}

      {!isCollapsed && (
        <>
          {semester.lectures.length > 0 && (
            <div className="flex gap-2 mb-4 flex-wrap">
              <button
                onClick={() => handleSort('date')}
                className={`flex items-center gap-2 px-3 py-1 rounded text-sm transition-colors ${
                  sortBy === 'date'
                    ? 'bg-blue-600 text-white'
                    : 'bg-slate-600 text-gray-300 hover:bg-slate-500'
                }`}
              >
                <ArrowDown size={14} />
                Nach Datum sortieren
              </button>
              <button
                onClick={() => handleSort('ects')}
                className={`flex items-center gap-2 px-3 py-1 rounded text-sm transition-colors ${
                  sortBy === 'ects'
                    ? 'bg-blue-600 text-white'
                    : 'bg-slate-600 text-gray-300 hover:bg-slate-500'
                }`}
              >
                <ArrowUp size={14} />
                Nach ECTS sortieren
              </button>
            </div>
          )}

          <Droppable droppableId={semester.id} type="LECTURE">
            {(provided, snapshot) => (
              <div
                ref={provided.innerRef}
                {...provided.droppableProps}
                className={`min-h-[100px] p-4 rounded-lg border-2 border-dashed transition-colors ${
                  snapshot.isDraggingOver
                    ? 'border-blue-400 bg-blue-500/10'
                    : 'border-slate-600 bg-slate-700/50'
                }`}
              >
                {semester.lectures.length === 0 ? (
                  <div className="text-center py-8">
                    <p className="text-gray-400 text-sm">Veranstaltungen hierher ziehen</p>
                  </div>
                ) : (
                  semester.lectures.map((lecture, index) => (
                    <LectureCard
                      key={lecture.id}
                      lecture={lecture}
                      index={index}
                      semesterSeason={semester.season}
                      onEdit={() => onEdit(lecture.id)}
                    />
                  ))
                )}
                {provided.placeholder}
              </div>
            )}
          </Droppable>
        </>
      )}
    </div>
  );
};
