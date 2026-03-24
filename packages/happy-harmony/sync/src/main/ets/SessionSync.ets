/**
 * Session synchronization.
 *
 * Handles REST fetching, WebSocket update processing, and metadata decryption
 * for chat sessions. Decrypts session metadata to extract title and agent mode.
 */
import { Session } from 'common';
import { Logger } from 'common';
import { SessionApi } from 'network';
import { DataKeyManager } from 'encryption';
import { SessionEncryption } from 'encryption';
import { NewSessionBody, UpdateSessionBody, DeleteSessionBody } from 'common';

const TAG = 'SessionSync';

/** Decrypted session metadata structure. */
class DecryptedMetadata {
  title: string = '';
  mode: string = '';

  constructor(title: string = '', mode: string = '') {
    this.title = title;
    this.mode = mode;
  }
}

class SessionSync {
  private sessions: Session[] = [];
  private sessionApi: SessionApi = SessionApi.getInstance();
  private dataKeyManager: DataKeyManager = DataKeyManager.getInstance();
  private sessionEncryption: SessionEncryption = SessionEncryption.getInstance();

  /**
   * REST fetch all sessions for the authenticated user.
   * Decrypts each session's DEK and metadata.
   *
   * @returns Decrypted session list
   */
  async fetchAll(): Promise<Session[]> {
    try {
      const rawSessions: Session[] = await this.sessionApi.getSessions();
      if (rawSessions.length === 0) {
        Logger.info(TAG, 'No sessions found');
        this.sessions = [];
        return [];
      }

      for (let i: number = 0; i < rawSessions.length; i++) {
        await this.processSession(rawSessions[i]);
      }

      this.sessions = rawSessions;
      Logger.info(TAG, `Fetched and decrypted ${rawSessions.length} sessions`);
      return this.sessions;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to fetch sessions: ${errMsg}`);
      return [];
    }
  }

  /**
   * Handle a new-session WebSocket update.
   * Decrypts the DEK and metadata, then inserts the session.
   */
  async handleNewSession(body: NewSessionBody): Promise<void> {
    try {
      const session: Session = new Session();
      session.id = body.id;
      session.metadata = body.metadata;
      session.metadataVersion = body.metadataVersion;
      session.agentState = body.agentState;
      session.agentStateVersion = body.agentStateVersion;
      session.dataEncryptionKey = body.dataEncryptionKey;
      session.active = body.active;
      session.activeAt = body.activeAt;
      session.createdAt = body.createdAt;
      session.updatedAt = body.updatedAt;

      await this.processSession(session);

      // Remove existing session with same id if present
      this.removeSessionById(session.id);
      this.sessions.push(session);

      Logger.info(TAG, `New session added: ${session.id}`);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to handle new session: ${errMsg}`);
    }
  }

  /**
   * Handle an update-session WebSocket update.
   * Updates metadata, agentState, and re-decrypts if version changed.
   */
  async handleUpdateSession(body: UpdateSessionBody): Promise<void> {
    try {
      const session: Session | null = this.findSession(body.id);
      if (session === null) {
        Logger.warn(TAG, `Update session: session not found ${body.id}, fetching`);
        return;
      }

      session.metadata = body.metadata;
      session.metadataVersion = body.metadataVersion;
      session.agentState = body.agentState;
      session.agentStateVersion = body.agentStateVersion;

      await this.decryptSessionMetadata(session);
      Logger.info(TAG, `Session updated: ${session.id}`);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to handle update session: ${errMsg}`);
    }
  }

  /**
   * Handle a delete-session WebSocket update.
   * Removes the session from the local list.
   */
  handleDeleteSession(body: DeleteSessionBody): void {
    try {
      this.removeSessionById(body.sid);
      Logger.info(TAG, `Session deleted: ${body.sid}`);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to handle delete session: ${errMsg}`);
    }
  }

  /**
   * Get all sessions.
   */
  getSessions(): Session[] {
    return this.sessions;
  }

  /**
   * Get a single session by ID.
   */
  getSession(id: string): Session | null {
    return this.findSession(id);
  }

  /**
   * Update the last message preview text for a session.
   * Called by MessageSync after a new message is decrypted.
   */
  updateLastMessagePreview(sessionId: string, preview: string): void {
    const session: Session | null = this.findSession(sessionId);
    if (session !== null) {
      session.lastMessagePreview = preview;
    }
  }

  /**
   * Process a session: decrypt DEK and metadata.
   */
  private async processSession(session: Session): Promise<void> {
    if (session.dataEncryptionKey.length > 0) {
      this.dataKeyManager.decryptDataKey(session.dataEncryptionKey, session.id);
    }
    await this.decryptSessionMetadata(session);
  }

  /**
   * Decrypt session metadata JSON to extract title and agent mode.
   * Metadata is stored as an encrypted base64 string.
   */
  private async decryptSessionMetadata(session: Session): Promise<void> {
    if (session.metadata.length === 0) {
      return;
    }

    const decrypted: string | null = await this.sessionEncryption.decrypt(
      session.id, session.metadata
    );
    if (decrypted === null) {
      Logger.warn(TAG, `Failed to decrypt metadata for session ${session.id}`);
      return;
    }

    const meta: DecryptedMetadata = this.parseMetadata(decrypted);
    session.decryptedTitle = meta.title;
    session.decryptedAgentMode = meta.mode;
  }

  /**
   * Parse decrypted metadata JSON string.
   * Expected format: { "title": "...", "mode": "..." }
   */
  private parseMetadata(jsonString: string): DecryptedMetadata {
    try {
      const parsed: DecryptedMetadata = JSON.parse(jsonString) as DecryptedMetadata;
      return parsed;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to parse session metadata: ${errMsg}`);
      return new DecryptedMetadata();
    }
  }

  /**
   * Find a session by ID.
   */
  private findSession(id: string): Session | null {
    for (let i: number = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].id === id) {
        return this.sessions[i];
      }
    }
    return null;
  }

  /**
   * Remove a session by ID.
   */
  private removeSessionById(id: string): void {
    const index: number = this.findSessionIndex(id);
    if (index >= 0) {
      this.sessions.splice(index, 1);
    }
  }

  /**
   * Find the index of a session by ID.
   */
  private findSessionIndex(id: string): number {
    for (let i: number = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].id === id) {
        return i;
      }
    }
    return -1;
  }
}

export { SessionSync };
