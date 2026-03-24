/**
 * Machine REST API endpoints.
 * Provides read operations for registered machines.
 */
import { ApiClient } from './ApiClient';
import { Machine } from 'common';
import { Logger } from 'common';

const TAG = 'MachineApi';

class MachineApi {
  private static instance: MachineApi | null = null;

  private constructor() {}

  static getInstance(): MachineApi {
    if (MachineApi.instance === null) {
      MachineApi.instance = new MachineApi();
    }
    return MachineApi.instance;
  }

  /**
   * GET /v1/machines - Fetch all machines for the authenticated user.
   */
  async getMachines(): Promise<Machine[]> {
    const apiClient: ApiClient = ApiClient.getInstance();
    const response = await apiClient.get<Machine[]>('/v1/machines');
    if (!response.success || response.data === null) {
      Logger.error(TAG, `Failed to fetch machines: ${response.statusCode} ${response.errorMessage}`);
      throw new Error(`Failed to fetch machines: ${response.errorMessage}`);
    }
    return response.data;
  }
}

export { MachineApi };
