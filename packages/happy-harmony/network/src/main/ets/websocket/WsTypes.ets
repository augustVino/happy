/**
 * WebSocket shared types and constants.
 */

/** A single frame exchanged over the WebSocket. */
export class WsFrame {
  event: string = '';
  id: string = '';
  data: string = '';
  error: string = '';

  constructor(event: string, id: string, data: string, error: string) {
    this.event = event;
    this.id = id;
    this.data = data;
    this.error = error;
  }

  /** Serialize to JSON string for sending. */
  toJSON(): string {
    const obj: ESObject = { 'event': this.event };
    if (this.id !== '') {
      obj['id'] = this.id;
    }
    if (this.data !== '') {
      obj['data'] = JSON.parse(this.data);
    }
    if (this.error !== '') {
      obj['error'] = this.error;
    }
    return JSON.stringify(obj);
  }

  /** Check if this frame is an ACK response (event ends with :ack). */
  isAck(): boolean {
    return this.event.endsWith(':ack');
  }

  /** Extract the original event name from an ACK event. */
  getOriginalEvent(): string {
    if (!this.isAck()) {
      return this.event;
    }
    return this.event.substring(0, this.event.length - 4);
  }
}

/** Connection state of the WebSocket transport. */
export class ConnectionState {
  static readonly DISCONNECTED: string = 'disconnected';
  static readonly CONNECTING: string = 'connecting';
  static readonly CONNECTED: string = 'connected';
  static readonly RECONNECTING: string = 'reconnecting';
}

/** Internal entry tracking a pending ACK request. */
export class AckEntry {
  resolve: (data: string) => void = () => {};
  reject: (error: string) => void = () => {};
  timerId: number = -1;

  constructor(resolve: (data: string) => void, reject: (error: string) => void, timerId: number) {
    this.resolve = resolve;
    this.reject = reject;
    this.timerId = timerId;
  }
}

/** Reconnection configuration. */
export class ReconnectConfig {
  baseDelay: number = 1000;
  maxDelay: number = 30000;
  multiplier: number = 2;

  constructor(baseDelay: number, maxDelay: number, multiplier: number) {
    this.baseDelay = baseDelay;
    this.maxDelay = maxDelay;
    this.multiplier = multiplier;
  }
}

/** Default reconnection config: exponential backoff 1s -> 2s -> 4s -> 8s -> 30s cap. */
export const DEFAULT_RECONNECT_CONFIG: ReconnectConfig = new ReconnectConfig(1000, 30000, 2);

/** Heartbeat configuration. */
export class HeartbeatConfig {
  pingInterval: number = 25000;
  pingTimeout: number = 10000;

  constructor(pingInterval: number, pingTimeout: number) {
    this.pingInterval = pingInterval;
    this.pingTimeout = pingTimeout;
  }
}

/** Default heartbeat config: 25s interval, 10s ACK timeout. */
export const DEFAULT_HEARTBEAT_CONFIG: HeartbeatConfig = new HeartbeatConfig(25000, 10000);
