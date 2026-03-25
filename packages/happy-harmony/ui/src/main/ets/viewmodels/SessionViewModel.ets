/**
 * Session-level ViewModel.
 *
 * Manages the state for a single chat session, including messages,
 * thinking state, and message sending.
 *
 * Uses @Observed/@Track for reactive UI updates when used with @ObjectLink.
 *
 * Usage:
 *   const vm = new SessionViewModel('session-id');
 *   await vm.loadMessages();
 *   await vm.sendMessage('Hello');
 */
import { SessionMessage, MessageRoles, MessageEventTypes } from 'common';
import { Logger } from 'common';
import { SyncEngine } from 'sync';
import { SessionEncryption } from 'encryption';
import { SessionApi, SendMessageRequest } from 'network';

/** Typed event for building message envelope JSON. */
class MessageTextEvent {
  t: string = '';
  text: string = '';
}

/** Typed envelope data for JSON serialization. */
class MessageEnvelopeData {
  id: string = '';
  time: number = 0;
  role: string = '';
  ev: MessageTextEvent = new MessageTextEvent();
}

const TAG = 'SessionViewModel';

@Observed
export class SessionViewModel {
  @Track sessionId: string = '';
  @Track messages: SessionMessage[] = [];
  @Track isThinking: boolean = false;
  @Track isActive: boolean = false;
  @Track agentState: string = '';

  private syncEngine: SyncEngine = SyncEngine.getInstance();
  private sessionEncryption: SessionEncryption = SessionEncryption.getInstance();
  private sessionApi: SessionApi = SessionApi.getInstance();

  constructor(sessionId: string) {
    this.sessionId = sessionId;
  }

  /**
   * Load messages for this session from SyncEngine.
   * Falls back to REST API if SyncEngine has no cached messages.
   */
  async loadMessages(): Promise<void> {
    try {
      Logger.info(TAG, `Loading messages for session: ${this.sessionId}`);

      // Try SyncEngine cache first
      const cachedMessages: SessionMessage[] = this.syncEngine.getMessages(this.sessionId);
      if (cachedMessages.length > 0) {
        this.messages = cachedMessages;
        Logger.info(TAG, `Loaded ${cachedMessages.length} cached messages`);
        return;
      }

      // Fall back to REST API
      const response = await this.sessionApi.getMessages(this.sessionId);
      this.messages = response.messages;
      Logger.info(TAG, `Loaded ${response.messages.length} messages from API`);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to load messages: ${errMsg}`);
    }
  }

  /**
   * Handle a new message received from WebSocket.
   * Appends the message and updates thinking state if applicable.
   */
  onNewMessage(message: SessionMessage): void {
    // Avoid duplicates
    if (this.isDuplicateMessage(message)) {
      return;
    }

    this.messages.push(message);

    // Update thinking state based on message event type
    if (message.eventType === MessageEventTypes.TURN_START) {
      this.onThinkingChanged(true);
    } else if (message.eventType === MessageEventTypes.TURN_END) {
      this.onThinkingChanged(false);
    } else if (message.eventType === MessageEventTypes.STOP) {
      this.onThinkingChanged(false);
    }

    Logger.info(TAG, `New message: seq=${message.seq} role=${message.role}`);
  }

  /**
   * Handle thinking state change for this session.
   */
  onThinkingChanged(thinking: boolean): void {
    if (this.isThinking === thinking) {
      return;
    }
    this.isThinking = thinking;
    Logger.info(TAG, `Thinking state: ${thinking}`);
  }

  /**
   * Send a user message to this session.
   *
   * Flow:
   * 1. Build plaintext envelope JSON
   * 2. Encrypt with SessionEncryption
   * 3. Send via REST API (SessionApi.sendMessage)
   *
   * @param text The user's message text
   * @returns true if sent successfully
   */
  async sendMessage(text: string): Promise<boolean> {
    if (this.sessionId === '') {
      Logger.error(TAG, 'Cannot send message: no session ID');
      return false;
    }

    if (text.trim() === '') {
      Logger.warn(TAG, 'Cannot send empty message');
      return false;
    }

    try {
      // Step 1: Build envelope plaintext
      const evObj: MessageTextEvent = new MessageTextEvent();
      evObj.t = MessageEventTypes.TEXT;
      evObj.text = text;
      const envelope: MessageEnvelopeData = new MessageEnvelopeData();
      envelope.id = this.generateLocalId();
      envelope.time = Date.now();
      envelope.role = MessageRoles.USER;
      envelope.ev = evObj;
      const plaintext: string = JSON.stringify(envelope);

      // Step 2: Encrypt the message
      const encrypted: string | null = await this.sessionEncryption.encrypt(
        this.sessionId,
        plaintext
      );
      if (encrypted === null) {
        Logger.error(TAG, 'Failed to encrypt message');
        return false;
      }

      // Step 3: Send via REST API
      const localId: string = envelope.id;
      const request: SendMessageRequest = new SendMessageRequest(localId, encrypted);
      await this.sessionApi.sendMessage(this.sessionId, [request]);

      // Step 4: Add optimistic local message
      const localMessage: SessionMessage = new SessionMessage();
      localMessage.id = localId;
      localMessage.sessionId = this.sessionId;
      localMessage.localId = localId;
      localMessage.role = MessageRoles.USER;
      localMessage.content = text;
      localMessage.decryptedContent = text;
      localMessage.eventType = MessageEventTypes.TEXT;
      localMessage.createdAt = Date.now();
      localMessage.updatedAt = Date.now();
      this.messages.push(localMessage);

      Logger.info(TAG, `Message sent successfully: ${localId}`);
      return true;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to send message: ${errMsg}`);
      return false;
    }
  }

  /**
   * Get the last message in the session, or null if empty.
   */
  getLastMessage(): SessionMessage | null {
    if (this.messages.length === 0) {
      return null;
    }
    return this.messages[this.messages.length - 1];
  }

  /**
   * Refresh messages from SyncEngine (e.g., after WebSocket update).
   */
  refreshMessages(): void {
    const freshMessages: SessionMessage[] = this.syncEngine.getMessages(this.sessionId);
    if (freshMessages.length > 0) {
      this.messages = freshMessages;
    }
    this.updateThinkingState();
  }

  // ---- Private methods ----

  /**
   * Update thinking state by scanning messages for TURN_START / TURN_END events.
   * The most recent thinking-related event determines the current state.
   */
  private updateThinkingState(): void {
    let thinking: boolean = false;
    for (let i: number = 0; i < this.messages.length; i++) {
      const msg: SessionMessage = this.messages[i];
      if (msg.eventType === MessageEventTypes.TURN_START) {
        thinking = true;
      } else if (msg.eventType === MessageEventTypes.TURN_END || msg.eventType === MessageEventTypes.STOP) {
        thinking = false;
      }
    }
    this.isThinking = thinking;
  }

  /**
   * Check if a message is already in the local list (by ID).
   */
  private isDuplicateMessage(message: SessionMessage): boolean {
    for (let i: number = 0; i < this.messages.length; i++) {
      if (this.messages[i].id === message.id) {
        return true;
      }
    }
    return false;
  }

  /**
   * Generate a simple local ID for optimistic message insertion.
   * Format: local_<timestamp>_<random4>
   */
  private generateLocalId(): string {
    const timestamp: number = Date.now();
    const random: number = Math.floor(Math.random() * 10000);
    return `local_${timestamp}_${random}`;
  }
}
