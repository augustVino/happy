/**
 * AES-256-GCM encryption/decryption using @ohos.security.cryptoFramework.
 *
 * Wire format:
 *   nonce(12 bytes) + ciphertext + tag(16 bytes)
 *
 * This is the new format for message encryption (version 0x00).
 */
import cryptoFramework from '@ohos.security.cryptoFramework';
import { BufferUtils } from 'common';
import { Logger } from 'common';

const TAG = 'AesGcmCrypto';

const AES_KEY_SIZE = 32;
const GCM_NONCE_SIZE = 12;
const GCM_TAG_SIZE = 16;

class AesGcmCrypto {
  private constructor() {}

  /**
   * Encrypt plaintext using AES-256-GCM.
   *
   * @param plaintext Raw bytes to encrypt
   * @param key 32-byte AES key (DEK)
   * @returns Encrypted data: nonce(12) + ciphertext + tag(16), or null on failure
   */
  static async encrypt(plaintext: Uint8Array, key: Uint8Array): Promise<Uint8Array | null> {
    if (key.length !== AES_KEY_SIZE) {
      Logger.error(TAG, `Key must be ${AES_KEY_SIZE} bytes, got ${key.length}`);
      return null;
    }

    try {
      // Generate cryptographically secure random nonce
      const random = cryptoFramework.createRandom();
      const nonceBlob: cryptoFramework.DataBlob = random.generateRandomSync(GCM_NONCE_SIZE);
      const nonce = new Uint8Array(nonceBlob.data);

      // Create AES-256-GCM cipher
      const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('AES256|GCM|PKCS7|NoPadding');

      // Create symmetric key from raw data
      const keyBlob: cryptoFramework.DataBlob = { data: key };
      const symKeyGenerator: cryptoFramework.SymKeyGenerator =
        cryptoFramework.createSymKeyGenerator('AES256');
      const symKey: cryptoFramework.SymKey = await symKeyGenerator.convertKey(keyBlob);

      // Set GCM parameters
      const gcmParams: cryptoFramework.GcmParamsSpec = {
        algName: 'AES256|GCM|PKCS7|NoPadding',
        iv: { data: nonce },
        aad: { data: new Uint8Array(0) },
        authTag: { data: new Uint8Array(GCM_TAG_SIZE) },
      };
      cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, gcmParams);

      // Encrypt
      const plaintextBlob: cryptoFramework.DataBlob = { data: plaintext };
      const encryptResult: cryptoFramework.DataBlob = cipher.doFinalSync(plaintextBlob);

      // Combine: nonce + ciphertext_with_tag
      // doFinal output includes the tag appended to ciphertext
      const ciphertextWithTag = new Uint8Array(encryptResult.data);
      return BufferUtils.concat(nonce, ciphertextWithTag);
    } catch (e) {
      Logger.error(TAG, `AES-GCM encrypt failed: ${e}`);
      return null;
    }
  }

  /**
   * Decrypt ciphertext using AES-256-GCM.
   *
   * @param data Encrypted data: nonce(12) + ciphertext + tag(16)
   * @param key 32-byte AES key (DEK)
   * @returns Decrypted plaintext, or null on failure
   */
  static async decrypt(data: Uint8Array, key: Uint8Array): Promise<Uint8Array | null> {
    if (key.length !== AES_KEY_SIZE) {
      Logger.error(TAG, `Key must be ${AES_KEY_SIZE} bytes, got ${key.length}`);
      return null;
    }
    if (data.length < GCM_NONCE_SIZE + GCM_TAG_SIZE) {
      Logger.error(TAG, `Encrypted data too short: ${data.length}`);
      return null;
    }

    try {
      // Extract nonce
      const nonce = BufferUtils.slice(data, 0, GCM_NONCE_SIZE);

      // Extract ciphertext + tag
      const ciphertextWithTag = BufferUtils.slice(data, GCM_NONCE_SIZE);

      // Create AES-256-GCM cipher
      const cipher: cryptoFramework.Cipher = cryptoFramework.createCipher('AES256|GCM|PKCS7|NoPadding');

      // Create symmetric key from raw data
      const keyBlob: cryptoFramework.DataBlob = { data: key };
      const symKeyGenerator: cryptoFramework.SymKeyGenerator =
        cryptoFramework.createSymKeyGenerator('AES256');
      const symKey: cryptoFramework.SymKey = await symKeyGenerator.convertKey(keyBlob);

      // Set GCM parameters
      const gcmParams: cryptoFramework.GcmParamsSpec = {
        algName: 'AES256|GCM|PKCS7|NoPadding',
        iv: { data: nonce },
        aad: { data: new Uint8Array(0) },
        authTag: { data: new Uint8Array(GCM_TAG_SIZE) },
      };
      cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, gcmParams);

      // Decrypt
      const ciphertextBlob: cryptoFramework.DataBlob = { data: ciphertextWithTag };
      const decryptResult: cryptoFramework.DataBlob = cipher.doFinalSync(ciphertextBlob);
      return new Uint8Array(decryptResult.data);
    } catch (e) {
      Logger.error(TAG, `AES-GCM decrypt failed: ${e}`);
      return null;
    }
  }
}

export { AesGcmCrypto };
