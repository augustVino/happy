export class AppConstants {
  static readonly APP_NAME: string = 'Happy Coder';
  static readonly APP_VERSION: string = '0.0.1';

  static readonly WS_RECONNECT_BASE_DELAY: number = 1000;
  static readonly WS_RECONNECT_MAX_DELAY: number = 30000;
  static readonly WS_HEARTBEAT_INTERVAL: number = 30000;
  static readonly WS_ACK_TIMEOUT: number = 10000;

  static readonly SYNC_INITIAL_PULL_LIMIT: number = 50;
  static readonly SYNC_POLL_INTERVAL: number = 5000;

  private constructor() {}
}
