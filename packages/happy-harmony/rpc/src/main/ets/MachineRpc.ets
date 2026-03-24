/**
 * MachineRpc - Machine-level RPC methods.
 *
 * Provides typed methods for machine-scoped operations such as
 * spawning sessions, stopping sessions, and stopping the daemon.
 *
 * Method name format: "{machineId}:{methodName}"
 *
 * Uses MachineEncryption for params/result encryption.
 */
import { MachineEncryption } from 'encryption';
import { RpcClient } from './RpcClient';
import { RpcResult, SpawnSessionParams, StopSessionParams } from './RpcTypes';

const TAG = 'MachineRpc';

/** Machine RPC method name constants. */
const METHOD_SPAWN_SESSION = 'spawnHappySession';
const METHOD_STOP_SESSION = 'stopSession';
const METHOD_STOP_DAEMON = 'stopDaemon';

class MachineRpc {
  private static instance: MachineRpc | null = null;
  private rpcClient: RpcClient;
  private machineEncryption: MachineEncryption;

  private constructor() {
    this.rpcClient = RpcClient.getInstance();
    this.machineEncryption = MachineEncryption.getInstance();
  }

  static getInstance(): MachineRpc {
    if (MachineRpc.instance === null) {
      MachineRpc.instance = new MachineRpc();
    }
    return MachineRpc.instance;
  }

  /**
   * Spawn a new Happy session on the remote machine.
   *
   * @param machineId - Target machine identifier
   * @param directory - Working directory for the session
   * @param sessionId - Optional pre-defined session ID
   * @param agent - Optional agent type (e.g., 'claude', 'codex')
   * @param env - Optional environment variables
   */
  async spawnHappySession(
    machineId: string,
    directory: string,
    sessionId?: string,
    agent?: string,
    env?: Object
  ): Promise<RpcResult> {
    const method: string = machineId + ':' + METHOD_SPAWN_SESSION;
    const params: SpawnSessionParams = new SpawnSessionParams();
    params.directory = directory;
    if (sessionId !== undefined && sessionId !== null) {
      params.sessionId = sessionId;
    }
    if (agent !== undefined && agent !== null) {
      params.agent = agent;
    }
    if (env !== undefined && env !== null) {
      params.env = env as ESObject;
    }
    return this.rpcClient.call(
      method,
      params,
      (p: Object) => this.encrypt(machineId, p),
      (c: string) => this.decrypt(machineId, c)
    );
  }

  /**
   * Stop a session on the remote machine.
   *
   * @param machineId - Target machine identifier
   * @param sessionId - Session to stop
   */
  async stopSession(machineId: string, sessionId: string): Promise<RpcResult> {
    const method: string = machineId + ':' + METHOD_STOP_SESSION;
    const params: StopSessionParams = new StopSessionParams();
    params.sessionId = sessionId;
    return this.rpcClient.call(
      method,
      params,
      (p: Object) => this.encrypt(machineId, p),
      (c: string) => this.decrypt(machineId, c)
    );
  }

  /**
   * Stop the Happy daemon on the remote machine.
   *
   * @param machineId - Target machine identifier
   */
  async stopDaemon(machineId: string): Promise<RpcResult> {
    const method: string = machineId + ':' + METHOD_STOP_DAEMON;
    const params: ESObject = {};
    return this.rpcClient.call(
      method,
      params,
      (p: Object) => this.encrypt(machineId, p),
      (c: string) => this.decrypt(machineId, c)
    );
  }

  /**
   * Encrypt params for a machine.
   * Delegates to MachineEncryption.encryptRpcParams() which handles
   * JSON.stringify internally.
   */
  private async encrypt(machineId: string, params: Object): Promise<string | null> {
    return this.machineEncryption.encryptRpcParams(machineId, params as ESObject);
  }

  /**
   * Decrypt a result for a machine.
   */
  private async decrypt(machineId: string, cipherText: string): Promise<string | null> {
    return this.machineEncryption.decryptRpcResult(machineId, cipherText);
  }
}

export { MachineRpc };
