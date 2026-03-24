/**
 * SessionRpc - Session-level RPC methods.
 *
 * Provides typed methods for all session-scoped operations such as
 * abort, allow, deny, bash, readFile, writeFile, etc.
 *
 * Each method constructs the appropriate params object, encrypts via
 * SessionEncryption, and delegates to RpcClient.call().
 *
 * Method name format: "{sessionId}:{methodName}"
 */
import { SessionEncryption } from 'encryption';
import { RpcClient } from './RpcClient';
import { RpcResult, BashParams, ReadFileParams, WriteFileParams,
  DirectoryParams, DirectoryTreeParams, RipgrepParams,
  PermissionActionParams, SwitchModeParams } from './RpcTypes';

const TAG = 'SessionRpc';

/** Session RPC method name constants. */
const METHOD_ABORT = 'abort';
const METHOD_ALLOW = 'allow';
const METHOD_DENY = 'deny';
const METHOD_SWITCH_MODE = 'switchMode';
const METHOD_BASH = 'bash';
const METHOD_READ_FILE = 'readFile';
const METHOD_WRITE_FILE = 'writeFile';
const METHOD_LIST_DIRECTORY = 'listDirectory';
const METHOD_GET_DIRECTORY_TREE = 'getDirectoryTree';
const METHOD_RIPGREP = 'ripgrep';
const METHOD_KILL_SESSION = 'killSession';

class SessionRpc {
  private static instance: SessionRpc | null = null;
  private rpcClient: RpcClient;
  private sessionEncryption: SessionEncryption;

  private constructor() {
    this.rpcClient = RpcClient.getInstance();
    this.sessionEncryption = SessionEncryption.getInstance();
  }

  static getInstance(): SessionRpc {
    if (SessionRpc.instance === null) {
      SessionRpc.instance = new SessionRpc();
    }
    return SessionRpc.instance;
  }

  /**
   * Abort the current operation in a session.
   */
  async abort(sessionId: string): Promise<RpcResult> {
    const method: string = sessionId + ':' + METHOD_ABORT;
    const params: ESObject = {};
    return this.rpcClient.call(
      method,
      params,
      (p: Object) => this.encrypt(sessionId, p),
      (c: string) => this.decrypt(sessionId, c)
    );
  }

  /**
   * Approve a permission request.
   */
  async allow(sessionId: string, requestId: string, mode: string): Promise<RpcResult> {
    const method: string = sessionId + ':' + METHOD_ALLOW;
    const params: PermissionActionParams = new PermissionActionParams();
    params.requestId = requestId;
    params.mode = mode;
    return this.rpcClient.call(
      method,
      params,
      (p: Object) => this.encrypt(sessionId, p),
      (c: string) => this.decrypt(sessionId, c)
    );
  }

  /**
   * Deny a permission request.
   */
  async deny(sessionId: string, requestId: string, mode: string): Promise<RpcResult> {
    const method: string = sessionId + ':' + METHOD_DENY;
    const params: PermissionActionParams = new PermissionActionParams();
    params.requestId = requestId;
    params.mode = mode;
    return this.rpcClient.call(
      method,
      params,
      (p: Object) => this.encrypt(sessionId, p),
      (c: string) => this.decrypt(sessionId, c)
    );
  }

  /**
   * Switch the agent mode for a session.
   */
  async switchMode(sessionId: string, mode: string): Promise<RpcResult> {
    const method: string = sessionId + ':' + METHOD_SWITCH_MODE;
    const params: SwitchModeParams = new SwitchModeParams();
    params.mode = mode;
    return this.rpcClient.call(
      method,
      params,
      (p: Object) => this.encrypt(sessionId, p),
      (c: string) => this.decrypt(sessionId, c)
    );
  }

  /**
   * Execute a Bash command on the remote machine via the session.
   */
  async bash(
    sessionId: string,
    command: string,
    cwd?: string,
    timeout?: number
  ): Promise<RpcResult> {
    const method: string = sessionId + ':' + METHOD_BASH;
    const params: BashParams = new BashParams();
    params.command = command;
    if (cwd !== undefined && cwd !== null) {
      params.cwd = cwd;
    }
    if (timeout !== undefined && timeout !== null) {
      params.timeout = timeout;
    }
    return this.rpcClient.call(
      method,
      params,
      (p: Object) => this.encrypt(sessionId, p),
      (c: string) => this.decrypt(sessionId, c),
      timeout
    );
  }

  /**
   * Read a file on the remote machine.
   */
  async readFile(sessionId: string, path: string): Promise<RpcResult> {
    const method: string = sessionId + ':' + METHOD_READ_FILE;
    const params: ReadFileParams = new ReadFileParams();
    params.path = path;
    return this.rpcClient.call(
      method,
      params,
      (p: Object) => this.encrypt(sessionId, p),
      (c: string) => this.decrypt(sessionId, c)
    );
  }

  /**
   * Write content to a file on the remote machine.
   */
  async writeFile(
    sessionId: string,
    path: string,
    content: string,
    expectedHash?: string
  ): Promise<RpcResult> {
    const method: string = sessionId + ':' + METHOD_WRITE_FILE;
    const params: WriteFileParams = new WriteFileParams();
    params.path = path;
    params.content = content;
    if (expectedHash !== undefined && expectedHash !== null) {
      params.expectedHash = expectedHash;
    }
    return this.rpcClient.call(
      method,
      params,
      (p: Object) => this.encrypt(sessionId, p),
      (c: string) => this.decrypt(sessionId, c)
    );
  }

  /**
   * List directory contents on the remote machine.
   */
  async listDirectory(sessionId: string, path: string): Promise<RpcResult> {
    const method: string = sessionId + ':' + METHOD_LIST_DIRECTORY;
    const params: DirectoryParams = new DirectoryParams();
    params.path = path;
    return this.rpcClient.call(
      method,
      params,
      (p: Object) => this.encrypt(sessionId, p),
      (c: string) => this.decrypt(sessionId, c)
    );
  }

  /**
   * Get a directory tree on the remote machine.
   */
  async getDirectoryTree(sessionId: string, path: string, maxDepth: number): Promise<RpcResult> {
    const method: string = sessionId + ':' + METHOD_GET_DIRECTORY_TREE;
    const params: DirectoryTreeParams = new DirectoryTreeParams();
    params.path = path;
    params.maxDepth = maxDepth;
    return this.rpcClient.call(
      method,
      params,
      (p: Object) => this.encrypt(sessionId, p),
      (c: string) => this.decrypt(sessionId, c)
    );
  }

  /**
   * Search files using ripgrep on the remote machine.
   */
  async ripgrep(sessionId: string, args: string[], cwd?: string): Promise<RpcResult> {
    const method: string = sessionId + ':' + METHOD_RIPGREP;
    const params: RipgrepParams = new RipgrepParams();
    params.args = args;
    if (cwd !== undefined && cwd !== null) {
      params.cwd = cwd;
    }
    return this.rpcClient.call(
      method,
      params,
      (p: Object) => this.encrypt(sessionId, p),
      (c: string) => this.decrypt(sessionId, c)
    );
  }

  /**
   * Kill (terminate) a session.
   */
  async killSession(sessionId: string): Promise<RpcResult> {
    const method: string = sessionId + ':' + METHOD_KILL_SESSION;
    const params: ESObject = {};
    return this.rpcClient.call(
      method,
      params,
      (p: Object) => this.encrypt(sessionId, p),
      (c: string) => this.decrypt(sessionId, c)
    );
  }

  /**
   * Encrypt params for a session.
   * Handles JSON.stringify internally, then delegates to SessionEncryption.encrypt().
   */
  private async encrypt(sessionId: string, params: Object): Promise<string | null> {
    const jsonString: string = JSON.stringify(params);
    return this.sessionEncryption.encrypt(sessionId, jsonString);
  }

  /**
   * Decrypt a result for a session.
   */
  private async decrypt(sessionId: string, cipherText: string): Promise<string | null> {
    return this.sessionEncryption.decrypt(sessionId, cipherText);
  }
}

export { SessionRpc };
