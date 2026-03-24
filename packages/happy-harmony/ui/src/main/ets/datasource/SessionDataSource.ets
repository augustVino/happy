/**
 * Data source for LazyForEach in session list.
 * Implements IDataSource to notify UI of data changes.
 */
import { Session } from 'common';
import { Logger } from 'common';

const TAG = 'SessionDataSource';

/**
 * Parameters passed to SessionItem aboutToReuse.
 */
export class SessionItemParams {
  session: Session = new Session();
  isActive: boolean = false;
}

/**
 * IDataSource implementation for session list.
 * Manages session data and notifies registered listeners of changes.
 */
export class SessionDataSource implements IDataSource {
  private sessions: Session[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.sessions.length;
  }

  getData(index: number): Session {
    return this.sessions[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos: number = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  /**
   * Replace all sessions and notify UI to refresh the entire list.
   */
  updateData(sessions: Session[]): void {
    this.sessions = sessions;
    this.notifyDataReload();
  }

  /**
   * Add a single session to the list.
   */
  addSession(session: Session): void {
    this.sessions.push(session);
    this.notifyDataAdd(this.sessions.length - 1);
  }

  /**
   * Remove a session by ID.
   */
  removeSession(sessionId: string): void {
    const index: number = this.findIndex(sessionId);
    if (index >= 0) {
      this.sessions.splice(index, 1);
      this.notifyDataDelete(index);
    }
  }

  /**
   * Update a single session in place.
   */
  updateSession(session: Session): void {
    const index: number = this.findIndex(session.id);
    if (index >= 0) {
      this.sessions[index] = session;
      this.notifyDataChange(index);
    }
  }

  /**
   * Get all sessions (for non-LazyForEach usage).
   */
  getSessions(): Session[] {
    return this.sessions;
  }

  private findIndex(sessionId: string): number {
    for (let i: number = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].id === sessionId) {
        return i;
      }
    }
    return -1;
  }

  private notifyDataReload(): void {
    this.listeners.forEach((listener: DataChangeListener): void => {
      listener.onDataReloaded();
    });
  }

  private notifyDataAdd(index: number): void {
    this.listeners.forEach((listener: DataChangeListener): void => {
      listener.onDataAdd(index);
    });
  }

  private notifyDataChange(index: number): void {
    this.listeners.forEach((listener: DataChangeListener): void => {
      listener.onDataChange(index);
    });
  }

  private notifyDataDelete(index: number): void {
    this.listeners.forEach((listener: DataChangeListener): void => {
      listener.onDataDelete(index);
    });
  }
}

/**
 * Format a timestamp into a relative time string (e.g., "2m ago", "1h ago").
 */
export function formatRelativeTime(timestamp: number): string {
  if (timestamp <= 0) {
    return '';
  }

  const now: number = Date.now();
  const diffMs: number = now - timestamp;
  const diffSeconds: number = Math.floor(diffMs / 1000);

  if (diffSeconds < 60) {
    return 'Just now';
  }

  const diffMinutes: number = Math.floor(diffSeconds / 60);
  if (diffMinutes < 60) {
    return diffMinutes + 'm ago';
  }

  const diffHours: number = Math.floor(diffMinutes / 60);
  if (diffHours < 24) {
    return diffHours + 'h ago';
  }

  const diffDays: number = Math.floor(diffHours / 24);
  if (diffDays < 7) {
    return diffDays + 'd ago';
  }

  const diffWeeks: number = Math.floor(diffDays / 7);
  return diffWeeks + 'w ago';
}
