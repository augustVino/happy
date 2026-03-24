/**
 * Authentication service.
 * Orchestrates login, account creation, restore, and logout flows.
 */
import { AuthCredentials } from 'common';
import { AuthChallengeRequest } from 'common';
import { QRAuthKeyPair } from 'common';
import { QRAuthState } from 'common';
import { AuthState } from 'common';
import { SodiumCrypto } from 'common';
import { Base64Utils } from 'common';
import { ApiClient } from 'network';
import { AuthApi } from 'network';
import { TokenStore } from './TokenStore';
import { KeyManager } from './KeyManager';
import { CreateAccountResult } from './KeyManager';
import { Logger } from 'common';

const TAG = 'AuthService';

/** Result of an auth operation. */
export class AuthResult {
  success: boolean = false;
  token: string = '';
  errorMessage: string = '';
  backupKey: string = '';

  constructor(success: boolean, token: string, errorMessage: string, backupKey: string) {
    this.success = success;
    this.token = token;
    this.errorMessage = errorMessage;
    this.backupKey = backupKey;
  }
}

/** Callback for QR restore progress. */
interface QRProgressCallback {
  onProgress: (dots: number) => void;
}

class AuthService {
  private static instance: AuthService | null = null;

  private constructor() {}

  static getInstance(): AuthService {
    if (AuthService.instance === null) {
      AuthService.instance = new AuthService();
    }
    return AuthService.instance;
  }

  /**
   * Check if the user is currently authenticated.
   */
  async checkAuthState(): Promise<AuthState> {
    const tokenStore: TokenStore = TokenStore.getInstance();
    const hasCredentials: boolean = await tokenStore.hasCredentials();
    if (hasCredentials) {
      return AuthState.AUTHENTICATED;
    }
    return AuthState.UNAUTHENTICATED;
  }

  /**
   * Get stored credentials.
   */
  async getStoredCredentials(): Promise<AuthCredentials | null> {
    const tokenStore: TokenStore = TokenStore.getInstance();
    return tokenStore.getCredentials();
  }

  /**
   * Create a new account and authenticate.
   * Generates a random secret, sends challenge to server, stores credentials.
   */
  async createAccount(): Promise<AuthResult> {
    try {
      const keyManager: KeyManager = KeyManager.getInstance();
      const result: CreateAccountResult = keyManager.createAccount();

      if (result.challenge === null) {
        return new AuthResult(false, '', 'Failed to generate auth challenge', '');
      }

      const publicKeyBase64: string = Base64Utils.encode(result.challenge.publicKey);
      const challengeBase64: string = Base64Utils.encode(result.challenge.challenge);
      const signatureBase64: string = Base64Utils.encode(result.challenge.signature);

      const request: AuthChallengeRequest = new AuthChallengeRequest(
        publicKeyBase64, challengeBase64, signatureBase64
      );

      const authApi: AuthApi = AuthApi.getInstance();
      const authResponse = await authApi.authenticate(request);

      const secretBase64Url: string = result.secretBase64Url;
      const credentials: AuthCredentials = new AuthCredentials(authResponse.token, secretBase64Url);

      const tokenStore: TokenStore = TokenStore.getInstance();
      const saved: boolean = await tokenStore.setCredentials(credentials);
      if (!saved) {
        return new AuthResult(false, '', 'Failed to save credentials', '');
      }

      const apiClient: ApiClient = ApiClient.getInstance();
      apiClient.setAuthToken(authResponse.token);

      const backupKey: string = keyManager.encodeSecretForBackup(result.secret);

      Logger.info(TAG, 'Account created successfully');
      return new AuthResult(true, authResponse.token, '', backupKey);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Create account failed: ${errMsg}`);
      return new AuthResult(false, '', errMsg, '');
    }
  }

  /**
   * Login with an existing secret key.
   */
  async loginWithSecret(secretBase64Url: string): Promise<AuthResult> {
    try {
      const secret: Uint8Array = Base64Utils.decodeBase64Url(secretBase64Url);

      const keyManager: KeyManager = KeyManager.getInstance();
      const challenge = keyManager.generateAuthChallenge(secret);

      const publicKeyBase64: string = Base64Utils.encode(challenge.publicKey);
      const challengeBase64: string = Base64Utils.encode(challenge.challenge);
      const signatureBase64: string = Base64Utils.encode(challenge.signature);

      const request: AuthChallengeRequest = new AuthChallengeRequest(
        publicKeyBase64, challengeBase64, signatureBase64
      );

      const authApi: AuthApi = AuthApi.getInstance();
      const authResponse = await authApi.authenticate(request);

      const credentials: AuthCredentials = new AuthCredentials(authResponse.token, secretBase64Url);

      const tokenStore: TokenStore = TokenStore.getInstance();
      const saved: boolean = await tokenStore.setCredentials(credentials);
      if (!saved) {
        return new AuthResult(false, '', 'Failed to save credentials', '');
      }

      const apiClient: ApiClient = ApiClient.getInstance();
      apiClient.setAuthToken(authResponse.token);

      Logger.info(TAG, 'Login successful');
      return new AuthResult(true, authResponse.token, '', '');
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Login failed: ${errMsg}`);
      return new AuthResult(false, '', errMsg, '');
    }
  }

  /**
   * Start QR restore: generate temporary keypair and register with server.
   * Returns the keypair for QR code display and polling.
   */
  async startQRRestore(): Promise<QRAuthKeyPair | null> {
    try {
      const keyManager: KeyManager = KeyManager.getInstance();
      const keypair: QRAuthKeyPair = keyManager.generateQRAuthKeyPair();
      const publicKeyBase64: string = Base64Utils.encode(keypair.publicKey);

      const authApi: AuthApi = AuthApi.getInstance();
      const response = await authApi.qrAccountRequest(publicKeyBase64);

      if (response.state === QRAuthState.AUTHORIZED) {
        // Already authorized (unlikely on first call, but handle it)
        Logger.info(TAG, 'QR auth already authorized');
        return keypair;
      }

      Logger.info(TAG, 'QR restore request registered');
      return keypair;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Start QR restore failed: ${errMsg}`);
      return null;
    }
  }

  /**
   * Poll for QR authorization and complete restore.
   * Should be called after startQRRestore().
   */
  async pollQRRestore(
    keypair: QRAuthKeyPair,
    onProgress?: (dots: number) => void,
    shouldCancel?: () => boolean
  ): Promise<AuthResult> {
    const authApi: AuthApi = AuthApi.getInstance();
    const keyManager: KeyManager = KeyManager.getInstance();
    const publicKeyBase64: string = Base64Utils.encode(keypair.publicKey);
    let dots: number = 0;

    while (true) {
      if (shouldCancel !== undefined && shouldCancel()) {
        return new AuthResult(false, '', 'Restore cancelled', '');
      }

      try {
        const response = await authApi.qrAccountRequest(publicKeyBase64);

        if (response.state === QRAuthState.AUTHORIZED) {
          const encryptedResponse: Uint8Array = Base64Utils.decode(response.response);
          const secret: Uint8Array | null = keyManager.decryptQRResponse(
            encryptedResponse, keypair.secretKey
          );

          if (secret === null) {
            return new AuthResult(false, '', 'Failed to decrypt auth response', '');
          }

          // Login with the recovered secret
          const loginResult: AuthResult = await this.loginWithSecret(
            Base64Utils.encodeBase64Url(secret)
          );
          return loginResult;
        }
      } catch (e) {
        const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
        Logger.error(TAG, `QR poll error: ${errMsg}`);
        return new AuthResult(false, '', errMsg, '');
      }

      if (onProgress !== undefined) {
        onProgress(dots);
      }
      dots++;

      // Wait 1 second before next poll
      await this.sleep(1000);
    }
  }

  /**
   * Restore account with a manual key string (Base32 encoded).
   */
  async restoreWithKey(keyString: string): Promise<AuthResult> {
    try {
      const keyManager: KeyManager = KeyManager.getInstance();
      const secret: Uint8Array | null = keyManager.decodeSecretFromBackup(keyString);

      if (secret === null) {
        return new AuthResult(false, '', 'Invalid key format', '');
      }

      return await this.loginWithSecret(Base64Utils.encodeBase64Url(secret));
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Restore with key failed: ${errMsg}`);
      return new AuthResult(false, '', errMsg, '');
    }
  }

  /**
   * Logout and clear credentials.
   */
  async logout(): Promise<void> {
    const tokenStore: TokenStore = TokenStore.getInstance();
    await tokenStore.removeCredentials();
    const apiClient: ApiClient = ApiClient.getInstance();
    apiClient.clearAuthToken();
    Logger.info(TAG, 'Logged out');
  }

  /**
   * Restore session from stored credentials.
   * Sets the auth token on ApiClient if credentials exist.
   */
  async restoreSession(): Promise<AuthResult> {
    try {
      const tokenStore: TokenStore = TokenStore.getInstance();
      const credentials: AuthCredentials | null = await tokenStore.getCredentials();

      if (credentials === null) {
        return new AuthResult(false, '', 'No stored credentials', '');
      }

      const apiClient: ApiClient = ApiClient.getInstance();
      apiClient.setAuthToken(credentials.token);

      Logger.info(TAG, 'Session restored from stored credentials');
      return new AuthResult(true, credentials.token, '', '');
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Session restore failed: ${errMsg}`);
      return new AuthResult(false, '', errMsg, '');
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve: (value: void) => void) => {
      setTimeout(resolve, ms);
    });
  }
}

export { AuthService };
