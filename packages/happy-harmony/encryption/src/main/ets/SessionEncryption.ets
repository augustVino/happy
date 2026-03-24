/**
 * Session-level encryption and decryption.
 *
 * Handles message encryption/decryption for a specific session using
 * the session's DEK (Data Encryption Key).
 *
 * Supports two wire formats:
 * - New (AES-256-GCM): version(1 byte, 0x00) + nonce(12) + ciphertext + tag(16)
 * - Legacy (NaCl SecretBox): nonce(24) + ciphertext (uses master secret)
 *
 * Message content format (after decryption):
 * {
 *   "id": "cuid2",
 *   "time": 1700000000000,
 *   "role": "user" | "agent",
 *   "ev": { ... }
 * }
 */
import { DataKeyManager } from './DataKeyManager';
import { EncryptionService } from './EncryptionService';
import { AesGcmCrypto } from './AesGcmCrypto';
import { SodiumCrypto } from 'common';
import { BufferUtils } from 'common';
import { Base64Utils } from 'common';
import { Logger } from 'common';

const TAG = 'SessionEncryption';

/** Message format version byte for AES-256-GCM */
const MSG_VERSION_AES_GCM = 0x00;
const MSG_VERSION_SIZE = 1;

class SessionEncryption {
  private static instance: SessionEncryption | null = null;
  private dataKeyManager: DataKeyManager;

  private constructor() {
    this.dataKeyManager = DataKeyManager.getInstance();
  }

  static getInstance(): SessionEncryption {
    if (SessionEncryption.instance === null) {
      SessionEncryption.instance = new SessionEncryption();
    }
    return SessionEncryption.instance;
  }

  /**
   * Encrypt a plaintext message for a session.
   * Uses AES-256-GCM with the session's DEK.
   *
   * @param sessionId Session identifier
   * @param plaintext JSON string to encrypt
   * @returns Base64-encoded encrypted message, or null on failure
   */
  async encrypt(sessionId: string, plaintext: string): Promise<string | null> {
    const dek = this.dataKeyManager.getDataKey(sessionId);
    if (dek === null) {
      Logger.error(TAG, `No DEK found for session: ${sessionId}`);
      return null;
    }

    const plaintextBytes = BufferUtils.fromUtf8String(plaintext);
    const encrypted = await AesGcmCrypto.encrypt(plaintextBytes, dek);
    if (encrypted === null) {
      Logger.error(TAG, `AES-GCM encrypt failed for session: ${sessionId}`);
      return null;
    }

    // Prepend version byte
    const versioned = new Uint8Array(MSG_VERSION_SIZE + encrypted.length);
    versioned[0] = MSG_VERSION_AES_GCM;
    versioned.set(encrypted, MSG_VERSION_SIZE);

    return Base64Utils.encode(versioned);
  }

  /**
   * Decrypt a message for a session.
   * Automatically detects the version and uses the appropriate algorithm.
   *
   * @param sessionId Session identifier
   * @param ciphertext Base64-encoded encrypted message
   * @returns Decrypted JSON string, or null on failure
   */
  async decrypt(sessionId: string, ciphertext: string): Promise<string | null> {
    let encryptedBytes: Uint8Array;
    try {
      encryptedBytes = Base64Utils.decode(ciphertext);
    } catch (e) {
      Logger.error(TAG, `Failed to decode base64 ciphertext: ${e}`);
      return null;
    }

    if (encryptedBytes.length === 0) {
      Logger.error(TAG, 'Empty ciphertext');
      return null;
    }

    // Check version byte
    const version: number = encryptedBytes[0];
    if (version === MSG_VERSION_AES_GCM) {
      return this.decryptAesGcm(sessionId, encryptedBytes);
    }

    // Legacy format: no version byte, starts with nonce (24 bytes) for SecretBox
    return this.decryptLegacySecretBox(encryptedBytes);
  }

  /**
   * Encrypt RPC params for a session.
   * Format: JSON.stringify(params) -> AES-GCM encrypt -> base64
   *
   * @param sessionId Session identifier
   * @param params Object to encrypt
   * @returns Base64-encoded encrypted params, or null on failure
   */
  async encryptRpcParams(sessionId: string, params: ESObject): Promise<string | null> {
    const jsonString: string = JSON.stringify(params);
    return this.encrypt(sessionId, jsonString);
  }

  /**
   * Decrypt RPC result for a session.
   *
   * @param sessionId Session identifier
   * @param encryptedResult Base64-encoded encrypted result
   * @returns Decrypted JSON string, or null on failure
   */
  async decryptRpcResult(sessionId: string, encryptedResult: string): Promise<string | null> {
    return this.decrypt(sessionId, encryptedResult);
  }

  /**
   * Decrypt using AES-256-GCM (new format).
   * Input: version(1) + nonce(12) + ciphertext + tag(16)
   */
  private async decryptAesGcm(sessionId: string, data: Uint8Array): Promise<string | null> {
    const dek = this.dataKeyManager.getDataKey(sessionId);
    if (dek === null) {
      Logger.error(TAG, `No DEK found for session: ${sessionId}`);
      return null;
    }

    // Strip version byte
    const encryptedPayload = BufferUtils.slice(data, MSG_VERSION_SIZE);
    const decrypted = await AesGcmCrypto.decrypt(encryptedPayload, dek);
    if (decrypted === null) {
      Logger.error(TAG, `AES-GCM decrypt failed for session: ${sessionId}`);
      return null;
    }

    return BufferUtils.toUtf8String(decrypted);
  }

  /**
   * Decrypt using NaCl SecretBox (legacy format).
   * Input: nonce(24) + ciphertext
   * Uses master secret from EncryptionService.
   */
  private decryptLegacySecretBox(data: Uint8Array): string | null {
    const encryptionService = EncryptionService.getInstance();
    if (!encryptionService.isReady()) {
      Logger.error(TAG, 'Encryption service not initialized for legacy decrypt');
      return null;
    }

    const masterSecret = encryptionService.getMasterSecret();
    if (masterSecret.length === 0) {
      Logger.error(TAG, 'Master secret not available for legacy decrypt');
      return null;
    }

    const result = SodiumCrypto.secretBoxDecryptRaw(data, masterSecret);
    if (result === null) {
      Logger.error(TAG, 'Legacy SecretBox decrypt failed');
      return null;
    }

    return BufferUtils.toUtf8String(result);
  }
}

export { SessionEncryption };
