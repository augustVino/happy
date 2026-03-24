/**
 * PermissionManager - Manages permission request queue and dialog lifecycle.
 *
 * When a permission request arrives (via WebSocket push), it is added to a
 * FIFO queue. The manager ensures only one dialog is shown at a time.
 * Approve/deny actions are delegated to SessionRpc.
 *
 * Usage:
 *   const manager = PermissionManager.getInstance();
 *   manager.addRequest(request);
 *   // When ready to show dialog:
 *   const current = manager.getCurrentRequest();
 */
import { SessionRpc } from 'rpc';
import { PermissionRequest, PermissionDialogCallback } from './PermissionDialog';

const TAG = 'PermissionManager';

class PermissionManager {
  private static instance: PermissionManager | null = null;
  private pendingRequests: PermissionRequest[] = [];
  private currentRequest: PermissionRequest | null = null;
  private sessionRpc: SessionRpc;
  private isProcessing: boolean = false;

  private constructor() {
    this.sessionRpc = SessionRpc.getInstance();
  }

  static getInstance(): PermissionManager {
    if (PermissionManager.instance === null) {
      PermissionManager.instance = new PermissionManager();
    }
    return PermissionManager.instance;
  }

  /**
   * Add a new permission request to the queue.
   * If no dialog is currently showing, this request becomes current immediately.
   */
  addRequest(request: PermissionRequest): void {
    if (request.id === '' || request.sessionId === '') {
      return;
    }
    this.pendingRequests.push(request);
    if (this.currentRequest === null) {
      this.advanceToNext();
    }
  }

  /**
   * Handle approve action from the dialog.
   * Calls SessionRpc.allow() and advances to the next pending request.
   */
  async handleApprove(requestId: string, mode: string): Promise<void> {
    if (this.currentRequest === null || this.currentRequest.id !== requestId) {
      return;
    }
    const sessionId: string = this.currentRequest.sessionId;
    this.isProcessing = true;
    try {
      await this.sessionRpc.allow(sessionId, requestId, mode);
    } catch (e) {
      // Log error but still advance queue
      const errorMsg: string = e instanceof Error ? e.message : String(e);
      console.error(TAG + ' handleApprove failed: ' + errorMsg);
    } finally {
      this.isProcessing = false;
      this.advanceToNext();
    }
  }

  /**
   * Handle deny action from the dialog.
   * Calls SessionRpc.deny() and advances to the next pending request.
   */
  async handleDeny(requestId: string): Promise<void> {
    if (this.currentRequest === null || this.currentRequest.id !== requestId) {
      return;
    }
    const sessionId: string = this.currentRequest.sessionId;
    const mode: string = this.currentRequest.toolName;
    this.isProcessing = true;
    try {
      await this.sessionRpc.deny(sessionId, requestId, mode);
    } catch (e) {
      // Log error but still advance queue
      const errorMsg: string = e instanceof Error ? e.message : String(e);
      console.error(TAG + ' handleDeny failed: ' + errorMsg);
    } finally {
      this.isProcessing = false;
      this.advanceToNext();
    }
  }

  /**
   * Get the current request that should be displayed in the dialog.
   * Returns null if there are no pending requests.
   */
  getCurrentRequest(): PermissionRequest | null {
    return this.currentRequest;
  }

  /**
   * Dismiss the current request without approve/deny.
   * Advances to the next pending request in the queue.
   */
  dismissCurrent(): void {
    this.advanceToNext();
  }

  /**
   * Check if there are pending requests waiting to be shown.
   */
  hasPendingRequests(): boolean {
    return this.pendingRequests.length > 0 || this.currentRequest !== null;
  }

  /**
   * Get the number of pending requests (including current).
   */
  getPendingCount(): number {
    let count: number = 0;
    if (this.currentRequest !== null) {
      count = 1;
    }
    return count + this.pendingRequests.length;
  }

  /**
   * Create a callback object wired to this manager's approve/deny/dismiss methods.
   * Pass this to PermissionDialog's callback property.
   */
  createCallback(): PermissionDialogCallback {
    const cb: PermissionDialogCallback = new PermissionDialogCallback();
    const manager: PermissionManager = this;
    cb.onApprove = (requestId: string, mode: string): void => {
      manager.handleApprove(requestId, mode);
    };
    cb.onDeny = (requestId: string): void => {
      manager.handleDeny(requestId);
    };
    cb.onDismiss = (): void => {
      manager.dismissCurrent();
    };
    return cb;
  }

  /**
   * Advance to the next pending request in the queue.
   */
  private advanceToNext(): void {
    this.currentRequest = null;
    if (this.pendingRequests.length > 0) {
      const shifted: PermissionRequest | undefined = this.pendingRequests.shift();
      if (shifted !== undefined) {
        this.currentRequest = shifted;
      }
    }
  }
}

export { PermissionManager };
