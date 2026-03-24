/**
 * Authentication API endpoints.
 * Mirrors the RN client's auth flow.
 */
import { ApiClient } from './ApiClient';
import { AuthChallengeRequest } from 'common';
import { AuthChallengeResponse } from 'common';
import { QRAccountRequest } from 'common';
import { QRAccountResponse } from 'common';
import { Logger } from 'common';

const TAG = 'AuthApi';

/** Raw server response for POST /v1/auth. */
class AuthTokenResponse {
  token: string = '';
}

/** Raw server response for POST /v1/auth/account/request. */
class QRAccountRequestResponse {
  state: string = '';
  token: string = '';
  response: string = '';
}

class AuthApi {
  private static instance: AuthApi | null = null;

  private constructor() {}

  static getInstance(): AuthApi {
    if (AuthApi.instance === null) {
      AuthApi.instance = new AuthApi();
    }
    return AuthApi.instance;
  }

  /**
   * POST /v1/auth - Authenticate with Ed25519 challenge-response.
   * Returns JWT token on success.
   */
  async authenticate(request: AuthChallengeRequest): Promise<AuthChallengeResponse> {
    const apiClient: ApiClient = ApiClient.getInstance();
    const body: ESObject = {
      'publicKey': request.publicKey,
      'challenge': request.challenge,
      'signature': request.signature,
    };
    const response = await apiClient.post<AuthTokenResponse>('/v1/auth', body);
    if (!response.success || response.data === null) {
      Logger.error(TAG, `Auth failed: ${response.statusCode} ${response.errorMessage}`);
      throw new Error(`Authentication failed: ${response.errorMessage}`);
    }
    return new AuthChallengeResponse(response.data.token);
  }

  /**
   * POST /v1/auth/account/request - Register or poll QR auth request.
   * First call registers the public key, subsequent calls poll for authorization.
   */
  async qrAccountRequest(publicKeyBase64: string): Promise<QRAccountResponse> {
    const apiClient: ApiClient = ApiClient.getInstance();
    const body: ESObject = {
      'publicKey': publicKeyBase64,
    };
    const response = await apiClient.post<QRAccountRequestResponse>('/v1/auth/account/request', body);
    if (!response.success || response.data === null) {
      Logger.error(TAG, `QR auth request failed: ${response.statusCode} ${response.errorMessage}`);
      throw new Error(`QR auth request failed: ${response.errorMessage}`);
    }
    return new QRAccountResponse(
      response.data.state,
      response.data.token,
      response.data.response
    );
  }
}

export { AuthApi };
