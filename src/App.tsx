import { useEffect, useRef, useState } from 'react';
import type { DropResult } from 'react-beautiful-dnd';
import { DragDropContext } from 'react-beautiful-dnd';
import {
  BookOpen,
  CheckCircle2,
  ChevronsUpDown,
  Download,
  LogOut,
  Plus,
  Trash2,
  Upload,
  User,
} from 'lucide-react';
import type { SemesterSeason } from './types';
import { useStudyPlanStore } from './store';
import {
  AddLectureModal,
  ParkingLot,
  PlanSetupModal,
  SemesterSection,
  UserSelection,
} from './components';

function App() {
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [editingLectureId, setEditingLectureId] = useState<string | null>(null);
  const [planNameInput, setPlanNameInput] = useState('');
  const [allCollapsed, setAllCollapsed] = useState<boolean | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [deleteLoading, setDeleteLoading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const currentUser = useStudyPlanStore((state) => state.currentUser);
  const authToken = useStudyPlanStore((state) => state.authToken);
  const isPlanLoading = useStudyPlanStore((state) => state.isPlanLoading);
  const syncStatus = useStudyPlanStore((state) => state.syncStatus);
  const syncMessage = useStudyPlanStore((state) => state.syncMessage);
  const setCurrentUser = useStudyPlanStore((state) => state.setCurrentUser);
  const setAuthToken = useStudyPlanStore((state) => state.setAuthToken);
  const loadPlanForUser = useStudyPlanStore((state) => state.loadPlanForUser);
  const refreshPlanFromServer = useStudyPlanStore(
    (state) => state.refreshPlanFromServer,
  );
  const deleteAccount = useStudyPlanStore((state) => state.deleteAccount);
  const planName = useStudyPlanStore((state) => state.planName);
  const regularSemesters = useStudyPlanStore(
    (state) => state.regularSemesters,
  );
  const startSeason = useStudyPlanStore((state) => state.startSeason);
  const isConfigured = useStudyPlanStore((state) => state.isConfigured);
  const semesters = useStudyPlanStore((state) => state.semesters);
  const parkingLot = useStudyPlanStore((state) => state.parkingLot);
  const initializePlan = useStudyPlanStore((state) => state.initializePlan);
  const setPlanName = useStudyPlanStore((state) => state.setPlanName);
  const addSemester = useStudyPlanStore((state) => state.addSemester);
  const moveLectureToSemester = useStudyPlanStore(
    (state) => state.moveLectureToSemester,
  );
  const moveLectureToParkingLot = useStudyPlanStore(
    (state) => state.moveLectureToParkingLot,
  );
  const reorderLecturesInSemester = useStudyPlanStore(
    (state) => state.reorderLecturesInSemester,
  );
  const exportPlan = useStudyPlanStore((state) => state.exportPlan);
  const importPlan = useStudyPlanStore((state) => state.importPlan);

  const controlsDisabled = isPlanLoading || deleteLoading;
  const syncToneClass =
    syncStatus === 'error'
      ? 'text-amber-300'
      : syncStatus === 'saving'
        ? 'text-blue-300'
        : 'text-slate-400';

  useEffect(() => {
    setPlanNameInput(planName);
  }, [planName]);

  const POLL_INTERVAL_MS = 30_000;

  useEffect(() => {
    if (!currentUser || !authToken) return;
    const intervalId = setInterval(() => {
      void refreshPlanFromServer();
    }, POLL_INTERVAL_MS);
    return () => clearInterval(intervalId);
  }, [currentUser, authToken, refreshPlanFromServer]);

  const handleLogin = (username: string, token: string) => {
    setCurrentUser(username);
    setAuthToken(token);
    void loadPlanForUser(username, token);
  };

  const handleLogout = () => {
    setCurrentUser(null);
  };

  const handleDeleteAccountConfirm = async () => {
    setDeleteLoading(true);
    setDeleteError(null);
    const err = await deleteAccount();
    setDeleteLoading(false);
    if (err) {
      setDeleteError(err);
    } else {
      setShowDeleteConfirm(false);
    }
  };

  const allLectures = [...semesters.flatMap((s) => s.lectures), ...parkingLot];
  const totalEcts = allLectures.reduce((sum, lecture) => sum + lecture.ects, 0);
  const passedLectures = allLectures.filter((lecture) => lecture.passed);
  const passedEcts = passedLectures.reduce(
    (sum, lecture) => sum + lecture.ects,
    0,
  );
  const gradedLectures = passedLectures.filter(
    (lecture) => lecture.grade !== undefined,
  );
  const avgGrade =
    gradedLectures.length > 0
      ? gradedLectures.reduce((sum, lecture) => sum + (lecture.grade ?? 0), 0) /
        gradedLectures.length
      : null;

  const handleSetupSubmit = (values: {
    planName: string;
    regularSemesters: number;
    startSeason: SemesterSeason;
  }) => {
    initializePlan(values);
  };

  const handlePlanNameCommit = () => {
    if (planNameInput.trim().length === 0) {
      setPlanNameInput(planName);
      return;
    }

    if (planNameInput !== planName) {
      setPlanName(planNameInput);
    }
  };

  const handleDragEnd = (result: DropResult) => {
    const { source, destination, draggableId } = result;

    if (!destination) {
      return;
    }

    if (
      source.droppableId === destination.droppableId &&
      source.index === destination.index
    ) {
      return;
    }

    if (
      source.droppableId === destination.droppableId &&
      source.droppableId !== 'parking-lot'
    ) {
      const semester = semesters.find((s) => s.id === source.droppableId);
      if (semester) {
        const lectures = Array.from(semester.lectures);
        const [removed] = lectures.splice(source.index, 1);
        lectures.splice(destination.index, 0, removed);
        reorderLecturesInSemester(semester.id, lectures);
      }
      return;
    }

    if (destination.droppableId === 'parking-lot') {
      moveLectureToParkingLot(draggableId);
      return;
    }

    moveLectureToSemester(draggableId, destination.droppableId);
  };

  const editingLecture = editingLectureId
    ? semesters
        .flatMap((s) => s.lectures)
        .concat(parkingLot)
        .find((lecture) => lecture.id === editingLectureId)
    : null;

  const handleEditClose = () => {
    setEditingLectureId(null);
  };

  const handleImport = () => {
    if (isPlanLoading) return;
    if (!currentUser) {
      alert('Bitte zuerst einen Benutzer auswählen.');
      return;
    }
    fileInputRef.current?.click();
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const content = e.target?.result as string;
        importPlan(content);
        alert('Studienplan erfolgreich importiert!');
      } catch (error) {
        alert(error instanceof Error ? error.message : 'Import fehlgeschlagen');
      }
    };
    reader.readAsText(file);
    event.target.value = '';
  };

  return (
    <DragDropContext onDragEnd={handleDragEnd}>
      <div className="min-h-screen">
        <header className="sticky top-0 z-40 border-b border-slate-700 bg-gradient-to-r from-slate-900 via-slate-800 to-slate-900 shadow-lg">
          <div className="mx-auto max-w-7xl px-4 py-4 sm:px-6 sm:py-6">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div className="flex min-w-0 flex-1 items-center gap-3">
                <div className="flex-shrink-0 rounded-lg bg-blue-600 p-2">
                  <BookOpen size={28} className="text-white" />
                </div>
                <div className="min-w-0 flex-1">
                  <input
                    className="w-full rounded bg-transparent px-1 text-2xl font-bold text-white focus:outline-none focus:ring-2 focus:ring-blue-500 sm:text-3xl"
                    value={planNameInput}
                    onChange={(e) => setPlanNameInput(e.target.value)}
                    onBlur={handlePlanNameCommit}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter') {
                        e.preventDefault();
                        handlePlanNameCommit();
                        (e.currentTarget as HTMLInputElement).blur();
                      }
                    }}
                    maxLength={200}
                    aria-label="Planname"
                    disabled={isPlanLoading}
                  />
                  <p className="text-sm text-gray-400">
                    Regelstudienzeit: {regularSemesters} Semester · Start:{' '}
                    {startSeason === 'winter' ? 'WS' : 'SS'}
                  </p>
                </div>
              </div>

              <div className="flex flex-wrap gap-2 sm:gap-3">
                {currentUser && (
                  <div className="flex items-center gap-2">
                    <span className="flex items-center gap-1 text-sm text-slate-300">
                      <User size={14} className="text-blue-400" />
                      <span className="hidden sm:inline">{currentUser}</span>
                    </span>
                    <button
                      onClick={() => {
                        setShowDeleteConfirm(true);
                        setDeleteError(null);
                      }}
                      className="btn-secondary flex items-center gap-2 border-red-900/50 text-red-400 hover:border-red-700 hover:text-red-300"
                      title="Konto löschen"
                      aria-label="Konto löschen"
                      disabled={controlsDisabled}
                    >
                      <Trash2 size={18} aria-hidden="true" />
                      <span className="hidden sm:inline">Konto löschen</span>
                    </button>
                    <button
                      onClick={handleLogout}
                      className="btn-secondary flex items-center gap-2"
                      title="Abmelden"
                      aria-label="Abmelden"
                      disabled={controlsDisabled}
                    >
                      <LogOut size={18} aria-hidden="true" />
                      <span className="hidden sm:inline">Abmelden</span>
                    </button>
                  </div>
                )}

                <button
                  onClick={exportPlan}
                  className="btn-secondary flex items-center gap-2"
                  title="Plan exportieren"
                  aria-label="Plan exportieren"
                  disabled={controlsDisabled}
                >
                  <Upload size={20} aria-hidden="true" />
                  <span className="hidden sm:inline">Export</span>
                </button>
                <button
                  onClick={handleImport}
                  className="btn-secondary flex items-center gap-2"
                  title="Plan importieren"
                  aria-label="Plan importieren"
                  disabled={controlsDisabled}
                >
                  <Download size={20} aria-hidden="true" />
                  <span className="hidden sm:inline">Import</span>
                </button>
                <button
                  onClick={() => setIsAddModalOpen(true)}
                  className="btn-primary flex items-center gap-2 shadow-lg hover:shadow-xl"
                  title="Veranstaltung hinzufügen"
                  aria-label="Veranstaltung hinzufügen"
                  disabled={controlsDisabled}
                >
                  <Plus size={20} aria-hidden="true" />
                  <span className="hidden sm:inline">Veranstaltung</span>
                </button>
                <button
                  onClick={addSemester}
                  className="btn-secondary flex items-center gap-2"
                  title="Semester hinzufügen"
                  aria-label="Semester hinzufügen"
                  disabled={controlsDisabled}
                >
                  <Plus size={20} aria-hidden="true" />
                  <span className="hidden sm:inline">Semester</span>
                </button>
              </div>
            </div>

            {currentUser && syncMessage && (
              <div className={`mt-3 text-xs ${syncToneClass}`}>{syncMessage}</div>
            )}

            {totalEcts > 0 && (
              <div className="mt-3 flex flex-wrap items-center gap-x-6 gap-y-1 border-t border-slate-700 pt-3 text-sm">
                <span className="text-gray-400">
                  <span className="font-semibold text-white">{totalEcts}</span>{' '}
                  ECTS geplant
                </span>
                {passedEcts > 0 && (
                  <span className="flex items-center gap-1 text-green-400">
                    <CheckCircle2 size={14} />
                    <span className="font-semibold">{passedEcts}</span> ECTS
                    bestanden
                    <span className="text-gray-500">
                      ({passedLectures.length}/{allLectures.length} Klausuren)
                    </span>
                  </span>
                )}
                {avgGrade !== null && (
                  <span className="text-gray-400">
                    Ø Note:{' '}
                    <span className="font-semibold text-blue-400">
                      {avgGrade.toFixed(1).replace('.', ',')}
                    </span>
                  </span>
                )}
              </div>
            )}
          </div>
        </header>

        <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6 sm:py-8">
          <div className="mb-6 rounded-lg border border-blue-400/30 bg-blue-500/10 px-4 py-3 text-sm text-blue-100">
            WS/SS bei Veranstaltungen ist ein Hinweis zum Turnus. Klausuren
            koennen weiterhin in jedem Semester geplant werden.
          </div>

          {semesters.length === 0 ? (
            <div className="card py-12 text-center">
              <BookOpen size={48} className="mx-auto mb-4 text-gray-400" />
              <p className="mb-4 text-gray-400">Noch keine Semester vorhanden</p>
              <button
                onClick={addSemester}
                className="btn-primary inline-flex items-center gap-2"
                disabled={controlsDisabled}
              >
                <Plus size={20} />
                Erstes Semester erstellen
              </button>
            </div>
          ) : (
            <div className="flex flex-col gap-6 lg:flex-row">
              {parkingLot.length > 0 && (
                <div className="w-full lg:w-80 lg:flex-shrink-0">
                  <ParkingLot onEdit={setEditingLectureId} />
                </div>
              )}
              <div className="min-w-0 flex-1">
                <div className="mb-2 flex justify-end">
                  <button
                    onClick={() => setAllCollapsed((c) => (c !== true ? true : false))}
                    className="flex items-center gap-1 rounded px-2 py-1 text-xs text-gray-500 transition-colors hover:text-gray-300"
                    title={allCollapsed === true ? 'Alle ausklappen' : 'Alle einklappen'}
                    disabled={controlsDisabled}
                  >
                    <ChevronsUpDown size={13} />
                    {allCollapsed === true ? 'Alle ausklappen' : 'Alle einklappen'}
                  </button>
                </div>
                <div className="space-y-6">
                  {semesters.map((semester) => (
                    <SemesterSection
                      key={semester.id}
                      semester={semester}
                      onEdit={setEditingLectureId}
                      externalCollapsed={allCollapsed}
                    />
                  ))}
                </div>
              </div>
            </div>
          )}
        </main>
      </div>

      <AddLectureModal
        key={editingLectureId ?? (isAddModalOpen ? 'create' : 'closed')}
        isOpen={isAddModalOpen || !!editingLectureId}
        onClose={() => {
          setIsAddModalOpen(false);
          handleEditClose();
        }}
        initialLecture={editingLecture || undefined}
      />

      <PlanSetupModal
        isOpen={
          isConfigured === false &&
          currentUser !== null &&
          !isPlanLoading &&
          syncStatus !== 'error'
        }
        onSubmit={handleSetupSubmit}
      />

      {currentUser === null && <UserSelection onLogin={handleLogin} />}

      <input
        ref={fileInputRef}
        type="file"
        accept="application/json"
        onChange={handleFileChange}
        style={{ display: 'none' }}
      />

      {currentUser !== null && isPlanLoading && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/80 p-4 backdrop-blur-sm">
          <div className="w-full max-w-sm rounded-2xl border border-slate-700 bg-slate-800 p-6 shadow-2xl">
            <div className="flex items-center gap-3">
              <div className="h-5 w-5 animate-spin rounded-full border-2 border-blue-400 border-t-transparent" />
              <div>
                <p className="font-semibold text-white">Plan wird geladen</p>
                <p className="text-sm text-slate-400">
                  Der zuletzt bestaetigte Stand wird vorbereitet.
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

      {showDeleteConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/90 p-4 backdrop-blur-sm">
          <div className="w-full max-w-sm rounded-2xl border border-slate-700 bg-slate-800 p-6 shadow-2xl">
            <h2 className="mb-2 text-lg font-bold text-white">Konto loeschen?</h2>
            <p className="mb-4 text-sm text-slate-300">
              Soll das Konto{' '}
              <span className="font-semibold text-white">{currentUser}</span>{' '}
              unwiderruflich geloescht werden? Alle Daten gehen dabei verloren.
            </p>
            {deleteError && (
              <p className="mb-3 text-sm text-red-400">{deleteError}</p>
            )}
            <div className="flex gap-3">
              <button
                onClick={() => {
                  setShowDeleteConfirm(false);
                  setDeleteError(null);
                }}
                className="btn-secondary flex-1"
                disabled={deleteLoading}
              >
                Abbrechen
              </button>
              <button
                onClick={() => void handleDeleteAccountConfirm()}
                className="flex-1 rounded-lg bg-red-700 px-4 py-2 font-medium text-white transition-colors hover:bg-red-600 disabled:opacity-50"
                disabled={deleteLoading}
              >
                {deleteLoading ? 'Loeschen…' : 'Loeschen'}
              </button>
            </div>
          </div>
        </div>
      )}
    </DragDropContext>
  );
}

export default App;
