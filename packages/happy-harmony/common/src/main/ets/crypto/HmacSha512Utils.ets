/**
 * HMAC-SHA512 implementation using @ohos.security.cryptoFramework.
 *
 * Output must be identical to the existing App/CLI implementations.
 * The App uses expo-crypto SHA-512 with manual HMAC construction.
 * The CLI uses Node.js crypto.createHmac('sha512', key).
 *
 * This implementation uses HarmonyOS CryptoFramework for the same result.
 */
import cryptoFramework from '@ohos.security.cryptoFramework';
import { Logger } from '../utils/Logger';
import { BufferUtils } from './BufferUtils';

const TAG = 'HmacSha512';

export class HmacSha512Utils {
  private constructor() {}

  /**
   * Compute HMAC-SHA512.
   * Produces a 64-byte (512-bit) output.
   *
   * Compatible with:
   * - App: expo-crypto SHA-512 with manual HMAC (ipad=0x36, opad=0x5c, blockSize=128)
   * - CLI: Node.js crypto.createHmac('sha512', key)
   *
   * @param key HMAC key
   * @param data Data to authenticate
   * @returns 64-byte HMAC-SHA512 result
   */
  static async hmacSha512(key: Uint8Array, data: Uint8Array): Promise<Uint8Array> {
    const blockSize = 128; // SHA-512 block size in bytes
    const opad = 0x5c;
    const ipad = 0x36;

    // Prepare key: if longer than block size, hash it first
    let actualKey: Uint8Array = key;
    if (key.length > blockSize) {
      actualKey = await HmacSha512Utils.sha512(key);
    }

    // Pad key to block size
    const paddedKey = new Uint8Array(blockSize);
    paddedKey.set(actualKey);

    // Create inner and outer padded keys
    const innerKey = new Uint8Array(blockSize);
    const outerKey = new Uint8Array(blockSize);

    for (let i = 0; i < blockSize; i++) {
      innerKey[i] = paddedKey[i] ^ ipad;
      outerKey[i] = paddedKey[i] ^ opad;
    }

    // Inner hash: SHA512(innerKey || data)
    const innerData = BufferUtils.concat(innerKey, data);
    const innerHash = await HmacSha512Utils.sha512(innerData);

    // Outer hash: SHA512(outerKey || innerHash)
    const outerData = BufferUtils.concat(outerKey, innerHash);
    const finalHash = await HmacSha512Utils.sha512(outerData);

    return finalHash;
  }

  /**
   * Compute SHA-512 hash.
   *
   * @param data Data to hash
   * @returns 64-byte SHA-512 hash
   */
  static async sha512(data: Uint8Array): Promise<Uint8Array> {
    try {
      const md: cryptoFramework.Md = cryptoFramework.createMd('SHA512');
      const dataBlob: cryptoFramework.DataBlob = { data: data };
      md.updateSync(dataBlob);
      const hashBlob: cryptoFramework.DataBlob = md.digestSync();
      return new Uint8Array(hashBlob.data);
    } catch (e) {
      Logger.error(TAG, `SHA-512 digest failed: ${e}`);
      throw new Error(`SHA-512 digest failed: ${e}`);
    }
  }
}
