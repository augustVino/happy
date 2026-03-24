/**
 * Wire types for auth and API communication.
 * Mirrors the RN client's auth-related types.
 */

/** Stored credentials (persisted in SecureStore). */
export class AuthCredentials {
  token: string = '';
  secret: string = '';

  constructor(token: string, secret: string) {
    this.token = token;
    this.secret = secret;
  }
}

/** Auth challenge request body sent to POST /v1/auth. */
export class AuthChallengeRequest {
  publicKey: string = '';
  challenge: string = '';
  signature: string = '';

  constructor(publicKey: string, challenge: string, signature: string) {
    this.publicKey = publicKey;
    this.challenge = challenge;
    this.signature = signature;
  }
}

/** Auth challenge response from POST /v1/auth. */
export class AuthChallengeResponse {
  token: string = '';

  constructor(token: string) {
    this.token = token;
  }
}

/** QR auth account request body sent to POST /v1/auth/account/request. */
export class QRAccountRequest {
  publicKey: string = '';

  constructor(publicKey: string) {
    this.publicKey = publicKey;
  }
}

/** QR auth account response states. */
export enum QRAuthState {
  REQUESTED = 'requested',
  AUTHORIZED = 'authorized',
}

/** QR auth account response from POST /v1/auth/account/request. */
export class QRAccountResponse {
  state: string = '';
  token: string = '';
  response: string = '';

  constructor(state: string, token: string, response: string) {
    this.state = state;
    this.token = token;
    this.response = response;
  }
}

/** QR auth temporary keypair. */
export class QRAuthKeyPair {
  publicKey: Uint8Array = new Uint8Array(0);
  secretKey: Uint8Array = new Uint8Array(0);

  constructor(publicKey: Uint8Array, secretKey: Uint8Array) {
    this.publicKey = publicKey;
    this.secretKey = secretKey;
  }
}
