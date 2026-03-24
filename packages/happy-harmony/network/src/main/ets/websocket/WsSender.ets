/**
 * WebSocket Message Sender.
 * Provides typed methods for sending push (fire-and-forget) and
 * request (await-ACK) frames over the WebSocket connection.
 */
import { WsFrame } from './WsTypes';
import { AckManager } from './AckManager';
import { Logger } from 'common';

const TAG = 'WsSender';

/** Callback for sending raw string data over the WebSocket. */
type SendRawCallback = (data: string) => boolean;

/** Callback for generating unique request IDs. */
type IdGenerator = () => string;

class WsSender {
  private sendRaw: SendRawCallback = (_data: string) => false;
  private ackManager: AckManager = new AckManager();
  private idGenerator: IdGenerator = () => '';
  private nextId: number = 0;

  constructor(sendRaw: SendRawCallback, ackManager: AckManager) {
    this.sendRaw = sendRaw;
    this.ackManager = ackManager;
    this.idGenerator = () => {
      this.nextId++;
      return 'req-' + this.nextId + '-' + Date.now();
    };
  }

  /**
   * Send a push frame (fire-and-forget, no ACK expected).
   * @param event - The event name (e.g. 'message', 'session-end').
   * @param data - The payload object.
   */
  sendPush(event: string, data: Object): void {
    const dataStr: string = JSON.stringify(data);
    const frame: WsFrame = new WsFrame(event, '', dataStr, '');
    const json: string = frame.toJSON();

    Logger.debug(TAG, 'Push: ' + event);

    const sent: boolean = this.sendRaw(json);
    if (!sent) {
      Logger.warn(TAG, 'Failed to send push frame: ' + event);
    }
  }

  /**
   * Send a request frame that expects an ACK response.
   * @param event - The event name (e.g. 'rpc-call', 'update-metadata').
   * @param data - The payload object.
   * @param timeout - ACK timeout in milliseconds (default 30000).
   * @returns Promise that resolves with the ACK data string.
   */
  sendRequest(event: string, data: Object, timeout: number): Promise<string> {
    const id: string = this.idGenerator();
    const dataStr: string = JSON.stringify(data);
    const frame: WsFrame = new WsFrame(event, id, dataStr, '');
    const json: string = frame.toJSON();

    Logger.debug(TAG, 'Request: ' + event + ' id=' + id);

    const sent: boolean = this.sendRaw(json);
    if (!sent) {
      return Promise.reject<string>('Failed to send request frame: ' + event);
    }

    return this.ackManager.register(id, timeout);
  }

  /**
   * Send a raw JSON string. Used for ping frames from heartbeat.
   */
  sendRawFrame(json: string): boolean {
    return this.sendRaw(json);
  }

  /** Update the underlying send callback (e.g. after reconnection). */
  setSendRaw(sendRaw: SendRawCallback): void {
    this.sendRaw = sendRaw;
  }
}

export { WsSender };
