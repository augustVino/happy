/**
 * Machine-level encryption and decryption.
 *
 * Handles RPC params encryption/decryption for machine communication
 * using the machine's DEK (Data Encryption Key).
 *
 * Similar to SessionEncryption but operates on machineId instead of sessionId.
 * Uses AES-256-GCM for all encryption.
 */
import { DataKeyManager } from './DataKeyManager';
import { AesGcmCrypto } from './AesGcmCrypto';
import { BufferUtils } from 'common';
import { Base64Utils } from 'common';
import { Logger } from 'common';

const TAG = 'MachineEncryption';

/** Message format version byte for AES-256-GCM */
const MSG_VERSION_AES_GCM = 0x00;
const MSG_VERSION_SIZE = 1;

class MachineEncryption {
  private static instance: MachineEncryption | null = null;
  private dataKeyManager: DataKeyManager;

  private constructor() {
    this.dataKeyManager = DataKeyManager.getInstance();
  }

  static getInstance(): MachineEncryption {
    if (MachineEncryption.instance === null) {
      MachineEncryption.instance = new MachineEncryption();
    }
    return MachineEncryption.instance;
  }

  /**
   * Encrypt RPC params for a machine.
   * Format: JSON.stringify(params) -> AES-GCM encrypt -> version prefix -> base64
   *
   * @param machineId Machine identifier
   * @param params Object to encrypt
   * @returns Base64-encoded encrypted params, or null on failure
   */
  async encryptRpcParams(machineId: string, params: ESObject): Promise<string | null> {
    const dek = this.dataKeyManager.getDataKey(machineId);
    if (dek === null) {
      Logger.error(TAG, `No DEK found for machine: ${machineId}`);
      return null;
    }

    const jsonString: string = JSON.stringify(params);
    const plaintextBytes = BufferUtils.fromUtf8String(jsonString);
    const encrypted = await AesGcmCrypto.encrypt(plaintextBytes, dek);
    if (encrypted === null) {
      Logger.error(TAG, `AES-GCM encrypt failed for machine: ${machineId}`);
      return null;
    }

    // Prepend version byte
    const versioned = new Uint8Array(MSG_VERSION_SIZE + encrypted.length);
    versioned[0] = MSG_VERSION_AES_GCM;
    versioned.set(encrypted, MSG_VERSION_SIZE);

    return Base64Utils.encode(versioned);
  }

  /**
   * Decrypt RPC result for a machine.
   *
   * @param machineId Machine identifier
   * @param encryptedResult Base64-encoded encrypted result
   * @returns Decrypted JSON string, or null on failure
   */
  async decryptRpcResult(machineId: string, encryptedResult: string): Promise<string | null> {
    const dek = this.dataKeyManager.getDataKey(machineId);
    if (dek === null) {
      Logger.error(TAG, `No DEK found for machine: ${machineId}`);
      return null;
    }

    let encryptedBytes: Uint8Array;
    try {
      encryptedBytes = Base64Utils.decode(encryptedResult);
    } catch (e) {
      Logger.error(TAG, `Failed to decode base64: ${e}`);
      return null;
    }

    if (encryptedBytes.length < MSG_VERSION_SIZE) {
      Logger.error(TAG, 'Encrypted data too short');
      return null;
    }

    const version: number = encryptedBytes[0];
    if (version !== MSG_VERSION_AES_GCM) {
      Logger.error(TAG, `Unsupported version: ${version}`);
      return null;
    }

    const encryptedPayload = BufferUtils.slice(encryptedBytes, MSG_VERSION_SIZE);
    const decrypted = await AesGcmCrypto.decrypt(encryptedPayload, dek);
    if (decrypted === null) {
      Logger.error(TAG, `AES-GCM decrypt failed for machine: ${machineId}`);
      return null;
    }

    return BufferUtils.toUtf8String(decrypted);
  }
}

export { MachineEncryption };
