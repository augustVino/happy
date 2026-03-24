/**
 * Server Update event types.
 * Mirrors the happy-wire package's CoreUpdateBody discriminated union.
 *
 * Since ArkTS does not support discriminated unions or unknown/any,
 * body.t is checked at runtime after parsing the JSON string.
 */

/** Container for all server update events. */
export class UpdateContainer {
  id: string = '';
  seq: number = 0;
  body: string = '';
  createdAt: number = 0;

  constructor(id: string, seq: number, body: string, createdAt: number) {
    this.id = id;
    this.seq = seq;
    this.body = body;
    this.createdAt = createdAt;
  }
}

/** Versioned encrypted value (metadata, agentState, daemonState). */
export class VersionedEncryptedValue {
  version: number = 0;
  value: string = '';

  constructor(version: number = 0, value: string = '') {
    this.version = version;
    this.value = value;
  }
}

/** Versioned encrypted value that can be null. */
export class VersionedNullableEncryptedValue {
  version: number = 0;
  value: string = '';

  constructor(version: number = 0, value: string = '') {
    this.version = version;
    this.value = value;
  }

  isNull(): boolean {
    return this.value === '';
  }
}

// --- Update body types (body.t discriminant) ---

/** body.t === 'new-message' */
export class NewMessageBody {
  t: string = 'new-message';
  sid: string = '';
  messageId: string = '';
  messageSeq: number = 0;
  messageLocalId: string = '';
  messageContent: string = '';
  messageCreatedAt: number = 0;
  messageUpdatedAt: number = 0;

  constructor() {
    this.t = 'new-message';
  }
}

/** body.t === 'new-session' */
export class NewSessionBody {
  t: string = 'new-session';
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

  constructor() {
    this.t = 'new-session';
  }
}

/** body.t === 'update-session' */
export class UpdateSessionBody {
  t: string = 'update-session';
  id: string = '';
  metadata: string = '';
  metadataVersion: number = 0;
  agentState: string = '';
  agentStateVersion: number = 0;

  constructor() {
    this.t = 'update-session';
  }
}

/** body.t === 'delete-session' */
export class DeleteSessionBody {
  t: string = 'delete-session';
  sid: string = '';

  constructor() {
    this.t = 'delete-session';
  }
}

/** body.t === 'new-machine' */
export class NewMachineBody {
  t: string = 'new-machine';
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

  constructor() {
    this.t = 'new-machine';
  }
}

/** body.t === 'update-machine' */
export class UpdateMachineBody {
  t: string = 'update-machine';
  machineId: string = '';
  metadata: string = '';
  metadataVersion: number = 0;
  daemonState: string = '';
  daemonStateVersion: number = 0;
  active: boolean = false;
  activeAt: number = 0;

  constructor() {
    this.t = 'update-machine';
  }
}

/** body.t === 'update-account' */
export class UpdateAccountBody {
  t: string = 'update-account';
  id: string = '';

  constructor() {
    this.t = 'update-account';
  }
}

// --- Ephemeral event types ---

/** Generic ephemeral event wrapper. */
export class EphemeralEvent {
  type: string = '';
  id: string = '';
  data: string = '';

  constructor(type: string = '', id: string = '', data: string = '') {
    this.type = type;
    this.id = id;
    this.data = data;
  }
}

/** type === 'activity' */
export class ActivityEphemeral {
  type: string = 'activity';
  id: string = '';
  active: boolean = false;
  activeAt: number = 0;
  thinking: boolean = false;

  constructor() {
    this.type = 'activity';
  }
}

/** type === 'machine-activity' */
export class MachineActivityEphemeral {
  type: string = 'machine-activity';
  id: string = '';
  active: boolean = false;
  activeAt: number = 0;

  constructor() {
    this.type = 'machine-activity';
  }
}

/** type === 'usage' */
export class UsageEphemeral {
  type: string = 'usage';
  id: string = '';

  constructor() {
    this.type = 'usage';
  }
}
