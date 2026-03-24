/**
 * WebSocket Transport Layer.
 * Manages the WebSocket lifecycle: connection, reconnection with exponential
 * backoff, message routing, heartbeat, and ACK management.
 *
 * Uses @ohos.net.webSocket for the underlying WebSocket connection.
 *
 * Usage:
 *   const transport = WsTransport.getInstance();
 *   await transport.connect(token);
 *   transport.on('update', (data) => { ... });
 *   transport.send('message', { text: 'hello' });
 *   const result = await transport.request('rpc-call', { ... });
 *   transport.disconnect();
 */
import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ServerConfig } from 'common';
import { Logger } from 'common';
import { WsFrame, ConnectionState, ReconnectConfig, DEFAULT_RECONNECT_CONFIG } from './WsTypes';
import { AckManager } from './AckManager';
import { WsSender } from './WsSender';
import { WsReceiver } from './WsReceiver';
import { WsHeartbeat } from './WsHeartbeat';

const TAG = 'WsTransport';

/** Callback for state change notifications. */
type StateChangeCallback = (newState: string, oldState: string) => void;

/** Internal record linking an event name to its callback. */
class EventSubscription {
  event: string = '';
  callback: (data: string) => void = (_data: string) => {};

  constructor(event: string, callback: (data: string) => void) {
    this.event = event;
    this.callback = callback;
  }
}

class WsTransport {
  private static instance: WsTransport | null = null;

  private ws: webSocket.WebSocket | null = null;
  private ackManager: AckManager = new AckManager();
  private sender: WsSender | null = null;
  private receiver: WsReceiver | null = null;
  private heartbeat: WsHeartbeat | null = null;

  private state: string = ConnectionState.DISCONNECTED;
  private token: string = '';
  private reconnectConfig: ReconnectConfig = DEFAULT_RECONNECT_CONFIG;
  private reconnectDelay: number = DEFAULT_RECONNECT_CONFIG.baseDelay;
  private reconnectTimerId: number = -1;
  private intentionalClose: boolean = false;
  private stateChangeCallbacks: StateChangeCallback[] = [];
  private subscriptions: EventSubscription[] = [];

  private constructor() {}

  static getInstance(): WsTransport {
    if (WsTransport.instance === null) {
      WsTransport.instance = new WsTransport();
    }
    return WsTransport.instance;
  }

  /**
   * Connect to the WebSocket server with the given JWT token.
   * If already connected, disconnects first.
   */
  async connect(token: string): Promise<void> {
    if (this.state === ConnectionState.CONNECTED || this.state === ConnectionState.CONNECTING) {
      Logger.warn(TAG, 'Already connected or connecting, disconnecting first');
      this.disconnect();
    }

    this.token = token;
    this.intentionalClose = false;
    this.setState(ConnectionState.CONNECTING);

    await this.doConnect();
  }

  /**
   * Disconnect from the WebSocket server.
   * Stops heartbeat, clears pending ACKs, and cleans up resources.
   */
  disconnect(): void {
    this.intentionalClose = true;
    this.cancelReconnect();

    if (this.heartbeat !== null) {
      this.heartbeat.stop();
    }

    if (this.ackManager !== null) {
      this.ackManager.clearAll();
    }

    if (this.ws !== null) {
      try {
        // ws.close returns Promise<boolean>; fire-and-forget
        this.ws.close({ code: 1000, reason: 'Client disconnect' });
      } catch (_e) {
        // Ignore close errors
      }
      this.ws = null;
    }

    this.sender = null;
    this.receiver = null;
    this.heartbeat = null;
    this.setState(ConnectionState.DISCONNECTED);
    Logger.info(TAG, 'Disconnected');
  }

  /**
   * Send a push frame (fire-and-forget, no ACK expected).
   */
  send(event: string, data: Object): void {
    if (this.sender === null) {
      Logger.warn(TAG, 'Cannot send - not connected');
      return;
    }
    this.sender.sendPush(event, data);
  }

  /**
   * Send a request frame and wait for the ACK response.
   * @param event - The event name.
   * @param data - The payload object.
   * @param timeout - ACK timeout in milliseconds (default 30000).
   * @returns Promise resolving with the ACK data string.
   */
  request(event: string, data: Object, timeout: number): Promise<string> {
    if (this.sender === null) {
      return Promise.reject<string>('Not connected');
    }
    return this.sender.sendRequest(event, data, timeout);
  }

  /**
   * Register a handler for a server event.
   */
  on(event: string, handler: (data: string) => void): void {
    this.removeSubscription(event);
    const sub: EventSubscription = new EventSubscription(event, handler);
    this.subscriptions.push(sub);

    if (this.receiver !== null) {
      this.receiver.registerHandler(event, handler);
    }
  }

  /**
   * Remove the handler for a server event.
   */
  off(event: string): void {
    this.removeSubscription(event);
    if (this.receiver !== null) {
      this.receiver.removeHandler(event);
    }
  }

  /**
   * Get the current connection state.
   */
  getState(): string {
    return this.state;
  }

  /**
   * Register a callback for connection state changes.
   */
  onStateChange(callback: StateChangeCallback): void {
    this.stateChangeCallbacks.push(callback);
  }

  /**
   * Remove a state change callback.
   */
  offStateChange(callback: StateChangeCallback): void {
    const index: number = this.stateChangeCallbacks.indexOf(callback);
    if (index >= 0) {
      this.stateChangeCallbacks.splice(index, 1);
    }
  }

  // ---- Internal methods ----

  private async doConnect(): Promise<void> {
    try {
      const serverConfig: ServerConfig = await ServerConfig.getInstance();
      const serverUrl: string = serverConfig.getServerUrl();
      const wsUrl: string = serverUrl.replace('https://', 'wss://').replace('http://', 'ws://')
        + '/v1/ws?token=' + this.token + '&clientType=user-scoped';

      Logger.info(TAG, 'Connecting to: ' + wsUrl.replace(/token=[^&]+/, 'token=***'));

      this.ws = webSocket.createWebSocket();
      this.setupInternalComponents();
      this.registerWsCallbacks();

      const connected: boolean = await this.ws.connect(wsUrl);
      if (!connected) {
        Logger.error(TAG, 'connect() returned false');
        this.setState(ConnectionState.DISCONNECTED);
        if (!this.intentionalClose) {
          this.scheduleReconnect();
        }
      }
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, 'Connection failed: ' + errMsg);
      this.setState(ConnectionState.DISCONNECTED);
      if (!this.intentionalClose) {
        this.scheduleReconnect();
      }
    }
  }

  private registerWsCallbacks(): void {
    if (this.ws === null) {
      return;
    }

    this.ws.on('open', (err: BusinessError, value: Object) => {
      if (err) {
        Logger.error(TAG, 'Open error: ' + err.message);
        return;
      }
      this.handleOpen();
    });

    this.ws.on('message', (err: BusinessError, value: string | ArrayBuffer) => {
      if (err) {
        Logger.error(TAG, 'Message error: ' + err.message);
        return;
      }
      this.handleRawMessage(value);
    });

    this.ws.on('close', (err: BusinessError, value: webSocket.CloseResult) => {
      if (err) {
        Logger.warn(TAG, 'Close error: ' + err.message);
        this.handleClose(0, err.message);
        return;
      }
      this.handleClose(value.code, value.reason);
    });

    this.ws.on('error', (err: BusinessError) => {
      this.handleError(err.message);
    });
  }

  private handleOpen(): void {
    Logger.info(TAG, 'Connection established');
    this.setState(ConnectionState.CONNECTED);
    this.reconnectDelay = this.reconnectConfig.baseDelay;

    if (this.heartbeat !== null) {
      this.heartbeat.start(
        (id: string) => {
          this.sendPing(id);
        },
        () => {
          this.onHeartbeatFailure();
        }
      );
    }
  }

  private handleRawMessage(data: string | ArrayBuffer): void {
    if (this.receiver === null) {
      return;
    }

    let messageStr: string = '';
    if (typeof data === 'string') {
      messageStr = data;
    } else {
      // ArrayBuffer -> string: convert bytes one by one to avoid spread/apply
      const bytes: Uint8Array = new Uint8Array(data as ArrayBuffer);
      let result: string = '';
      for (let i: number = 0; i < bytes.length; i++) {
        result = result + String.fromCharCode(bytes[i]);
      }
      messageStr = result;
    }

    if (messageStr === '') {
      return;
    }

    this.receiver.onMessage(messageStr);
  }

  private handleError(error: string): void {
    Logger.error(TAG, 'WebSocket error: ' + error);
  }

  private handleClose(code: number, reason: string): void {
    Logger.info(TAG, 'Connection closed: code=' + code + ' reason=' + reason);

    if (this.heartbeat !== null) {
      this.heartbeat.stop();
    }

    this.ackManager.clearAll();
    this.ws = null;
    this.sender = null;

    if (!this.intentionalClose) {
      this.setState(ConnectionState.RECONNECTING);
      this.scheduleReconnect();
    } else {
      this.setState(ConnectionState.DISCONNECTED);
    }
  }

  private sendPing(id: string): void {
    if (this.sender === null) {
      return;
    }
    const frame: WsFrame = new WsFrame('ping', id, '', '');
    this.sender.sendRawFrame(frame.toJSON());
  }

  private onHeartbeatFailure(): void {
    Logger.error(TAG, 'Heartbeat failure - forcing reconnection');
    if (this.ws !== null) {
      try {
        // ws.close returns Promise<boolean>; fire-and-forget
        this.ws.close({ code: 1001, reason: 'Heartbeat failure' });
      } catch (_e) {
        // Ignore
      }
    }
  }

  private scheduleReconnect(): void {
    if (this.intentionalClose || this.token === '') {
      return;
    }

    this.cancelReconnect();

    Logger.info(TAG, 'Reconnecting in ' + this.reconnectDelay + 'ms');

    this.reconnectTimerId = setTimeout(() => {
      this.reconnectTimerId = -1;
      this.doConnect();
    }, this.reconnectDelay);

    // Exponential backoff
    const nextDelay: number = this.reconnectDelay * this.reconnectConfig.multiplier;
    this.reconnectDelay = nextDelay > this.reconnectConfig.maxDelay
      ? this.reconnectConfig.maxDelay
      : nextDelay;
  }

  private cancelReconnect(): void {
    if (this.reconnectTimerId >= 0) {
      clearTimeout(this.reconnectTimerId);
      this.reconnectTimerId = -1;
    }
  }

  private setupInternalComponents(): void {
    this.ackManager = new AckManager();

    // Create sender with a sendRaw that writes to the current ws
    this.sender = new WsSender(
      (data: string): boolean => {
        if (this.ws === null) {
          return false;
        }
        try {
          // ws.send returns Promise<boolean>; fire-and-forget here
          // and assume success since the WebSocket is in connected state
          this.ws.send(data);
          return true;
        } catch (_e) {
          return false;
        }
      },
      this.ackManager
    );

    // Create receiver
    this.receiver = new WsReceiver(this.ackManager);
    this.receiver.onError((error: string) => {
      Logger.error(TAG, 'Server error: ' + error);
    });

    // Re-register existing subscriptions
    for (let i: number = 0; i < this.subscriptions.length; i++) {
      const sub: EventSubscription = this.subscriptions[i];
      this.receiver.registerHandler(sub.event, sub.callback);
    }

    // Create heartbeat
    this.heartbeat = new WsHeartbeat(this.ackManager);
  }

  private setState(newState: string): void {
    const oldState: string = this.state;
    if (oldState === newState) {
      return;
    }

    this.state = newState;
    Logger.info(TAG, 'State: ' + oldState + ' -> ' + newState);

    // Notify callbacks (iterate copy to allow removal during callback)
    const callbacks: StateChangeCallback[] = [];
    for (let i: number = 0; i < this.stateChangeCallbacks.length; i++) {
      callbacks.push(this.stateChangeCallbacks[i]);
    }
    for (let i: number = 0; i < callbacks.length; i++) {
      callbacks[i](newState, oldState);
    }
  }

  private removeSubscription(event: string): void {
    const index: number = this.findSubscriptionIndex(event);
    if (index >= 0) {
      this.subscriptions.splice(index, 1);
    }
  }

  private findSubscriptionIndex(event: string): number {
    for (let i: number = 0; i < this.subscriptions.length; i++) {
      if (this.subscriptions[i].event === event) {
        return i;
      }
    }
    return -1;
  }
}

export { WsTransport };
