/**
 * Secure credential storage using @ohos.data.preferences.
 * Provides encrypted key-value storage for auth credentials.
 */
import { preferences } from '@kit.ArkData';
import { AuthCredentials } from 'common';
import { Logger } from 'common';
import { AppContext } from 'common';

const TAG = 'SecureStore';
const CREDENTIALS_KEY = 'auth_credentials';
const PREFERENCES_NAME = 'happy-harmony-secure';

class CredentialJson {
  token: string = '';
  secret: string = '';

  constructor(token: string, secret: string) {
    this.token = token;
    this.secret = secret;
  }
}

class SecureStore {
  private static instance: SecureStore | null = null;
  private preferencesInstance: preferences.Preferences | null = null;
  private initialized: boolean = false;
  private memoryCache: AuthCredentials | null = null;

  private constructor() {}

  static async getInstance(): Promise<SecureStore> {
    if (SecureStore.instance === null) {
      SecureStore.instance = new SecureStore();
    }
    if (!SecureStore.instance.initialized) {
      await SecureStore.instance.init();
    }
    return SecureStore.instance;
  }

  private async init(): Promise<void> {
    try {
      const ctx = AppContext.getContext();
      this.preferencesInstance = await preferences.getPreferences(ctx, PREFERENCES_NAME);
      this.initialized = true;
      Logger.info(TAG, 'SecureStore initialized');
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to init SecureStore: ${errMsg}`);
      throw new Error(`SecureStore init failed: ${errMsg}`);
    }
  }

  async getCredentials(): Promise<AuthCredentials | null> {
    if (this.memoryCache !== null) {
      return this.memoryCache;
    }
    if (this.preferencesInstance === null) {
      return null;
    }
    try {
      const stored: preferences.ValueType = await this.preferencesInstance.get(CREDENTIALS_KEY, '');
      if (stored === '' || stored === null) {
        return null;
      }
      const jsonStr: string = stored as string;
      const parsed: CredentialJson = JSON.parse(jsonStr) as CredentialJson;
      const credentials: AuthCredentials = new AuthCredentials(parsed.token, parsed.secret);
      this.memoryCache = credentials;
      return credentials;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to get credentials: ${errMsg}`);
      return null;
    }
  }

  async setCredentials(credentials: AuthCredentials): Promise<boolean> {
    try {
      const jsonStr: string = JSON.stringify(credentials);
      this.memoryCache = credentials;
      if (this.preferencesInstance !== null) {
        await this.preferencesInstance.put(CREDENTIALS_KEY, jsonStr);
        await this.preferencesInstance.flush();
      }
      Logger.info(TAG, 'Credentials saved');
      return true;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to save credentials: ${errMsg}`);
      return false;
    }
  }

  async removeCredentials(): Promise<boolean> {
    try {
      this.memoryCache = null;
      if (this.preferencesInstance !== null) {
        await this.preferencesInstance.delete(CREDENTIALS_KEY);
        await this.preferencesInstance.flush();
      }
      Logger.info(TAG, 'Credentials removed');
      return true;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to remove credentials: ${errMsg}`);
      return false;
    }
  }

  hasCredentialsSync(): boolean {
    return this.memoryCache !== null;
  }
}

export { SecureStore };
