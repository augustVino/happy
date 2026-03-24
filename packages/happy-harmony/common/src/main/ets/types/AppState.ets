/**
 * Application state types and global state keys.
 */

/** Auth state of the application. */
export enum AuthState {
  UNKNOWN = 'unknown',
  AUTHENTICATED = 'authenticated',
  UNAUTHENTICATED = 'unauthenticated',
}

/** Restore method type. */
export enum RestoreMethod {
  QR_CODE = 'qr_code',
  MANUAL_KEY = 'manual_key',
}

/** Global application state keys for StateStore. */
export class AppStateKeys {
  static readonly IS_CONNECTED: string = 'isConnected';
  static readonly IS_DATA_READY: string = 'isDataReady';
  static readonly USER_ID: string = 'userId';
  static readonly ACTIVE_SESSION_ID: string = 'activeSessionId';
}
