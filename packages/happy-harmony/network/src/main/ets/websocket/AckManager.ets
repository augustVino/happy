/**
 * ACK Manager - tracks pending requests awaiting server acknowledgment.
 * Each request registers a Promise; the manager resolves or rejects
 * when the matching ACK frame arrives or the timeout fires.
 */
import { AckEntry } from './WsTypes';
import { Logger } from 'common';

const TAG = 'AckManager';

/** Internal record linking a request id to its pending entry. */
class PendingRequest {
  id: string = '';
  entry: AckEntry = new AckEntry(() => {}, () => {}, -1);

  constructor(id: string, entry: AckEntry) {
    this.id = id;
    this.entry = entry;
  }
}

class AckManager {
  private pendingRequests: PendingRequest[] = [];

  /**
   * Register a pending request. Returns a Promise that resolves with
   * the ACK data string or rejects on timeout.
   */
  register(id: string, timeout: number): Promise<string> {
    return new Promise<string>((resolve: (data: string) => void, reject: (error: string) => void) => {
      const timerId: number = setTimeout(() => {
        this.reject(id, 'ACK timeout after ' + timeout + 'ms');
      }, timeout);

      const entry: AckEntry = new AckEntry(resolve, reject, timerId);
      const request: PendingRequest = new PendingRequest(id, entry);
      this.pendingRequests.push(request);
      Logger.debug(TAG, 'Registered pending request: ' + id);
    });
  }

  /**
   * Resolve a pending request by id. Returns true if a match was found.
   */
  resolve(id: string, data: string): boolean {
    const index: number = this.findIndex(id);
    if (index < 0) {
      Logger.warn(TAG, 'No pending request found for resolve: ' + id);
      return false;
    }

    const request: PendingRequest = this.pendingRequests[index];
    clearTimeout(request.entry.timerId);
    request.entry.resolve(data);
    this.pendingRequests.splice(index, 1);
    Logger.debug(TAG, 'Resolved pending request: ' + id);
    return true;
  }

  /**
   * Reject a pending request by id. Returns true if a match was found.
   */
  reject(id: string, error: string): boolean {
    const index: number = this.findIndex(id);
    if (index < 0) {
      Logger.warn(TAG, 'No pending request found for reject: ' + id);
      return false;
    }

    const request: PendingRequest = this.pendingRequests[index];
    clearTimeout(request.entry.timerId);
    request.entry.reject(error);
    this.pendingRequests.splice(index, 1);
    Logger.debug(TAG, 'Rejected pending request: ' + id + ' - ' + error);
    return true;
  }

  /**
   * Remove a pending request without resolving or rejecting.
   */
  remove(id: string): void {
    const index: number = this.findIndex(id);
    if (index >= 0) {
      const request: PendingRequest = this.pendingRequests[index];
      clearTimeout(request.entry.timerId);
      this.pendingRequests.splice(index, 1);
      Logger.debug(TAG, 'Removed pending request: ' + id);
    }
  }

  /**
   * Clear all pending requests, rejecting each with a disconnection message.
   * Called when the WebSocket connection drops.
   */
  clearAll(): void {
    const count: number = this.pendingRequests.length;
    for (let i: number = this.pendingRequests.length - 1; i >= 0; i--) {
      const request: PendingRequest = this.pendingRequests[i];
      clearTimeout(request.entry.timerId);
      request.entry.reject('Connection closed');
    }
    this.pendingRequests = [];
    if (count > 0) {
      Logger.info(TAG, 'Cleared ' + count + ' pending requests');
    }
  }

  /** Get the number of currently pending requests. */
  getPendingCount(): number {
    return this.pendingRequests.length;
  }

  private findIndex(id: string): number {
    for (let i: number = 0; i < this.pendingRequests.length; i++) {
      if (this.pendingRequests[i].id === id) {
        return i;
      }
    }
    return -1;
  }
}

export { AckManager };
