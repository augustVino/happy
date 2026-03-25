/**
 * Server configuration constants.
 * Mirrors the RN client's serverConfig.ts.
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Logger } from '../utils/Logger';
import { AppContext } from '../utils/AppContext';

const TAG = 'ServerConfig';
const SERVER_URL_KEY = 'custom-server-url';
const PREFERENCES_NAME = 'happy-harmony-config';

const DEFAULT_SERVER_URL: string = 'http://10.66.142.27:3005';

class ServerConfig {
  private static instance: ServerConfig | null = null;
  private serverUrl: string = DEFAULT_SERVER_URL;
  private preferencesInstance: preferences.Preferences | null = null;
  private initialized: boolean = false;

  private constructor() {}

  static async getInstance(): Promise<ServerConfig> {
    if (ServerConfig.instance === null) {
      ServerConfig.instance = new ServerConfig();
    }
    if (!ServerConfig.instance.initialized) {
      await ServerConfig.instance.init();
    }
    return ServerConfig.instance;
  }

  private async init(): Promise<void> {
    try {
      const ctx: common.Context = AppContext.getContext();
      this.preferencesInstance = await preferences.getPreferences(ctx, PREFERENCES_NAME);
      const storedUrl: preferences.ValueType = await this.preferencesInstance.get(SERVER_URL_KEY, '');
      if (storedUrl !== '' && storedUrl !== null) {
        this.serverUrl = storedUrl as string;
      }
      this.initialized = true;
      Logger.info(TAG, 'ServerConfig initialized: ' + this.serverUrl);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, 'Failed to init ServerConfig: ' + errMsg);
      this.serverUrl = DEFAULT_SERVER_URL;
      this.initialized = true;
    }
  }

  getServerUrl(): string {
    return this.serverUrl;
  }

  async setServerUrl(url: string | null): Promise<void> {
    if (url !== null && url.trim() !== '') {
      this.serverUrl = url.trim();
    } else {
      this.serverUrl = DEFAULT_SERVER_URL;
    }
    if (this.preferencesInstance !== null) {
      try {
        await this.preferencesInstance.put(SERVER_URL_KEY, this.serverUrl);
        await this.preferencesInstance.flush();
      } catch (e) {
        const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
        Logger.error(TAG, 'Failed to save server URL: ' + errMsg);
      }
    }
  }

  isUsingCustomServer(): boolean {
    return this.serverUrl !== DEFAULT_SERVER_URL;
  }

  validateServerUrl(url: string): ServerUrlValidation {
    if (!url || url.trim() === '') {
      return new ServerUrlValidation(false, 'Server URL cannot be empty');
    }
    const trimmed: string = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return new ServerUrlValidation(false, 'Server URL must use HTTP or HTTPS protocol');
    }
    return new ServerUrlValidation(true, '');
  }
}

export class ServerUrlValidation {
  valid: boolean = false;
  error: string = '';

  constructor(valid: boolean, error: string) {
    this.valid = valid;
    this.error = error;
  }
}

export { ServerConfig, DEFAULT_SERVER_URL };
