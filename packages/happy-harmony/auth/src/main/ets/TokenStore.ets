/**
 * Token storage for JWT tokens and secrets.
 * Wraps SecureStore with a clean interface for auth operations.
 */
import { AuthCredentials } from 'common';
import { SecureStore } from 'encryption';
import { Logger } from 'common';

const TAG = 'TokenStore';

class TokenStore {
  private static instance: TokenStore | null = null;

  private constructor() {}

  static getInstance(): TokenStore {
    if (TokenStore.instance === null) {
      TokenStore.instance = new TokenStore();
    }
    return TokenStore.instance;
  }

  async getCredentials(): Promise<AuthCredentials | null> {
    const secureStore: SecureStore = await SecureStore.getInstance();
    return secureStore.getCredentials();
  }

  async setCredentials(credentials: AuthCredentials): Promise<boolean> {
    const secureStore: SecureStore = await SecureStore.getInstance();
    return secureStore.setCredentials(credentials);
  }

  async removeCredentials(): Promise<boolean> {
    const secureStore: SecureStore = await SecureStore.getInstance();
    return secureStore.removeCredentials();
  }

  async getToken(): Promise<string | null> {
    const credentials: AuthCredentials | null = await this.getCredentials();
    if (credentials === null) {
      return null;
    }
    return credentials.token;
  }

  async getSecret(): Promise<string | null> {
    const credentials: AuthCredentials | null = await this.getCredentials();
    if (credentials === null) {
      return null;
    }
    return credentials.secret;
  }

  async hasCredentials(): Promise<boolean> {
    const credentials: AuthCredentials | null = await this.getCredentials();
    return credentials !== null;
  }
}

export { TokenStore };
