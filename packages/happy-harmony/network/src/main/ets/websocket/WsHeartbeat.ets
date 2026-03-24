/**
 * WebSocket Heartbeat Manager.
 * Sends periodic application-layer ping frames and monitors for ACK responses.
 * If no pong is received within the timeout, reports a heartbeat failure.
 */
import { AckManager } from './AckManager';
import { HeartbeatConfig, DEFAULT_HEARTBEAT_CONFIG } from './WsTypes';
import { Logger } from 'common';

const TAG = 'WsHeartbeat';

/** Callback invoked when a heartbeat ping should be sent. */
type SendPingCallback = (id: string) => void;

/** Callback invoked when heartbeat fails (no pong received). */
type HeartbeatFailureCallback = () => void;

class WsHeartbeat {
  private config: HeartbeatConfig = DEFAULT_HEARTBEAT_CONFIG;
  private ackManager: AckManager = new AckManager();
  private intervalId: number = -1;
  private pingCounter: number = 0;
  private running: boolean = false;
  private sendPingCallback: SendPingCallback = (_id: string) => {};
  private failureCallback: HeartbeatFailureCallback = () => {};
  private consecutiveFailures: number = 0;
  private maxConsecutiveFailures: number = 3;

  constructor(ackManager: AckManager) {
    this.ackManager = ackManager;
  }

  /**
   * Start the heartbeat loop. Sends a ping every config.pingInterval ms.
   */
  start(sendPing: SendPingCallback, onFailure: HeartbeatFailureCallback): void {
    if (this.running) {
      Logger.warn(TAG, 'Heartbeat already running');
      return;
    }

    this.sendPingCallback = sendPing;
    this.failureCallback = onFailure;
    this.running = true;
    this.consecutiveFailures = 0;
    this.pingCounter = 0;

    Logger.info(TAG, 'Heartbeat started (interval=' + this.config.pingInterval +
      'ms, timeout=' + this.config.pingTimeout + 'ms)');

    // Send first ping immediately
    this.sendPing();

    // Schedule periodic pings
    this.intervalId = setInterval(() => {
      this.sendPing();
    }, this.config.pingInterval);
  }

  /**
   * Stop the heartbeat loop and clean up timers.
   */
  stop(): void {
    if (!this.running) {
      return;
    }

    this.running = false;

    if (this.intervalId >= 0) {
      clearInterval(this.intervalId);
      this.intervalId = -1;
    }

    // Remove any pending ping ACK requests
    if (this.currentPingId !== '') {
      this.ackManager.remove(this.currentPingId);
      this.currentPingId = '';
    }

    Logger.info(TAG, 'Heartbeat stopped');
  }

  /**
   * Called when a pong ACK is received. Resets the failure counter.
   */
  onPong(): void {
    this.consecutiveFailures = 0;
    Logger.debug(TAG, 'Pong received');
  }

  /**
   * Update heartbeat configuration. Takes effect on next ping cycle.
   */
  setConfig(config: HeartbeatConfig): void {
    this.config = config;
    Logger.info(TAG, 'Config updated (interval=' + config.pingInterval + 'ms, timeout=' +
      config.pingTimeout + 'ms)');
  }

  /** Check if the heartbeat is currently running. */
  isRunning(): boolean {
    return this.running;
  }

  private currentPingId: string = '';

  private sendPing(): void {
    if (!this.running) {
      return;
    }

    this.pingCounter++;
    const pingId: string = 'ping-' + this.pingCounter;
    this.currentPingId = pingId;

    Logger.debug(TAG, 'Sending ping: ' + pingId);

    // Register ACK expectation
    this.ackManager.register(pingId, this.config.pingTimeout).then(() => {
      this.onPong();
    }).catch(() => {
      this.handlePingTimeout(pingId);
    });

    // Send the ping frame via the callback
    this.sendPingCallback(pingId);
  }

  private handlePingTimeout(pingId: string): void {
    // Only handle if this is still the current ping
    if (pingId !== this.currentPingId) {
      return;
    }

    this.consecutiveFailures++;
    Logger.warn(TAG, 'Ping timeout: ' + pingId +
      ' (failures=' + this.consecutiveFailures + ')');

    if (this.consecutiveFailures >= this.maxConsecutiveFailures) {
      Logger.error(TAG, 'Max consecutive heartbeat failures reached (' +
        this.maxConsecutiveFailures + '), triggering failure callback');
      this.stop();
      this.failureCallback();
    }
  }
}

export { WsHeartbeat };
