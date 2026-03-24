/**
 * RPC type definitions for the Happy Coder RPC module.
 *
 * Defines the data structures used for RPC call requests and responses,
 * as well as parameter types for session-level and machine-level RPC methods.
 */

/** Result of an RPC call, returned to callers after decryption. */
export class RpcResult {
  ok: boolean = false;
  result: string = '';
  error: string = '';
}

/** RPC call payload sent over WebSocket. */
export class RpcCallParams {
  method: string = '';
  params: string = '';
}

/** RPC ACK response payload received from the server. */
export class RpcCallResponse {
  ok: boolean = false;
  result: string = '';
  error: string = '';
}

/** Parameters for a remote Bash execution. */
export class BashParams {
  command: string = '';
  cwd: string = '';
  timeout: number = 0;
}

/** Parameters for a file read operation. */
export class ReadFileParams {
  path: string = '';
}

/** Parameters for a file write operation. */
export class WriteFileParams {
  path: string = '';
  content: string = '';
  expectedHash: string = '';
}

/** Parameters for spawning a new session. */
export class SpawnSessionParams {
  directory: string = '';
  sessionId: string = '';
  agent: string = '';
  env: ESObject = {};
}

/** Parameters for a directory listing. */
export class DirectoryParams {
  path: string = '';
}

/** Parameters for a directory tree query. */
export class DirectoryTreeParams {
  path: string = '';
  maxDepth: number = 0;
}

/** Parameters for a ripgrep search. */
export class RipgrepParams {
  args: string[] = [];
  cwd: string = '';
}

/** Parameters for an abort/allow/deny permission action. */
export class PermissionActionParams {
  requestId: string = '';
  mode: string = '';
}

/** Parameters for a mode switch action. */
export class SwitchModeParams {
  mode: string = '';
}

/** Parameters for stopping a session on a machine. */
export class StopSessionParams {
  sessionId: string = '';
}

/**
 * Parse an RPC ACK JSON string into an RpcCallResponse instance.
 * Handles the case where 'result' or 'error' may be missing.
 */
export function parseRpcCallResponse(jsonStr: string): RpcCallResponse {
  const response: RpcCallResponse = new RpcCallResponse();
  try {
    const parsed: ESObject = JSON.parse(jsonStr) as ESObject;
    if (parsed['ok'] !== undefined) {
      response.ok = parsed['ok'] as boolean;
    }
    if (parsed['result'] !== undefined && parsed['result'] !== null) {
      response.result = parsed['result'] as string;
    }
    if (parsed['error'] !== undefined && parsed['error'] !== null) {
      response.error = parsed['error'] as string;
    }
  } catch (_e) {
    // Return default error response on parse failure
    response.ok = false;
    response.error = 'Failed to parse RPC response';
  }
  return response;
}
