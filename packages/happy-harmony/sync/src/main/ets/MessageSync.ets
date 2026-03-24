/**
 * Message synchronization.
 *
 * Handles REST fetching, WebSocket update processing, and content decryption
 * for session messages. Maintains a map of sessionId -> messages for fast lookup.
 */
import { SessionMessage, MessageEventTypes } from 'common';
import { Logger } from 'common';
import { SessionApi, MessagesResponse } from 'network';
import { DataKeyManager } from 'encryption';
import { SessionEncryption } from 'encryption';
import { NewMessageBody } from 'common';

const TAG = 'MessageSync';

/** Maximum message preview length for session list display. */
const MAX_PREVIEW_LENGTH: number = 80;

/** Decrypted message envelope structure. */
class MessageEnvelope {
  id: string = '';
  time: number = 0;
  role: string = '';
  ev: MessageEvent = new MessageEvent();

  constructor() {}
}

/** Event structure within a message envelope. */
class MessageEvent {
  t: string = '';
  text: string = '';
  status: string = '';

  constructor() {}
}

/** Typed class for JSON parsing of message envelope. */
class ParsedEnvelope {
  id: string = '';
  time: number = 0;
  role: string = '';
  ev: ParsedEnvelopeEvent = new ParsedEnvelopeEvent();

  constructor() {}
}

/** Typed class for JSON parsing of envelope event field. */
class ParsedEnvelopeEvent {
  t: string = '';
  text: string = '';
  status: string = '';

  constructor() {}
}

class MessageSync {
  private messages: Map<string, SessionMessage[]> = new Map();
  private sessionApi: SessionApi = SessionApi.getInstance();
  private sessionEncryption: SessionEncryption = SessionEncryption.getInstance();
  private dataKeyManager: DataKeyManager = DataKeyManager.getInstance();

  /**
   * REST fetch messages for a session, optionally after a given seq number.
   * Decrypts message contents and appends to the local cache.
   *
   * @param sessionId Session identifier
   * @param afterSeq Fetch messages after this sequence number (default 0)
   * @returns Fetched messages list
   */
  async fetchMessages(sessionId: string, afterSeq: number = 0): Promise<SessionMessage[]> {
    try {
      const response: MessagesResponse = await this.sessionApi.getMessages(sessionId, afterSeq);
      if (response.messages.length === 0) {
        Logger.info(TAG, `No messages for session ${sessionId}`);
        return [];
      }

      const dek: Uint8Array | null = this.dataKeyManager.getDataKey(sessionId);
      if (dek === null) {
        Logger.warn(TAG, `No DEK for session ${sessionId}, cannot decrypt messages`);
        return [];
      }

      for (let i: number = 0; i < response.messages.length; i++) {
        await this.decryptMessage(response.messages[i]);
      }

      this.appendMessages(sessionId, response.messages);
      Logger.info(TAG, `Fetched ${response.messages.length} messages for session ${sessionId}`);
      return response.messages;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to fetch messages for ${sessionId}: ${errMsg}`);
      return [];
    }
  }

  /**
   * Handle a new-message WebSocket update.
   * Decrypts the message content and inserts it into the cache.
   */
  async handleNewMessage(body: NewMessageBody): Promise<void> {
    try {
      const message: SessionMessage = new SessionMessage();
      message.id = body.messageId;
      message.seq = body.messageSeq;
      message.sessionId = body.sid;
      message.localId = body.messageLocalId;
      message.content = body.messageContent;
      message.createdAt = body.messageCreatedAt;
      message.updatedAt = body.messageUpdatedAt;

      const dek: Uint8Array | null = this.dataKeyManager.getDataKey(body.sid);
      if (dek === null) {
        Logger.warn(TAG, `No DEK for session ${body.sid}, cannot decrypt new message`);
        return;
      }

      await this.decryptMessage(message);
      this.insertMessage(body.sid, message);

      Logger.info(TAG, `New message: seq=${message.seq} session=${body.sid}`);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to handle new message: ${errMsg}`);
    }
  }

  /**
   * Get all messages for a session.
   */
  getMessages(sessionId: string): SessionMessage[] {
    const msgs: SessionMessage[] | undefined = this.messages.get(sessionId);
    if (msgs === undefined) {
      return [];
    }
    return msgs;
  }

  /**
   * Get a human-readable preview text for a message.
   * Used to display the last message in session list items.
   */
  getMessagePreview(message: SessionMessage): string {
    if (message.decryptedContent.length === 0) {
      return message.content;
    }

    const envelope: MessageEnvelope = this.parseEnvelope(message.decryptedContent);
    if (envelope.ev.t.length === 0) {
      return envelope.role.length > 0 ? envelope.role : '';
    }

    const event: MessageEvent = envelope.ev;
    const eventType: string = event.t;

    if (eventType === MessageEventTypes.TEXT) {
      const text: string = event.text;
      if (text.length > MAX_PREVIEW_LENGTH) {
        return text.substring(0, MAX_PREVIEW_LENGTH) + '...';
      }
      return text;
    }

    if (eventType === MessageEventTypes.TOOL_CALL_START) {
      return '[tool call]';
    }

    if (eventType === MessageEventTypes.TOOL_CALL_END) {
      return '[tool result]';
    }

    if (eventType === MessageEventTypes.TURN_END) {
      const status: string = event.status;
      if (status === 'completed') {
        return '[done]';
      }
      return '[turn end]';
    }

    return '';
  }

  /**
   * Decrypt a message's content using the session DEK.
   * Sets decryptedContent, role, eventType, and isThinking on the message.
   */
  private async decryptMessage(message: SessionMessage): Promise<void> {
    if (message.content.length === 0) {
      return;
    }

    const decrypted: string | null = await this.sessionEncryption.decrypt(
      message.sessionId, message.content
    );
    if (decrypted === null) {
      Logger.warn(TAG, `Failed to decrypt message ${message.id}`);
      return;
    }

    message.decryptedContent = decrypted;

    const envelope: MessageEnvelope = this.parseEnvelope(decrypted);
    message.role = envelope.role;

    if (envelope.ev.t.length > 0) {
      message.eventType = envelope.ev.t;
    }
  }

  /**
   * Parse a decrypted message envelope JSON string.
   * Expected format: { "id": "...", "time": ..., "role": "...", "ev": { ... } }
   */
  private parseEnvelope(jsonString: string): MessageEnvelope {
    try {
      const parsed: ParsedEnvelope = JSON.parse(jsonString) as ParsedEnvelope;
      const envelope: MessageEnvelope = new MessageEnvelope();
      envelope.id = parsed.id;
      envelope.time = parsed.time;
      envelope.role = parsed.role;
      envelope.ev.t = parsed.ev.t;
      envelope.ev.text = parsed.ev.text;
      envelope.ev.status = parsed.ev.status;
      return envelope;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to parse message envelope: ${errMsg}`);
      return new MessageEnvelope();
    }
  }

  /**
   * Append messages to the cache for a session.
   * Deduplicates by message ID.
   */
  private appendMessages(sessionId: string, newMessages: SessionMessage[]): void {
    let existing: SessionMessage[] = [];
    const cached: SessionMessage[] | undefined = this.messages.get(sessionId);
    if (cached !== undefined) {
      existing = cached;
    }

    for (let i: number = 0; i < newMessages.length; i++) {
      const msg: SessionMessage = newMessages[i];
      if (!this.containsMessage(existing, msg.id)) {
        existing.push(msg);
      }
    }

    this.messages.set(sessionId, existing);
  }

  /**
   * Insert a single message into the cache.
   * Places it in the correct position by seq number.
   */
  private insertMessage(sessionId: string, message: SessionMessage): void {
    let existing: SessionMessage[] = [];
    const cached: SessionMessage[] | undefined = this.messages.get(sessionId);
    if (cached !== undefined) {
      existing = cached;
    }

    // Deduplicate: skip if message with same ID exists
    if (this.containsMessage(existing, message.id)) {
      return;
    }

    // Insert in seq order
    let inserted: boolean = false;
    for (let i: number = 0; i < existing.length; i++) {
      if (existing[i].seq > message.seq) {
        existing.splice(i, 0, message);
        inserted = true;
        break;
      }
    }
    if (!inserted) {
      existing.push(message);
    }

    this.messages.set(sessionId, existing);
  }

  /**
   * Check if a message list contains a message with the given ID.
   */
  private containsMessage(messages: SessionMessage[], messageId: string): boolean {
    for (let i: number = 0; i < messages.length; i++) {
      if (messages[i].id === messageId) {
        return true;
      }
    }
    return false;
  }
}

export { MessageSync };
