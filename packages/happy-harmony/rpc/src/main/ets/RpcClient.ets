/**
 * RpcClient - Generic RPC caller.
 *
 * Provides a single method `call()` that handles the full RPC lifecycle:
 * 1. Encrypt params using the provided encryption function
 * 2. Build the RPC call frame with method and encrypted params
 * 3. Send via WsTransport.request() and wait for ACK
 * 4. Decrypt the result using the provided decryption function
 * 5. Return a structured RpcResult
 *
 * Used by SessionRpc and MachineRpc for entity-specific methods.
 */
import { WsTransport } from 'network';
import { Logger } from 'common';
import { RpcResult, RpcCallParams, RpcCallResponse, parseRpcCallResponse } from './RpcTypes';

const TAG = 'RpcClient';

/** Default RPC timeout in milliseconds. */
const DEFAULT_TIMEOUT = 30000;

/** RPC event name sent over WebSocket. */
const RPC_EVENT = 'rpc-call';

class RpcClient {
  private static instance: RpcClient | null = null;
  private wsTransport: WsTransport;

  private constructor() {
    this.wsTransport = WsTransport.getInstance();
  }

  static getInstance(): RpcClient {
    if (RpcClient.instance === null) {
      RpcClient.instance = new RpcClient();
    }
    return RpcClient.instance;
  }

  /**
   * Perform an RPC call.
   *
   * @param method - RPC method name in format "{entityId}:{methodName}"
   * @param params - Plain params object to be encrypted and sent
   * @param encryptFn - Function that accepts a params object and returns
   *                    base64-encoded encrypted ciphertext (or null on failure).
   *                    Responsible for JSON.stringify + encryption internally.
   * @param decryptFn - Function that accepts base64 ciphertext and returns
   *                    the decrypted plaintext JSON string (or null on failure).
   * @param timeout - ACK timeout in ms (default 30000)
   * @returns RpcResult with ok, decrypted result JSON string, and optional error
   */
  async call(
    method: string,
    params: Object,
    encryptFn: (params: Object) => Promise<string | null>,
    decryptFn: (cipherText: string) => Promise<string | null>,
    timeout?: number
  ): Promise<RpcResult> {
    const result: RpcResult = new RpcResult();
    const effectiveTimeout: number = (timeout !== undefined && timeout !== null) ? timeout : DEFAULT_TIMEOUT;

    // Step 1: Encrypt params (encryptFn handles JSON.stringify internally)
    const encryptedParams: string | null = await encryptFn(params);
    if (encryptedParams === null) {
      Logger.error(TAG, 'Failed to encrypt params for method: ' + method);
      result.ok = false;
      result.error = 'Encryption failed';
      return result;
    }

    // Step 2: Build RPC call payload
    const callParams: RpcCallParams = new RpcCallParams();
    callParams.method = method;
    callParams.params = encryptedParams;

    // Step 3: Send request and wait for ACK
    let ackJson: string = '';
    try {
      ackJson = await this.wsTransport.request(RPC_EVENT, callParams, effectiveTimeout);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, 'RPC request failed for method ' + method + ': ' + errMsg);
      result.ok = false;
      result.error = errMsg;
      return result;
    }

    // Step 4: Parse ACK response
    const response: RpcCallResponse = parseRpcCallResponse(ackJson);

    if (!response.ok) {
      Logger.warn(TAG, 'RPC call failed for method ' + method + ': ' + response.error);
      result.ok = false;
      result.error = response.error;
      return result;
    }

    // Step 5: Decrypt result
    if (response.result === '') {
      // Empty result is valid (e.g., void operations)
      result.ok = true;
      result.result = '';
      return result;
    }

    const decryptedResult: string | null = await decryptFn(response.result);
    if (decryptedResult === null) {
      Logger.error(TAG, 'Failed to decrypt result for method: ' + method);
      result.ok = false;
      result.error = 'Decryption failed';
      return result;
    }

    result.ok = true;
    result.result = decryptedResult;
    return result;
  }
}

export { RpcClient };
