/**
 * Application state types.
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
