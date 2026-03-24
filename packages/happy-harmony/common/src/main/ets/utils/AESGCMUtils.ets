/**
 * AES-256-GCM encryption/decryption utility.
 * Uses @ohos.security.cryptoFramework for platform-native crypto.
 *
 * Wire format:
 *   encrypt: version(1 byte, 0x00) + nonce(12) + ciphertext + tag(16)
 *   decrypt: parses the above format
 */
import cryptoFramework from '@ohos.security.cryptoFramework';
import { BufferUtils } from '../crypto/BufferUtils';
import { Logger } from './Logger';

const TAG = 'AESGCMUtils';
const AES_KEY_SIZE: number = 32;
const GCM_NONCE_SIZE: number = 12;
const GCM_TAG_SIZE: number = 16;
const VERSION_BYTE: number = 0x00;
const AES_GCM_ALGO_NAME: string = 'AES256';
const AES_GCM_ALGO_PARAM: string = 'GcmParam';

export class AESGCMUtils {
  private constructor() {}

  /**
   * Encrypt plaintext using AES-256-GCM.
   * Returns: version(1) + nonce(12) + ciphertext + tag(16)
   */
  static encrypt(key: Uint8Array, plaintext: Uint8Array): Uint8Array {
    AESGCMUtils.validateKey(key);

    const symKey: cryptoFramework.SymKey = AESGCMUtils.createSymKey(key);
    const nonce: Uint8Array = AESGCMUtils.generateNonce();

    const gcmParam: cryptoFramework.GcmParamsSpec = {
      algName: AES_GCM_ALGO_NAME + '|' + AES_GCM_ALGO_PARAM,
      iv: { data: nonce },
      aad: { data: new Uint8Array(0) },
      authTag: { data: new Uint8Array(GCM_TAG_SIZE) },
    };

    const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher(AES_GCM_ALGO_NAME + '|' + AES_GCM_ALGO_PARAM);
    cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, gcmParam);

    const encryptData: cryptoFramework.DataBlob = { data: plaintext };
    const encrypted: cryptoFramework.DataBlob = cipher.doFinalSync(encryptData);

    // Build wire format: version(1) + nonce(12) + ciphertext+tag
    return BufferUtils.concat(
      new Uint8Array([VERSION_BYTE]),
      nonce,
      new Uint8Array(encrypted.data)
    );
  }

  /**
   * Decrypt data encrypted with AES-256-GCM.
   * Expects: version(1) + nonce(12) + ciphertext + tag(16)
   * Returns plaintext Uint8Array, or null on failure.
   */
  static decrypt(key: Uint8Array, data: Uint8Array): Uint8Array | null {
    AESGCMUtils.validateKey(key);

    const minSize: number = 1 + GCM_NONCE_SIZE + GCM_TAG_SIZE;
    if (data.length < minSize) {
      Logger.error(TAG, `Encrypted data too short: ${data.length}, minimum: ${minSize}`);
      return null;
    }

    const version: number = data[0];
    if (version !== VERSION_BYTE) {
      Logger.error(TAG, `Unsupported encryption version: ${version}`);
      return null;
    }

    const nonce: Uint8Array = BufferUtils.slice(data, 1, 1 + GCM_NONCE_SIZE);
    const ciphertextWithTag: Uint8Array = BufferUtils.slice(data, 1 + GCM_NONCE_SIZE);

    const symKey: cryptoFramework.SymKey = AESGCMUtils.createSymKey(key);

    const gcmParam: cryptoFramework.GcmParamsSpec = {
      algName: AES_GCM_ALGO_NAME + '|' + AES_GCM_ALGO_PARAM,
      iv: { data: nonce },
      aad: { data: new Uint8Array(0) },
      authTag: { data: new Uint8Array(GCM_TAG_SIZE) },
    };

    try {
      const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher(AES_GCM_ALGO_NAME + '|' + AES_GCM_ALGO_PARAM);
      cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, gcmParam);

      const decryptData: cryptoFramework.DataBlob = { data: ciphertextWithTag };
      const decrypted: cryptoFramework.DataBlob = cipher.doFinalSync(decryptData);
      return new Uint8Array(decrypted.data);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Decryption failed: ${errMsg}`);
      return null;
    }
  }

  /**
   * Generate a random 32-byte AES-256 key.
   */
  static generateKey(): Uint8Array {
    const random: cryptoFramework.Random = cryptoFramework.createRandom();
    const randomData: cryptoFramework.DataBlob = random.generateRandomSync(AES_KEY_SIZE);
    return new Uint8Array(randomData.data);
  }

  /**
   * Generate a random 12-byte GCM nonce.
   */
  private static generateNonce(): Uint8Array {
    const random: cryptoFramework.Random = cryptoFramework.createRandom();
    const randomData: cryptoFramework.DataBlob = random.generateRandomSync(GCM_NONCE_SIZE);
    return new Uint8Array(randomData.data);
  }

  /**
   * Create a symmetric key from raw bytes.
   */
  private static createSymKey(keyData: Uint8Array): cryptoFramework.SymKey {
    const symKeyGenerator: cryptoFramework.SymKeyGenerator =
      cryptoFramework.createSymKeyGenerator(AES_GCM_ALGO_NAME);
    const keyBlob: cryptoFramework.DataBlob = { data: keyData };
    return symKeyGenerator.convertKeySync(keyBlob);
  }

  /**
   * Validate that the key is exactly 32 bytes.
   */
  private static validateKey(key: Uint8Array): void {
    if (key.length !== AES_KEY_SIZE) {
      throw new Error(`AES-256 key must be ${AES_KEY_SIZE} bytes, got ${key.length}`);
    }
  }
}
