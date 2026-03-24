/**
 * Core data models for sessions, messages, machines, and user profile.
 * These are the domain objects used throughout the application.
 */

/** Represents a chat session. */
export class Session {
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
  // Decrypted cache fields
  decryptedTitle: string = '';
  decryptedAgentMode: string = '';
  isThinking: boolean = false;
  lastMessagePreview: string = '';
}

/** Represents a message within a session. */
export class SessionMessage {
  id: string = '';
  seq: number = 0;
  sessionId: string = '';
  localId: string = '';
  content: string = '';
  role: string = '';
  createdAt: number = 0;
  updatedAt: number = 0;
  // Decrypted cache fields
  decryptedContent: string = '';
  eventType: string = '';
  isThinking: boolean = false;
}

/** Represents a registered machine (CLI daemon). */
export class Machine {
  id: string = '';
  name: string = '';
  metadata: string = '';
  metadataVersion: number = 0;
  daemonState: string = '';
  daemonStateVersion: number = 0;
  active: boolean = false;
  activeAt: number = 0;
  createdAt: number = 0;
  updatedAt: number = 0;
  dataEncryptionKey: string = '';
  // Decrypted cache fields
  decryptedName: string = '';
  isOnline: boolean = false;
}

/** Represents the authenticated user's profile. */
export class UserProfile {
  id: string = '';
  firstName: string = '';
  lastName: string = '';
  avatar: string = '';
  github: string = '';
}

/** Message content types (from session envelope ev.t). */
export class MessageEventTypes {
  static readonly TEXT: string = 'text';
  static readonly SERVICE: string = 'service';
  static readonly TOOL_CALL_START: string = 'tool-call-start';
  static readonly TOOL_CALL_END: string = 'tool-call-end';
  static readonly FILE: string = 'file';
  static readonly TURN_START: string = 'turn-start';
  static readonly TURN_END: string = 'turn-end';
  static readonly STOP: string = 'stop';
  static readonly START: string = 'start';
}

/** Turn end status values. */
export class TurnEndStatus {
  static readonly COMPLETED: string = 'completed';
  static readonly FAILED: string = 'failed';
  static readonly CANCELLED: string = 'cancelled';
}

/** Message role values. */
export class MessageRoles {
  static readonly USER: string = 'user';
  static readonly AGENT: string = 'agent';
}
