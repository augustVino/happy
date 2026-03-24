/**
 * Session REST API endpoints.
 * Provides CRUD operations for sessions and messages.
 */
import { ApiClient } from './ApiClient';
import { Session, SessionMessage } from 'common';
import { Logger } from 'common';

const TAG = 'SessionApi';

/** Raw server response for GET /v1/sessions. */
class SessionsResponse {
  sessions: Session[] = [];

  constructor(sessions: Session[] = []) {
    this.sessions = sessions;
  }
}

/** Raw server response for GET /v3/sessions/:id/messages. */
class MessagesResponse {
  messages: SessionMessage[] = [];
  hasMore: boolean = false;

  constructor(messages: SessionMessage[] = [], hasMore: boolean = false) {
    this.messages = messages;
    this.hasMore = hasMore;
  }
}

/** Request body for POST /v3/sessions/:id/messages. */
class SendMessageRequest {
  localId: string = '';
  content: string = '';

  constructor(localId: string, content: string) {
    this.localId = localId;
    this.content = content;
  }
}

/** Response body for POST /v3/sessions/:id/messages. */
class SendMessageResponse {
  messages: SendMessageRequest[] = [];

  constructor(messages: SendMessageRequest[] = []) {
    this.messages = messages;
  }
}

class SessionApi {
  private static instance: SessionApi | null = null;

  private constructor() {}

  static getInstance(): SessionApi {
    if (SessionApi.instance === null) {
      SessionApi.instance = new SessionApi();
    }
    return SessionApi.instance;
  }

  /**
   * GET /v1/sessions - Fetch all sessions for the authenticated user.
   */
  async getSessions(): Promise<Session[]> {
    const apiClient: ApiClient = ApiClient.getInstance();
    const response = await apiClient.get<Session[]>('/v1/sessions');
    if (!response.success || response.data === null) {
      Logger.error(TAG, `Failed to fetch sessions: ${response.statusCode} ${response.errorMessage}`);
      throw new Error(`Failed to fetch sessions: ${response.errorMessage}`);
    }
    return response.data;
  }

  /**
   * GET /v3/sessions/:id/messages - Fetch messages for a session.
   * Supports pagination via after_seq and limit.
   */
  async getMessages(sessionId: string, afterSeq: number = 0, limit: number = 100): Promise<MessagesResponse> {
    const apiClient: ApiClient = ApiClient.getInstance();
    const query: string = `?after_seq=${afterSeq}&limit=${limit}`;
    const path: string = `/v3/sessions/${sessionId}/messages${query}`;
    const response = await apiClient.get<MessagesResponse>(path);
    if (!response.success || response.data === null) {
      Logger.error(TAG, `Failed to fetch messages: ${response.statusCode} ${response.errorMessage}`);
      throw new Error(`Failed to fetch messages: ${response.errorMessage}`);
    }
    return response.data;
  }

  /**
   * POST /v3/sessions/:id/messages - Send messages to a session.
   */
  async sendMessage(sessionId: string, messages: SendMessageRequest[]): Promise<void> {
    const apiClient: ApiClient = ApiClient.getInstance();
    const path: string = `/v3/sessions/${sessionId}/messages`;
    const body: ESObject = {
      'messages': messages,
    };
    const response = await apiClient.post<SendMessageResponse>(path, body);
    if (!response.success) {
      Logger.error(TAG, `Failed to send messages: ${response.statusCode} ${response.errorMessage}`);
      throw new Error(`Failed to send messages: ${response.errorMessage}`);
    }
  }

  /**
   * DELETE /v1/sessions/:id - Delete a session.
   */
  async deleteSession(sessionId: string): Promise<void> {
    const apiClient: ApiClient = ApiClient.getInstance();
    const path: string = `/v1/sessions/${sessionId}`;
    const response = await apiClient.delete<null>(path);
    if (!response.success) {
      Logger.error(TAG, `Failed to delete session: ${response.statusCode} ${response.errorMessage}`);
      throw new Error(`Failed to delete session: ${response.errorMessage}`);
    }
  }
}

export { SessionApi, SendMessageRequest, MessagesResponse };
