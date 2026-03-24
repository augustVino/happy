/**
 * Data Encryption Key (DEK) manager.
 *
 * Manages DEK lifecycle:
 * 1. Receives encrypted DEK from server (base64-encoded)
 * 2. Decrypts using content keypair (via EncryptionService)
 * 3. Caches DEK for subsequent message encryption/decryption
 *
 * Encrypted DEK wire format:
 *   version(1 byte, 0x00) + ephemeralPublicKey(32 bytes) + nonce(24 bytes) + ciphertext
 *   Ciphertext = box(plaintext_DEK_32_bytes) = 32 bytes + 16 bytes MAC
 *
 * Total encrypted DEK size: 1 + 32 + 24 + 48 = 105 bytes
 */
import { EncryptionService } from './EncryptionService';
import { SodiumCrypto } from 'common';
import { BufferUtils } from 'common';
import { Base64Utils } from 'common';
import { Logger } from 'common';

const TAG = 'DataKeyManager';

/** Expected sizes for DEK decryption */
const DEK_VERSION = 0x00;
const DEK_VERSION_SIZE = 1;
const EPHEMERAL_PUBLIC_KEY_SIZE = 32;
const BOX_NONCE_SIZE = 24;
const DEK_PLAINTEXT_SIZE = 32;

class DataKeyManager {
  private static instance: DataKeyManager | null = null;
  private dekCache: Map<string, Uint8Array> = new Map();

  private constructor() {}

  static getInstance(): DataKeyManager {
    if (DataKeyManager.instance === null) {
      DataKeyManager.instance = new DataKeyManager();
    }
    return DataKeyManager.instance;
  }

  /**
   * Decrypt a data encryption key from its encrypted form.
   *
   * @param encryptedKey Base64-encoded encrypted DEK
   * @param entityId Session ID or machine ID
   * @returns Decrypted DEK (32 bytes), or null on failure
   */
  decryptDataKey(encryptedKey: string, entityId: string): Uint8Array | null {
    // Check cache first
    const cached: Uint8Array | undefined = this.dekCache.get(entityId);
    if (cached !== undefined) {
      return cached;
    }

    const encryptionService = EncryptionService.getInstance();
    if (!encryptionService.isReady()) {
      Logger.error(TAG, 'Encryption service not initialized');
      return null;
    }

    // Decode base64
    let encryptedBytes: Uint8Array;
    try {
      encryptedBytes = Base64Utils.decode(encryptedKey);
    } catch (e) {
      Logger.error(TAG, `Failed to decode base64: ${e}`);
      return null;
    }

    // Validate minimum length: version(1) + ephemeralPubKey(32) + nonce(24) + mac(16) = 73
    const minLength = DEK_VERSION_SIZE + EPHEMERAL_PUBLIC_KEY_SIZE + BOX_NONCE_SIZE + 16;
    if (encryptedBytes.length < minLength) {
      Logger.error(TAG, `Encrypted DEK too short: ${encryptedBytes.length} < ${minLength}`);
      return null;
    }

    // Parse version byte
    const version: number = encryptedBytes[0];
    if (version !== DEK_VERSION) {
      Logger.error(TAG, `Unsupported DEK version: ${version}`);
      return null;
    }

    // Extract the box bundle (everything after version byte)
    const boxBundle = BufferUtils.slice(encryptedBytes, DEK_VERSION_SIZE);

    // Decrypt using boxDecrypt which expects: ephemeralPubKey(32) + nonce(24) + ciphertext
    const contentSecretKey = encryptionService.getContentSecretKey();
    const dek = SodiumCrypto.boxDecrypt(boxBundle, contentSecretKey);
    if (dek === null) {
      Logger.error(TAG, `Failed to decrypt DEK for entity: ${entityId}`);
      return null;
    }

    if (dek.length !== DEK_PLAINTEXT_SIZE) {
      Logger.error(TAG, `Decrypted DEK has unexpected size: ${dek.length}, expected ${DEK_PLAINTEXT_SIZE}`);
      return null;
    }

    // Cache the DEK
    this.dekCache.set(entityId, dek);
    Logger.info(TAG, `DEK decrypted and cached for entity: ${entityId}`);

    return dek;
  }

  /**
   * Get a cached DEK for an entity.
   *
   * @param entityId Session ID or machine ID
   * @returns Cached DEK, or null if not found
   */
  getDataKey(entityId: string): Uint8Array | null {
    const dek: Uint8Array | undefined = this.dekCache.get(entityId);
    if (dek === undefined) {
      return null;
    }
    return dek;
  }

  /**
   * Store a DEK directly (e.g., after decryption elsewhere).
   *
   * @param entityId Session ID or machine ID
   * @param dek The DEK to cache
   */
  putDataKey(entityId: string, dek: Uint8Array): void {
    this.dekCache.set(entityId, dek);
    Logger.info(TAG, `DEK cached for entity: ${entityId}`);
  }

  /**
   * Clear cached DEK for a specific entity.
   *
   * @param entityId Session ID or machine ID
   */
  clearCache(entityId: string): void {
    const dek: Uint8Array | undefined = this.dekCache.get(entityId);
    if (dek !== undefined) {
      BufferUtils.zeroOut(dek);
    }
    this.dekCache.delete(entityId);
    Logger.info(TAG, `DEK cache cleared for entity: ${entityId}`);
  }

  /**
   * Clear all cached DEKs. Should be called on logout.
   */
  clearAll(): void {
    this.dekCache.forEach((dek: Uint8Array, key: string) => {
      BufferUtils.zeroOut(dek);
    });
    this.dekCache.clear();
    Logger.info(TAG, 'All DEK cache cleared');
  }
}

export { DataKeyManager };
