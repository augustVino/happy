/**
 * Account REST API endpoints.
 * Provides operations for the authenticated user's account.
 */
import { ApiClient } from './ApiClient';
import { UserProfile } from 'common';
import { Logger } from 'common';

const TAG = 'AccountApi';

class AccountApi {
  private static instance: AccountApi | null = null;

  private constructor() {}

  static getInstance(): AccountApi {
    if (AccountApi.instance === null) {
      AccountApi.instance = new AccountApi();
    }
    return AccountApi.instance;
  }

  /**
   * GET /v1/account/profile - Fetch the authenticated user's profile.
   */
  async getProfile(): Promise<UserProfile> {
    const apiClient: ApiClient = ApiClient.getInstance();
    const response = await apiClient.get<UserProfile>('/v1/account/profile');
    if (!response.success || response.data === null) {
      Logger.error(TAG, `Failed to fetch profile: ${response.statusCode} ${response.errorMessage}`);
      throw new Error(`Failed to fetch profile: ${response.errorMessage}`);
    }
    return response.data;
  }
}

export { AccountApi };
