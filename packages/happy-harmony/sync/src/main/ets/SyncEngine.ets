/**
 * Core sync engine orchestrator.
 *
 * Coordinates initial data sync (REST + decrypt) and real-time updates (WebSocket).
 * Singleton pattern: use SyncEngine.getInstance() to access.
 *
 * Initialization flow:
 * 1. Initialize EncryptionService (derive contentKeyPair from master secret)
 * 2. Parallel REST fetch: sessions, machines, profile
 * 3. Decrypt DEKs and metadata for all sessions and machines
 * 4. Set AppStorage global state
 * 5. Connect WebSocket, register update/ephemeral event handlers
 * 6. Set isDataReady = true
 *
 * Real-time sync:
 * - 'update' events: dispatch to SessionSync, MessageSync, or MachineSync by body.t
 * - 'ephemeral' events: update thinking/active state on sessions and machines
 * - Seq gap detection: if seq has gaps, trigger REST backfill
 */
import { Session, SessionMessage, Machine, UserProfile, AppStateKeys } from 'common';
import { Logger } from 'common';
import { WsTransport } from 'network';
import { AccountApi } from 'network';
import { EncryptionService } from 'encryption';
import { DataKeyManager } from 'encryption';
import { SessionSync } from './SessionSync';
import { MessageSync } from './MessageSync';
import { MachineSync } from './MachineSync';
import {
  UpdateContainer,
  NewMessageBody,
  NewSessionBody,
  UpdateSessionBody,
  DeleteSessionBody,
  NewMachineBody,
  UpdateMachineBody,
  EphemeralEvent,
} from 'common';

const TAG = 'SyncEngine';

/** Update type discriminant values. */
class UpdateTypes {
  static readonly NEW_MESSAGE: string = 'new-message';
  static readonly NEW_SESSION: string = 'new-session';
  static readonly UPDATE_SESSION: string = 'update-session';
  static readonly DELETE_SESSION: string = 'delete-session';
  static readonly NEW_MACHINE: string = 'new-machine';
  static readonly UPDATE_MACHINE: string = 'update-machine';
  static readonly UPDATE_ACCOUNT: string = 'update-account';
}

/** Ephemeral event type discriminant values. */
class EphemeralTypes {
  static readonly ACTIVITY: string = 'activity';
  static readonly MACHINE_ACTIVITY: string = 'machine-activity';
  static readonly USAGE: string = 'usage';
}

/** Maximum seq gap before triggering a REST backfill. */
const MAX_SEQ_GAP: number = 5;

/** Typed class for parsing update container JSON. */
class ParsedUpdateContainer {
  id: string = '';
  seq: number = 0;
  body: string = '';
  createdAt: number = 0;

  constructor() {}
}

/** Typed class for parsing ephemeral event JSON. */
class ParsedEphemeralEvent {
  type: string = '';
  id: string = '';
  data: string = '';

  constructor() {}
}

/** Unified typed class for parsing all update body JSON variants. */
class ParsedUpdateBody {
  t: string = '';
  sid: string = '';
  messageId: string = '';
  messageSeq: number = 0;
  messageLocalId: string = '';
  messageContent: string = '';
  messageCreatedAt: number = 0;
  messageUpdatedAt: number = 0;
  id: string = '';
  metadata: string = '';
  metadataVersion: number = 0;
  agentState: string = '';
  agentStateVersion: number = 0;
  dataEncryptionKey: string = '';
  active: boolean = false;
  activeAt: number = 0;
  createdAt: number = 0;
  updatedAt: number = 0;
  name: string = '';
  daemonState: string = '';
  daemonStateVersion: number = 0;
  machineId: string = '';

  constructor() {}
}

/** Typed class for parsing activity ephemeral data JSON. */
class ParsedActivityData {
  thinking: boolean = false;
  active: boolean = false;
  activeAt: number = 0;

  constructor() {}
}

/** Typed class for parsing machine activity ephemeral data JSON. */
class ParsedMachineActivityData {
  active: boolean = false;
  activeAt: number = 0;

  constructor() {}
}

class SyncEngine {
  private static instance: SyncEngine | null = null;

  private wsTransport: WsTransport = WsTransport.getInstance();
  private sessionSync: SessionSync = new SessionSync();
  private messageSync: MessageSync = new MessageSync();
  private machineSync: MachineSync = new MachineSync();
  private encryptionService: EncryptionService = EncryptionService.getInstance();
  private dataKeyManager: DataKeyManager = DataKeyManager.getInstance();
  private accountApi: AccountApi = AccountApi.getInstance();

  private isInitialized: boolean = false;
  private lastSeq: number = 0;
  private profile: UserProfile | null = null;

  private constructor() {}

  static getInstance(): SyncEngine {
    if (SyncEngine.instance === null) {
      SyncEngine.instance = new SyncEngine();
    }
    return SyncEngine.instance;
  }

  /**
   * Initialize the sync engine.
   *
   * 1. Initialize EncryptionService (derive contentKeyPair)
   * 2. Parallel REST fetch: sessions, machines, profile
   * 3. Decrypt DEKs and metadata
   * 4. Set AppStorage global state
   * 5. Connect WebSocket and register event handlers
   *
   * @returns true if initialization succeeded
   */
  async init(): Promise<boolean> {
    if (this.isInitialized) {
      Logger.info(TAG, 'Already initialized');
      return true;
    }

    try {
      Logger.info(TAG, 'Starting sync initialization...');

      // Step 1: Initialize encryption
      const encryptionOk: boolean = await this.encryptionService.initialize();
      if (!encryptionOk) {
        Logger.error(TAG, 'Encryption service initialization failed');
        return false;
      }

      // Step 2: Parallel REST fetch
      const sessionsPromise: Promise<Session[]> = this.sessionSync.fetchAll();
      const machinesPromise: Promise<Machine[]> = this.machineSync.fetchAll();
      const profilePromise: Promise<UserProfile> = this.fetchProfile();

      const results = await Promise.all([sessionsPromise, machinesPromise, profilePromise]);
      const sessionsCount: number = results[0].length;
      const machinesCount: number = results[1].length;
      const profile: UserProfile = results[2];

      this.profile = profile;

      // Step 3: Set AppStorage global state
      AppStorage.setOrCreate(AppStateKeys.IS_DATA_READY, true);
      AppStorage.setOrCreate(AppStateKeys.USER_ID, profile.id);

      Logger.info(TAG, `Sync complete: ${sessionsCount} sessions, ${machinesCount} machines`);

      // Step 4: Register WebSocket event handlers
      this.registerWsHandlers();

      this.isInitialized = true;
      Logger.info(TAG, 'Sync engine initialized successfully');
      return true;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Sync initialization failed: ${errMsg}`);
      AppStorage.setOrCreate(AppStateKeys.IS_DATA_READY, false);
      return false;
    }
  }

  /**
   * Connect to WebSocket with the given token.
   * Should be called after init() with a valid JWT.
   */
  async connectWebSocket(token: string): Promise<void> {
    try {
      await this.wsTransport.connect(token);
      AppStorage.setOrCreate(AppStateKeys.IS_CONNECTED, true);
      Logger.info(TAG, 'WebSocket connected');
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `WebSocket connection failed: ${errMsg}`);
      AppStorage.setOrCreate(AppStateKeys.IS_CONNECTED, false);
    }
  }

  /**
   * Disconnect WebSocket and clean up state.
   */
  disconnect(): void {
    this.wsTransport.off('update');
    this.wsTransport.off('ephemeral');
    this.wsTransport.disconnect();
    this.isInitialized = false;
    this.lastSeq = 0;
    this.dataKeyManager.clearAll();
    AppStorage.setOrCreate(AppStateKeys.IS_CONNECTED, false);
    AppStorage.setOrCreate(AppStateKeys.IS_DATA_READY, false);
    Logger.info(TAG, 'Sync engine disconnected');
  }

  /**
   * Handle a WebSocket 'update' event.
   * Parses the JSON, checks seq continuity, and dispatches to the appropriate syncer.
   */
  async handleUpdate(rawData: string): Promise<void> {
    try {
      const container: UpdateContainer | null = this.parseUpdateContainer(rawData);
      if (container === null) {
        Logger.warn(TAG, 'Failed to parse update container');
        return;
      }

      // Check seq gap
      if (this.lastSeq > 0 && this.checkSeqGap(container.seq)) {
        Logger.warn(TAG, `Seq gap detected: last=${this.lastSeq} current=${container.seq}`);
        await this.backfillSessions();
      }

      this.lastSeq = container.seq;

      // Parse body to determine type
      const bodyObj: ParsedUpdateBody = JSON.parse(container.body) as ParsedUpdateBody;
      const type: string = bodyObj.t;

      switch (type) {
        case UpdateTypes.NEW_MESSAGE:
          await this.handleNewMessage(bodyObj);
          break;
        case UpdateTypes.NEW_SESSION:
          await this.handleNewSession(bodyObj);
          break;
        case UpdateTypes.UPDATE_SESSION:
          await this.handleUpdateSession(bodyObj);
          break;
        case UpdateTypes.DELETE_SESSION:
          this.handleDeleteSession(bodyObj);
          break;
        case UpdateTypes.NEW_MACHINE:
          await this.handleNewMachine(bodyObj);
          break;
        case UpdateTypes.UPDATE_MACHINE:
          await this.handleUpdateMachine(bodyObj);
          break;
        case UpdateTypes.UPDATE_ACCOUNT:
          await this.handleUpdateAccount();
          break;
        default:
          Logger.warn(TAG, `Unknown update type: ${type}`);
          break;
      }
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to handle update: ${errMsg}`);
    }
  }

  /**
   * Handle a WebSocket 'ephemeral' event.
   * Updates thinking/active state on sessions and machines.
   */
  handleEphemeral(rawData: string): void {
    try {
      const ephemeral: EphemeralEvent | null = this.parseEphemeral(rawData);
      if (ephemeral === null) {
        Logger.warn(TAG, 'Failed to parse ephemeral event');
        return;
      }

      switch (ephemeral.type) {
        case EphemeralTypes.ACTIVITY:
          this.handleActivity(ephemeral.id, ephemeral.data);
          break;
        case EphemeralTypes.MACHINE_ACTIVITY:
          this.handleMachineActivity(ephemeral.id, ephemeral.data);
          break;
        case EphemeralTypes.USAGE:
          // Usage events don't require local state updates
          break;
        default:
          Logger.warn(TAG, `Unknown ephemeral type: ${ephemeral.type}`);
          break;
      }
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to handle ephemeral: ${errMsg}`);
    }
  }

  /**
   * Get all sessions.
   */
  getSessions(): Session[] {
    return this.sessionSync.getSessions();
  }

  /**
   * Get all machines.
   */
  getMachines(): Machine[] {
    return this.machineSync.getMachines();
  }

  /**
   * Get messages for a session.
   */
  getMessages(sessionId: string): SessionMessage[] {
    return this.messageSync.getMessages(sessionId);
  }

  /**
   * Get the user profile.
   */
  getProfile(): UserProfile | null {
    return this.profile;
  }

  /**
   * Check if the sync engine is ready.
   */
  isReady(): boolean {
    return this.isInitialized;
  }

  /**
   * Get the last processed update sequence number.
   */
  getLastSeq(): number {
    return this.lastSeq;
  }

  // ---- Private methods ----

  /**
   * Register WebSocket event handlers for 'update' and 'ephemeral'.
   */
  private registerWsHandlers(): void {
    this.wsTransport.on('update', (data: string) => {
      this.handleUpdate(data);
    });

    this.wsTransport.on('ephemeral', (data: string) => {
      this.handleEphemeral(data);
    });
  }

  /**
   * Fetch the user profile via REST.
   */
  private async fetchProfile(): Promise<UserProfile> {
    try {
      return await this.accountApi.getProfile();
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to fetch profile: ${errMsg}`);
      const fallback: UserProfile = new UserProfile();
      return fallback;
    }
  }

  /**
   * Parse raw JSON string into an UpdateContainer.
   */
  private parseUpdateContainer(rawData: string): UpdateContainer | null {
    try {
      const parsed: ParsedUpdateContainer = JSON.parse(rawData) as ParsedUpdateContainer;
      const container: UpdateContainer = new UpdateContainer(parsed.id, parsed.seq, parsed.body,
        parsed.createdAt);
      return container;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to parse update container: ${errMsg}`);
      return null;
    }
  }

  /**
   * Parse raw JSON string into an EphemeralEvent.
   */
  private parseEphemeral(rawData: string): EphemeralEvent | null {
    try {
      const parsed: ParsedEphemeralEvent = JSON.parse(rawData) as ParsedEphemeralEvent;
      const event: EphemeralEvent = new EphemeralEvent();
      event.type = parsed.type;
      event.id = parsed.id;
      event.data = parsed.data;
      return event;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to parse ephemeral event: ${errMsg}`);
      return null;
    }
  }

  /**
   * Check if there is a gap in the sequence numbers.
   * Returns true if the gap exceeds MAX_SEQ_GAP.
   */
  private checkSeqGap(newSeq: number): boolean {
    if (this.lastSeq <= 0) {
      return false;
    }
    const gap: number = newSeq - this.lastSeq;
    return gap > MAX_SEQ_GAP;
  }

  /**
   * REST backfill: re-fetch all sessions to recover from seq gaps.
   */
  private async backfillSessions(): Promise<void> {
    try {
      await this.sessionSync.fetchAll();
      Logger.info(TAG, 'Session backfill complete');
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Session backfill failed: ${errMsg}`);
    }
  }

  // ---- Update dispatchers ----

  private async handleNewMessage(bodyObj: ParsedUpdateBody): Promise<void> {
    const body: NewMessageBody = new NewMessageBody();
    body.sid = bodyObj.sid;
    body.messageId = bodyObj.messageId;
    body.messageSeq = bodyObj.messageSeq;
    body.messageLocalId = bodyObj.messageLocalId;
    body.messageContent = bodyObj.messageContent;
    body.messageCreatedAt = bodyObj.messageCreatedAt;
    body.messageUpdatedAt = bodyObj.messageUpdatedAt;
    await this.messageSync.handleNewMessage(body);

    // Update session preview with latest message
    const messages: SessionMessage[] = this.messageSync.getMessages(body.sid);
    if (messages.length > 0) {
      const lastMsg: SessionMessage = messages[messages.length - 1];
      const preview: string = this.messageSync.getMessagePreview(lastMsg);
      this.sessionSync.updateLastMessagePreview(body.sid, preview);
    }
  }

  private async handleNewSession(bodyObj: ParsedUpdateBody): Promise<void> {
    const body: NewSessionBody = new NewSessionBody();
    body.id = bodyObj.id;
    body.metadata = bodyObj.metadata;
    body.metadataVersion = bodyObj.metadataVersion;
    body.agentState = bodyObj.agentState;
    body.agentStateVersion = bodyObj.agentStateVersion;
    body.dataEncryptionKey = bodyObj.dataEncryptionKey;
    body.active = bodyObj.active;
    body.activeAt = bodyObj.activeAt;
    body.createdAt = bodyObj.createdAt;
    body.updatedAt = bodyObj.updatedAt;
    await this.sessionSync.handleNewSession(body);
  }

  private async handleUpdateSession(bodyObj: ParsedUpdateBody): Promise<void> {
    const body: UpdateSessionBody = new UpdateSessionBody();
    body.id = bodyObj.id;
    body.metadata = bodyObj.metadata;
    body.metadataVersion = bodyObj.metadataVersion;
    body.agentState = bodyObj.agentState;
    body.agentStateVersion = bodyObj.agentStateVersion;
    await this.sessionSync.handleUpdateSession(body);
  }

  private handleDeleteSession(bodyObj: ParsedUpdateBody): void {
    const body: DeleteSessionBody = new DeleteSessionBody();
    body.sid = bodyObj.sid;
    this.sessionSync.handleDeleteSession(body);
  }

  private async handleNewMachine(bodyObj: ParsedUpdateBody): Promise<void> {
    const body: NewMachineBody = new NewMachineBody();
    body.id = bodyObj.id;
    body.name = bodyObj.name;
    body.metadata = bodyObj.metadata;
    body.metadataVersion = bodyObj.metadataVersion;
    body.daemonState = bodyObj.daemonState;
    body.daemonStateVersion = bodyObj.daemonStateVersion;
    body.active = bodyObj.active;
    body.activeAt = bodyObj.activeAt;
    body.createdAt = bodyObj.createdAt;
    body.updatedAt = bodyObj.updatedAt;
    await this.machineSync.handleNewMachine(body);
  }

  private async handleUpdateMachine(bodyObj: ParsedUpdateBody): Promise<void> {
    const body: UpdateMachineBody = new UpdateMachineBody();
    body.machineId = bodyObj.machineId;
    body.metadata = bodyObj.metadata;
    body.metadataVersion = bodyObj.metadataVersion;
    body.daemonState = bodyObj.daemonState;
    body.daemonStateVersion = bodyObj.daemonStateVersion;
    body.active = bodyObj.active;
    body.activeAt = bodyObj.activeAt;
    await this.machineSync.handleUpdateMachine(body);
  }

  private async handleUpdateAccount(): Promise<void> {
    try {
      const profile: UserProfile = await this.accountApi.getProfile();
      this.profile = profile;
      AppStorage.setOrCreate(AppStateKeys.USER_ID, profile.id);
      Logger.info(TAG, 'Account profile updated');
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to refresh profile: ${errMsg}`);
    }
  }

  // ---- Ephemeral handlers ----

  private handleActivity(id: string, data: string): void {
    try {
      const parsed: ParsedActivityData = JSON.parse(data) as ParsedActivityData;
      const session: Session | null = this.sessionSync.getSession(id);
      if (session === null) {
        return;
      }

      session.isThinking = parsed.thinking;
      session.active = parsed.active;
      session.activeAt = parsed.activeAt;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to handle activity ephemeral: ${errMsg}`);
    }
  }

  private handleMachineActivity(id: string, data: string): void {
    try {
      const parsed: ParsedMachineActivityData = JSON.parse(data) as ParsedMachineActivityData;
      const machines: Machine[] = this.machineSync.getMachines();

      for (let i: number = 0; i < machines.length; i++) {
        if (machines[i].id === id) {
          machines[i].isOnline = parsed.active;
          machines[i].activeAt = parsed.activeAt;
          break;
        }
      }
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to handle machine activity ephemeral: ${errMsg}`);
    }
  }

}

export { SyncEngine };
