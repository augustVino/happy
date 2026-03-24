/**
 * HTTP client wrapper using @ohos.net.http.
 * Provides typed request methods for API communication.
 */
import { http } from '@kit.NetworkKit';
import { ServerConfig } from 'common';
import { Logger } from 'common';

const TAG = 'ApiClient';


/** API response wrapper. */
export class ApiResponse<T> {
  success: boolean = false;
  data: T | null = null;
  statusCode: number = 0;
  errorMessage: string = '';

  constructor(success: boolean, data: T | null, statusCode: number, errorMessage: string) {
    this.success = success;
    this.data = data;
    this.statusCode = statusCode;
    this.errorMessage = errorMessage;
  }
}

class ApiClient {
  private static instance: ApiClient | null = null;
  private authToken: string = '';

  private constructor() {}

  static getInstance(): ApiClient {
    if (ApiClient.instance === null) {
      ApiClient.instance = new ApiClient();
    }
    return ApiClient.instance;
  }

  setAuthToken(token: string): void {
    this.authToken = token;
  }

  clearAuthToken(): void {
    this.authToken = '';
  }

  hasAuthToken(): boolean {
    return this.authToken !== '';
  }

  private buildHeaders(): Map<string, string> {
    const headers: Map<string, string> = new Map();
    headers.set('Content-Type', 'application/json');
    if (this.authToken !== '') {
      headers.set('Authorization', 'Bearer ' + this.authToken);
    }
    return headers;
  }

  async get<T>(path: string): Promise<ApiResponse<T>> {
    return this.request<T>(http.RequestMethod.GET, path, null);
  }

  async post<T>(path: string, body: ESObject | null): Promise<ApiResponse<T>> {
    return this.request<T>(http.RequestMethod.POST, path, body);
  }

  async put<T>(path: string, body: ESObject | null): Promise<ApiResponse<T>> {
    return this.request<T>(http.RequestMethod.PUT, path, body);
  }

  async delete<T>(path: string): Promise<ApiResponse<T>> {
    return this.request<T>(http.RequestMethod.DELETE, path, null);
  }

  private async request<T>(method: http.RequestMethod, path: string, body: ESObject | null): Promise<ApiResponse<T>> {
    const serverConfig: ServerConfig = await ServerConfig.getInstance();
    const baseUrl: string = serverConfig.getServerUrl();
    const fullUrl: string = baseUrl + path;

    Logger.info(TAG, `${method} ${fullUrl}`);

    try {
      const httpRequest: http.HttpRequest = http.createHttp();
      const headers: Map<string, string> = this.buildHeaders();
      const headerObj: ESObject = {};
      headers.forEach((value: string, key: string) => {
        headerObj[key] = value;
      });

      const options: http.HttpRequestOptions = {
        method: method,
        header: headerObj,
        extraData: body !== null ? JSON.stringify(body) : undefined,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000,
      };

      const response: http.HttpResponse = await httpRequest.request(fullUrl, options);
      const statusCode: number = response.responseCode;

      Logger.info(TAG, `${method} ${path} → ${statusCode}`);

      if (statusCode >= 200 && statusCode < 300) {
        const result: T = this.parseResponse<T>(response.result as string);
        httpRequest.destroy();
        return new ApiResponse<T>(true, result, statusCode, '');
      } else {
        const errMsg: string = response.result as string;
        httpRequest.destroy();
        return new ApiResponse<T>(false, null, statusCode, errMsg);
      }
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Request failed: ${method} ${path} - ${errMsg}`);
      return new ApiResponse<T>(false, null, 0, errMsg);
    }
  }

  private parseResponse<T>(responseStr: string): T {
    try {
      return JSON.parse(responseStr) as T;
    } catch (e) {
      Logger.error(TAG, `Failed to parse response JSON`);
      throw new Error('Invalid JSON response');
    }
  }
}

export { ApiClient };
