import React, { useEffect, useState } from 'react';
import {
  BookOpen,
  Eye,
  EyeOff,
  LogIn,
  Trash2,
  UserPlus,
} from 'lucide-react';

interface UserSelectionProps {
  onLogin: (username: string, token: string) => void;
}

type View = 'select' | 'create';
type PasswordMode = 'login' | 'delete';

export const UserSelection: React.FC<UserSelectionProps> = ({ onLogin }) => {
  const [view, setView] = useState<View>('select');
  const [users, setUsers] = useState<string[]>([]);
  const [selectedUser, setSelectedUser] = useState('');
  const [password, setPassword] = useState('');
  const [requiresPassword, setRequiresPassword] = useState(false);
  const [passwordMode, setPasswordMode] = useState<PasswordMode>('login');
  const [showPassword, setShowPassword] = useState(false);
  const [newUsername, setNewUsername] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [usersLoading, setUsersLoading] = useState(false);
  const [deleteConfirmUser, setDeleteConfirmUser] = useState<string | null>(null);
  const [deleteLoading, setDeleteLoading] = useState(false);

  const fetchWithTimeout = async (
    url: string,
    options?: RequestInit,
    timeoutMs = 10000,
  ): Promise<Response> => {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

    try {
      return await fetch(url, {
        ...options,
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeoutId);
    }
  };

  const loadUsers = async () => {
    setUsersLoading(true);
    setError('');

    try {
      const res = await fetchWithTimeout('/api/users');
      if (!res.ok) {
        throw new Error('Benutzer konnten nicht geladen werden.');
      }
      const data = (await res.json()) as string[];
      setUsers(data);
    } catch (err) {
      setUsers([]);
      const errorMsg =
        err instanceof Error && err.name === 'AbortError'
          ? 'Anfrage zeitüberschritten. Server nicht erreichbar.'
          : 'Benutzerliste konnte nicht geladen werden. Server nicht erreichbar.';
      setError(errorMsg);
    } finally {
      setUsersLoading(false);
    }
  };

  useEffect(() => {
    void loadUsers();
  }, []);

  const deleteUserWithToken = async (
    username: string,
    token: string,
  ): Promise<string | null> => {
    try {
      const res = await fetchWithTimeout(
        `/api/users/${encodeURIComponent(username)}`,
        {
          method: 'DELETE',
          headers: { Authorization: `Bearer ${token}` },
        },
      );

      if (res.ok) {
        setUsers((prev) => prev.filter((user) => user !== username));
        return null;
      }

      try {
        const data = (await res.json()) as { error?: string };
        return data.error ?? 'Loeschen fehlgeschlagen';
      } catch {
        return 'Loeschen fehlgeschlagen';
      }
    } catch (err) {
      const errorMsg =
        err instanceof Error && err.name === 'AbortError'
          ? 'Anfrage zeitüberschritten. Benutzer konnte nicht gelöscht werden.'
          : 'Server nicht erreichbar';
      return errorMsg;
    }
  };

  const handleUserSelect = async (username: string) => {
    setError('');
    setPassword('');
    setSelectedUser(username);
    setPasswordMode('login');
    setLoading(true);

    try {
      const res = await fetchWithTimeout('/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username }),
      });
      const data = (await res.json()) as {
        requiresPassword?: boolean;
        username?: string;
        token?: string;
      };

      if (res.ok && data.token) {
        onLogin(data.username ?? username, data.token);
        return;
      }

      if (res.status === 401 && data.requiresPassword) {
        setSelectedUser(data.username ?? username);
        setRequiresPassword(true);
        return;
      }

      setError('Fehler beim Anmelden');
    } catch (err) {
      const errorMsg =
        err instanceof Error && err.name === 'AbortError'
          ? 'Anfrage zeitüberschritten. Server nicht erreichbar.'
          : 'Server nicht erreichbar';
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const handlePasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await fetchWithTimeout('/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: selectedUser, password }),
      });
      const data = (await res.json()) as {
        username?: string;
        token?: string;
        error?: string;
      };

      if (!res.ok || !data.token) {
        setError(data.error ?? 'Falsches Passwort');
        return;
      }

      const resolvedUser = data.username ?? selectedUser;
      if (passwordMode === 'delete') {
        const deleteErrorMessage = await deleteUserWithToken(
          resolvedUser,
          data.token,
        );
        if (deleteErrorMessage) {
          setError(deleteErrorMessage);
          return;
        }
        setRequiresPassword(false);
        setSelectedUser('');
        setPassword('');
        setPasswordMode('login');
        return;
      }

      onLogin(resolvedUser, data.token);
    } catch (err) {
      const errorMsg =
        err instanceof Error && err.name === 'AbortError'
          ? 'Anfrage zeitüberschritten. Server nicht erreichbar.'
          : 'Server nicht erreichbar';
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateUser = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const body: Record<string, string> = { username: newUsername.trim() };
      if (newPassword.length > 0) {
        body.password = newPassword;
      }

      const res = await fetchWithTimeout('/api/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data = (await res.json()) as {
        username?: string;
        token?: string;
        error?: string;
      };

      if (res.ok && data.token) {
        onLogin(data.username ?? newUsername.trim(), data.token);
      } else {
        setError(data.error ?? 'Fehler beim Erstellen');
      }
    } catch (err) {
      const errorMsg =
        err instanceof Error && err.name === 'AbortError'
          ? 'Anfrage zeitüberschritten. Server nicht erreichbar.'
          : 'Server nicht erreichbar';
      setError(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteConfirm = async () => {
    if (!deleteConfirmUser) return;
    setDeleteLoading(true);
    setError('');

    try {
      const res = await fetchWithTimeout('/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: deleteConfirmUser }),
      });
      const data = (await res.json()) as {
        requiresPassword?: boolean;
        username?: string;
        token?: string;
        error?: string;
      };

      if (res.ok && data.token) {
        const deleteErrorMessage = await deleteUserWithToken(
          data.username ?? deleteConfirmUser,
          data.token,
        );
        if (deleteErrorMessage) {
          setError(deleteErrorMessage);
        }
      } else if (res.status === 401 && data.requiresPassword) {
        setSelectedUser(data.username ?? deleteConfirmUser);
        setRequiresPassword(true);
        setPasswordMode('delete');
        setPassword('');
      } else {
        setError(data.error ?? 'Loeschen fehlgeschlagen');
      }
    } catch (err) {
      const errorMsg =
        err instanceof Error && err.name === 'AbortError'
          ? 'Anfrage zeitüberschritten. Benutzer konnte nicht gelöscht werden.'
          : 'Server nicht erreichbar';
      setError(errorMsg);
    } finally {
      setDeleteConfirmUser(null);
      setDeleteLoading(false);
    }
  };

  const selectionDisabled = loading || usersLoading || deleteLoading;
  const passwordPromptAction =
    passwordMode === 'delete' ? 'zum Loeschen' : 'zum Anmelden';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/90 p-4 backdrop-blur-sm">
      <div className="w-full max-w-md rounded-2xl border border-slate-700 bg-slate-800 p-6 shadow-2xl">
        <div className="mb-6 flex items-center gap-3">
          <div className="flex-shrink-0 rounded-lg bg-blue-600 p-2">
            <BookOpen size={24} className="text-white" />
          </div>
          <div>
            <h2 className="text-xl font-bold text-white">StudiumsPlaner</h2>
            <p className="text-sm text-slate-400">
              Bitte waehle einen Benutzer
            </p>
          </div>
        </div>

        {view === 'select' && (
          <>
            {!requiresPassword ? (
              <>
                {usersLoading ? (
                  <p className="mb-4 py-4 text-center text-sm text-slate-400">
                    Benutzer werden geladen...
                  </p>
                ) : users.length > 0 ? (
                  <div className="mb-4 max-h-56 space-y-2 overflow-y-auto">
                    {users.map((user) => (
                      <div key={user} className="flex items-center gap-2">
                        <button
                          onClick={() => void handleUserSelect(user)}
                          className="flex flex-1 items-center gap-2 rounded-lg border border-slate-600 bg-slate-700 px-4 py-3 text-left text-white transition-colors hover:border-blue-500 hover:bg-slate-600 disabled:cursor-not-allowed disabled:opacity-50"
                          disabled={selectionDisabled}
                        >
                          <LogIn size={16} className="flex-shrink-0 text-blue-400" />
                          <span className="truncate">{user}</span>
                        </button>
                        <button
                          onClick={() => {
                            setDeleteConfirmUser(user);
                            setError('');
                          }}
                          className="flex-shrink-0 rounded-lg p-3 text-red-400 transition-colors hover:bg-slate-700 hover:text-red-300 disabled:cursor-not-allowed disabled:opacity-50"
                          title={`${user} loeschen`}
                          aria-label={`${user} loeschen`}
                          disabled={selectionDisabled}
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="mb-4 py-4 text-center text-sm text-slate-400">
                    Noch keine Benutzer vorhanden.
                  </p>
                )}

                {error && <p className="mb-3 text-sm text-red-400">{error}</p>}

                <div className="flex gap-2">
                  <button
                    onClick={() => void loadUsers()}
                    className="btn-secondary flex-1"
                    disabled={selectionDisabled}
                  >
                    Aktualisieren
                  </button>
                  <button
                    onClick={() => {
                      setView('create');
                      setError('');
                    }}
                    className="btn-primary flex flex-1 items-center justify-center gap-2"
                    disabled={selectionDisabled}
                  >
                    <UserPlus size={18} />
                    Neuen Benutzer anlegen
                  </button>
                </div>
              </>
            ) : (
              <form
                onSubmit={(e) => void handlePasswordSubmit(e)}
                className="space-y-4"
              >
                <p className="text-sm text-slate-300">
                  Passwort fuer{' '}
                  <span className="font-semibold text-white">{selectedUser}</span>{' '}
                  {passwordPromptAction}:
                </p>
                <div className="relative">
                  <input
                    className="input-field pr-10"
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Passwort eingeben"
                    maxLength={128}
                    autoFocus
                    required
                    disabled={loading}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword((value) => !value)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white"
                    tabIndex={-1}
                  >
                    {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
                {error && <p className="text-sm text-red-400">{error}</p>}
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => {
                      setRequiresPassword(false);
                      setSelectedUser('');
                      setPassword('');
                      setPasswordMode('login');
                      setError('');
                    }}
                    className="btn-secondary flex-1"
                    disabled={loading}
                  >
                    Zurueck
                  </button>
                  <button
                    type="submit"
                    className="btn-primary flex-1"
                    disabled={loading}
                  >
                    {loading
                      ? 'Pruefen...'
                      : passwordMode === 'delete'
                        ? 'Loeschen'
                        : 'Anmelden'}
                  </button>
                </div>
              </form>
            )}
          </>
        )}

        {view === 'create' && (
          <form
            onSubmit={(e) => void handleCreateUser(e)}
            className="space-y-4"
          >
            <div>
              <label className="mb-1 block text-sm font-medium text-gray-300">
                Benutzername
              </label>
              <input
                className="input-field"
                type="text"
                value={newUsername}
                onChange={(e) => setNewUsername(e.target.value)}
                placeholder="z.B. max"
                maxLength={50}
                pattern="[-a-zA-Z0-9_ ]+"
                title="Erlaubt: Buchstaben, Ziffern, Leerzeichen, _ und -"
                required
                autoFocus
                disabled={loading}
              />
            </div>
            <div>
              <label className="mb-1 block text-sm font-medium text-gray-300">
                Passwort{' '}
                <span className="font-normal text-slate-500">(optional)</span>
              </label>
              <div className="relative">
                <input
                  className="input-field pr-10"
                  type={showNewPassword ? 'text' : 'password'}
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  placeholder="Leer lassen fuer kein Passwort"
                  maxLength={128}
                  disabled={loading}
                />
                <button
                  type="button"
                  onClick={() => setShowNewPassword((value) => !value)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white"
                  tabIndex={-1}
                >
                  {showNewPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>
            {error && <p className="text-sm text-red-400">{error}</p>}
            <div className="flex gap-2">
              <button
                type="button"
                onClick={() => {
                  setView('select');
                  setError('');
                }}
                className="btn-secondary flex-1"
                disabled={loading}
              >
                Zurueck
              </button>
              <button
                type="submit"
                className="btn-primary flex-1"
                disabled={loading}
              >
                {loading ? 'Erstellen...' : 'Erstellen & Anmelden'}
              </button>
            </div>
          </form>
        )}
      </div>

      {deleteConfirmUser && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-slate-950/90 p-4 backdrop-blur-sm">
          <div className="w-full max-w-sm rounded-2xl border border-slate-700 bg-slate-800 p-6 shadow-2xl">
            <h2 className="mb-2 text-lg font-bold text-white">Konto loeschen?</h2>
            <p className="mb-4 text-sm text-slate-300">
              Soll das Konto{' '}
              <span className="font-semibold text-white">
                {deleteConfirmUser}
              </span>{' '}
              unwiderruflich geloescht werden? Alle Daten gehen dabei verloren.
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setDeleteConfirmUser(null)}
                className="btn-secondary flex-1"
                disabled={deleteLoading}
              >
                Abbrechen
              </button>
              <button
                onClick={() => void handleDeleteConfirm()}
                className="flex-1 rounded-lg bg-red-700 px-4 py-2 font-medium text-white transition-colors hover:bg-red-600 disabled:opacity-50"
                disabled={deleteLoading}
              >
                {deleteLoading ? 'Pruefen...' : 'Loeschen'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
