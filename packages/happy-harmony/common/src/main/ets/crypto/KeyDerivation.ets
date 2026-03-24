/**
 * Key derivation compatible with existing App/CLI implementations.
 *
 * Uses HMAC-SHA512 tree-based derivation matching:
 * - App: packages/happy-app/sources/encryption/deriveKey.ts
 * - CLI: packages/happy-cli/src/utils/deriveKey.ts
 *
 * Root step: HMAC-SHA512(usage + ' Master Seed', masterSecret)
 * Child step: HMAC-SHA512(chainCode, 0x00 + TextEncoder(index))
 */
import { HmacSha512Utils } from './HmacSha512Utils';
import { BufferUtils } from './BufferUtils';
import { Logger } from '../utils/Logger';

const TAG = 'KeyDerivation';

/**
 * State of a key derivation tree node.
 */
export interface KeyTreeState {
  key: Uint8Array;
  chainCode: Uint8Array;
}

export class KeyDerivation {
  private constructor() {}

  /**
   * Derive the root of the key tree.
   * HMAC-SHA512(usage + ' Master Seed', seed) -> key(32) + chainCode(32)
   *
   * @param seed Master secret (32 bytes)
   * @param usage Usage string, e.g., 'Happy EnCoder', 'Happy Coder'
   * @returns Key tree root state with key and chainCode
   */
  static async deriveTreeRoot(seed: Uint8Array, usage: string): Promise<KeyTreeState> {
    const usageBytes = BufferUtils.fromUtf8String(usage + ' Master Seed');
    const hash = await HmacSha512Utils.hmacSha512(usageBytes, seed);
    return {
      key: BufferUtils.slice(hash, 0, 32),
      chainCode: BufferUtils.slice(hash, 32),
    };
  }

  /**
   * Derive a child key from a parent chain code.
   * HMAC-SHA512(chainCode, 0x00 + TextEncoder(index))
   *
   * @param chainCode Parent chain code (32 bytes)
   * @param index Path element string
   * @returns Child key tree state
   */
  static async deriveTreeChild(chainCode: Uint8Array, index: string): Promise<KeyTreeState> {
    // Prepare data: 0x00 + TextEncoder(index)
    const indexBytes = BufferUtils.fromUtf8String(index);
    const data = new Uint8Array(1 + indexBytes.length);
    data[0] = 0x00;
    data.set(indexBytes, 1);

    const hash = await HmacSha512Utils.hmacSha512(chainCode, data);
    return {
      key: BufferUtils.slice(hash, 0, 32),
      chainCode: BufferUtils.slice(hash, 32),
    };
  }

  /**
   * Derive a key from the master secret using a usage string and path.
   * Compatible with existing App/CLI deriveKey function.
   *
   * Example:
   *   // Derive content encryption key
   *   deriveKey(masterSecret, 'Happy EnCoder', ['content'])
   *
   *   // Derive analytics ID
   *   deriveKey(masterSecret, 'Happy Coder', ['analytics', 'id'])
   *
   * @param master Master secret (32 bytes)
   * @param usage Usage context string
   * @param path Derivation path elements
   * @returns Derived key (32 bytes)
   */
  static async deriveKey(master: Uint8Array, usage: string, path: string[]): Promise<Uint8Array> {
    let state = await KeyDerivation.deriveTreeRoot(master, usage);

    for (let i = 0; i < path.length; i++) {
      state = await KeyDerivation.deriveTreeChild(state.chainCode, path[i]);
    }

    return state.key;
  }
}
