/**
 * Global application ViewModel.
 *
 * Orchestrates app-level state using @Observed/@Track for reactive UI updates.
 * Bridges SyncEngine data with the UI layer by:
 * 1. Initializing SyncEngine and connecting WebSocket
 * 2. Listening to WsTransport state changes for connection status
 * 3. Syncing key state to AppStorage for cross-component @StorageLink access
 *
 * Singleton pattern: use AppViewModel.getInstance() to access.
 */
import { Session, Machine, UserProfile, AppStateKeys } from 'common';
import { Logger } from 'common';
import { SyncEngine } from 'sync';
import { WsTransport } from 'network';

const TAG = 'AppViewModel';

@Observed
export class AppViewModel {
  @Track sessions: Session[] = [];
  @Track machines: Machine[] = [];
  @Track activeSessionId: string = '';
  @Track isConnected: boolean = false;
  @Track isDataReady: boolean = false;
  @Track userId: string = '';
  @Track profile: UserProfile = new UserProfile();
  @Track errorMessage: string = '';

  private static instance: AppViewModel | null = null;
  private syncEngine: SyncEngine = SyncEngine.getInstance();
  private wsTransport: WsTransport = WsTransport.getInstance();

  private constructor() {}

  static getInstance(): AppViewModel {
    if (AppViewModel.instance === null) {
      AppViewModel.instance = new AppViewModel();
    }
    return AppViewModel.instance;
  }

  /**
   * Initialize the app: run SyncEngine.init(), connect WebSocket, register listeners.
   *
   * @returns true if initialization succeeded
   */
  async initialize(token: string): Promise<boolean> {
    try {
      Logger.info(TAG, 'Initializing AppViewModel...');

      // Step 1: Initialize SyncEngine (fetch + decrypt sessions, machines, profile)
      const initOk: boolean = await this.syncEngine.init();
      if (!initOk) {
        this.setError('Failed to initialize sync engine');
        return false;
      }

      // Step 2: Connect WebSocket
      await this.syncEngine.connectWebSocket(token);

      // Step 3: Register WebSocket state change listener
      this.wsTransport.onStateChange((newState: string, _oldState: string): void => {
        this.onConnectionChanged(newState === 'connected');
      });

      // Step 4: Sync initial data from SyncEngine to local @Track state
      this.refreshFromSyncEngine();

      // Step 5: Set AppStorage for cross-component @StorageLink access
      this.syncToAppStorage();

      Logger.info(TAG, 'AppViewModel initialized successfully');
      return true;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Initialization failed: ${errMsg}`);
      this.setError(errMsg);
      return false;
    }
  }

  /**
   * Refresh sessions list from SyncEngine and update @Track properties.
   */
  onSessionsChanged(): void {
    this.refreshFromSyncEngine();
    Logger.info(TAG, `Sessions updated, count: ${this.sessions.length}`);
  }

  /**
   * Refresh machines list from SyncEngine and update @Track properties.
   */
  onMachinesChanged(): void {
    this.refreshFromSyncEngine();
    Logger.info(TAG, `Machines updated, count: ${this.machines.length}`);
  }

  /**
   * Handle WebSocket connection state change.
   * Updates local state and syncs to AppStorage.
   */
  onConnectionChanged(connected: boolean): void {
    this.isConnected = connected;
    AppStorage.setOrCreate(AppStateKeys.IS_CONNECTED, connected);

    if (connected) {
      // Re-fetch data after reconnection
      this.refreshFromSyncEngine();
      Logger.info(TAG, 'Reconnected - data refreshed');
    } else {
      Logger.info(TAG, 'Connection lost');
    }
  }

  /**
   * Get the currently active session, or null if none selected.
   */
  getActiveSession(): Session | null {
    if (this.activeSessionId === '') {
      return null;
    }

    for (let i: number = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].id === this.activeSessionId) {
        return this.sessions[i];
      }
    }
    return null;
  }

  /**
   * Set the active session by ID.
   */
  setActiveSession(sessionId: string): void {
    this.activeSessionId = sessionId;
    AppStorage.setOrCreate(AppStateKeys.ACTIVE_SESSION_ID, sessionId);
    Logger.info(TAG, `Active session set: ${sessionId}`);
  }

  /**
   * Clear the active session.
   */
  clearActiveSession(): void {
    this.activeSessionId = '';
    AppStorage.setOrCreate(AppStateKeys.ACTIVE_SESSION_ID, '');
    Logger.info(TAG, 'Active session cleared');
  }

  /**
   * Get all machines that are currently online.
   */
  getOnlineMachines(): Machine[] {
    const online: Machine[] = [];
    for (let i: number = 0; i < this.machines.length; i++) {
      if (this.machines[i].isOnline) {
        online.push(this.machines[i]);
      }
    }
    return online;
  }

  /**
   * Set an error message for UI display.
   */
  setError(message: string): void {
    this.errorMessage = message;
    Logger.error(TAG, `Error: ${message}`);
  }

  /**
   * Clear the current error message.
   */
  clearError(): void {
    this.errorMessage = '';
  }

  /**
   * Disconnect and clean up resources.
   */
  dispose(): void {
    this.syncEngine.disconnect();
    this.clearActiveSession();
    this.clearError();
    this.sessions = [];
    this.machines = [];
    this.isConnected = false;
    this.isDataReady = false;
    Logger.info(TAG, 'AppViewModel disposed');
  }

  // ---- Private methods ----

  /**
   * Pull latest data from SyncEngine and update @Track properties.
   */
  private refreshFromSyncEngine(): void {
    this.sessions = this.syncEngine.getSessions();
    this.machines = this.syncEngine.getMachines();
    this.isDataReady = this.syncEngine.isReady();

    const profile: UserProfile | null = this.syncEngine.getProfile();
    if (profile !== null) {
      this.profile = profile;
      this.userId = profile.id;
    }
  }

  /**
   * Sync current state to AppStorage for cross-component access via @StorageLink.
   */
  private syncToAppStorage(): void {
    AppStorage.setOrCreate(AppStateKeys.IS_CONNECTED, this.isConnected);
    AppStorage.setOrCreate(AppStateKeys.IS_DATA_READY, this.isDataReady);
    AppStorage.setOrCreate(AppStateKeys.USER_ID, this.userId);
    AppStorage.setOrCreate(AppStateKeys.ACTIVE_SESSION_ID, this.activeSessionId);
  }
}
