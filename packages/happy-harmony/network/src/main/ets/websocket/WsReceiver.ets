/**
 * WebSocket Message Receiver.
 * Parses incoming raw frames and dispatches them to registered handlers
 * or resolves pending ACK requests via the AckManager.
 */
import { WsFrame } from './WsTypes';
import { AckManager } from './AckManager';
import { Logger } from 'common';

const TAG = 'WsReceiver';

/** Handler for a specific event type. */
type FrameHandler = (data: string) => void;

/** Internal record linking an event name to its handler. */
class HandlerEntry {
  event: string = '';
  handler: FrameHandler = (_data: string) => {};

  constructor(event: string, handler: FrameHandler) {
    this.event = event;
    this.handler = handler;
  }
}

/** Callback invoked when an error frame is received from the server. */
type ErrorHandler = (error: string) => void;

class WsReceiver {
  private handlers: HandlerEntry[] = [];
  private ackManager: AckManager = new AckManager();
  private errorHandler: ErrorHandler = (_error: string) => {};

  constructor(ackManager: AckManager) {
    this.ackManager = ackManager;
  }

  /**
   * Process a raw message string from the WebSocket.
   * Parses JSON, determines if it is an ACK or event frame,
   * and dispatches accordingly.
   */
  onMessage(rawFrame: string): void {
    let frame: WsFrame;
    try {
      frame = WsReceiver.parseFrame(rawFrame);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, 'Failed to parse frame: ' + errMsg);
      return;
    }

    Logger.debug(TAG, 'Received: ' + frame.event +
      (frame.id !== '' ? ' id=' + frame.id : ''));

    // Check if this is an ACK response
    if (frame.isAck()) {
      this.handleAck(frame);
      return;
    }

    // Check if this is an error frame
    if (frame.event === 'error') {
      this.handleError(frame);
      return;
    }

    // Dispatch to registered handler
    this.dispatchToHandler(frame);
  }

  /**
   * Register a handler for a specific event type.
   */
  registerHandler(event: string, handler: FrameHandler): void {
    // Remove existing handler for this event if any
    this.removeHandler(event);

    const entry: HandlerEntry = new HandlerEntry(event, handler);
    this.handlers.push(entry);
    Logger.debug(TAG, 'Registered handler for: ' + event);
  }

  /**
   * Remove the handler for a specific event type.
   */
  removeHandler(event: string): void {
    const index: number = this.findHandlerIndex(event);
    if (index >= 0) {
      this.handlers.splice(index, 1);
      Logger.debug(TAG, 'Removed handler for: ' + event);
    }
  }

  /**
   * Register a global error handler for server error frames.
   */
  onError(handler: ErrorHandler): void {
    this.errorHandler = handler;
  }

  /** Remove all registered handlers. */
  removeAllHandlers(): void {
    this.handlers = [];
    Logger.debug(TAG, 'All handlers removed');
  }

  private handleAck(frame: WsFrame): void {
    if (frame.id === '') {
      Logger.warn(TAG, 'ACK frame without id: ' + frame.event);
      return;
    }

    const ackData: string = frame.data;
    if (frame.error !== '') {
      this.ackManager.reject(frame.id, frame.error);
    } else {
      this.ackManager.resolve(frame.id, ackData);
    }
  }

  private handleError(frame: WsFrame): void {
    let errorMsg: string = '';
    try {
      const parsed: ESObject = JSON.parse(frame.data);
      errorMsg = (parsed['message'] as string) || frame.data;
    } catch (_e) {
      errorMsg = frame.data;
    }
    Logger.warn(TAG, 'Server error: ' + errorMsg);
    this.errorHandler(errorMsg);
  }

  private dispatchToHandler(frame: WsFrame): void {
    const index: number = this.findHandlerIndex(frame.event);
    if (index < 0) {
      Logger.debug(TAG, 'No handler registered for event: ' + frame.event);
      return;
    }

    const entry: HandlerEntry = this.handlers[index];
    entry.handler(frame.data);
  }

  private findHandlerIndex(event: string): number {
    for (let i: number = 0; i < this.handlers.length; i++) {
      if (this.handlers[i].event === event) {
        return i;
      }
    }
    return -1;
  }

  private static parseFrame(raw: string): WsFrame {
    const obj: ESObject = JSON.parse(raw);
    const event: string = (obj['event'] as string) || '';
    const id: string = (obj['id'] as string) || '';
    const error: string = (obj['error'] as string) || '';

    let data: string = '';
    if (obj['data'] !== undefined && obj['data'] !== null) {
      data = JSON.stringify(obj['data']);
    }

    return new WsFrame(event, id, data, error);
  }
}

export { WsReceiver };
