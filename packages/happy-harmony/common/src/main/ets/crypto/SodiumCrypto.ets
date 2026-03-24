/**
 * High-level cryptographic API compatible with existing App/CLI implementations.
 *
 * Wire formats:
 * - SecretBox: nonce(24) + ciphertext
 * - Box: ephemeralPublicKey(32) + nonce(24) + ciphertext
 *
 * Uses libsodium N-API bindings via SodiumFFI.
 */
import { SodiumFFI, SodiumKeypair } from './SodiumFFI';
import { BufferUtils } from './BufferUtils';
import { Logger } from '../utils/Logger';

const TAG = 'SodiumCrypto';

export class SodiumCrypto {
  private constructor() {}

  /**
   * Initialize libsodium. Must be called before any other crypto operations.
   */
  static init(): void {
    if (!SodiumFFI.isInitialized()) {
      const result = SodiumFFI.sodiumInit();
      if (result !== 0) {
        Logger.error(TAG, `Failed to initialize libsodium: ${result}`);
        throw new Error(`Failed to initialize libsodium: ${result}`);
      }
    }
  }

  // --- Random ---

  /**
   * Generate random bytes.
   */
  static randomBytes(length: number): Uint8Array {
    SodiumCrypto.ensureInitialized();
    return SodiumFFI.randomBytesBufNew(length);
  }

  // --- Ed25519 ---

  /**
   * Generate Ed25519 keypair from a 32-byte seed.
   * Compatible with libsodium crypto_sign_seed_keypair.
   */
  static ed25519SeedKeypair(seed: Uint8Array): SodiumKeypair {
    SodiumCrypto.ensureInitialized();
    if (seed.length !== SodiumFFI.cryptoSignSeedBytes) {
      throw new Error(`Seed must be ${SodiumFFI.cryptoSignSeedBytes} bytes, got ${seed.length}`);
    }
    return SodiumFFI.cryptoSignSeedKeypair(seed);
  }

  /**
   * Sign a message with Ed25519 secret key.
   * Returns detached signature (64 bytes).
   */
  static ed25519Sign(message: Uint8Array, secretKey: Uint8Array): Uint8Array {
    SodiumCrypto.ensureInitialized();
    if (secretKey.length !== SodiumFFI.cryptoSignSecretKeyBytes) {
      throw new Error(`Secret key must be ${SodiumFFI.cryptoSignSecretKeyBytes} bytes, got ${secretKey.length}`);
    }
    return SodiumFFI.cryptoSignDetached(message, secretKey);
  }

  /**
   * Verify an Ed25519 detached signature.
   */
  static ed25519Verify(signature: Uint8Array, message: Uint8Array, publicKey: Uint8Array): boolean {
    SodiumCrypto.ensureInitialized();
    if (signature.length !== SodiumFFI.cryptoSignBytes) {
      throw new Error(`Signature must be ${SodiumFFI.cryptoSignBytes} bytes, got ${signature.length}`);
    }
    if (publicKey.length !== SodiumFFI.cryptoSignPublicKeyBytes) {
      throw new Error(`Public key must be ${SodiumFFI.cryptoSignPublicKeyBytes} bytes, got ${publicKey.length}`);
    }
    return SodiumFFI.cryptoSignVerifyDetached(signature, message, publicKey);
  }

  // --- Auth Challenge ---

  /**
   * Generate an auth challenge response.
   * Compatible with existing App/CLI authChallenge function.
   *
   * Returns: { challenge: Uint8Array(32), signature: Uint8Array(64), publicKey: Uint8Array(32) }
   */
  static authChallenge(secret: Uint8Array): AuthChallengeResult {
    SodiumCrypto.ensureInitialized();
    const keypair = SodiumFFI.cryptoSignSeedKeypair(secret);
    const challenge = SodiumFFI.randomBytesBufNew(32);
    const signature = SodiumFFI.cryptoSignDetached(challenge, keypair.secretKey);
    return {
      challenge: challenge,
      signature: signature,
      publicKey: keypair.publicKey,
    };
  }

  // --- NaCl Box (public key encryption) ---

  /**
   * Generate a new ephemeral X25519 keypair.
   */
  static boxKeypair(): SodiumKeypair {
    SodiumCrypto.ensureInitialized();
    return SodiumFFI.cryptoBoxKeypair();
  }

  /**
   * Get the X25519 public key for a given seed.
   * Compatible with existing App getPublicKeyForBox function.
   */
  static boxPublicKeyFromSeed(seed: Uint8Array): Uint8Array {
    SodiumCrypto.ensureInitialized();
    const keypair = SodiumFFI.cryptoBoxSeedKeypair(seed);
    return keypair.publicKey;
  }

  /**
   * Encrypt data using NaCl Box (X25519 + XSalsa20-Poly1305).
   * Compatible with existing App/CLI encryptBox function.
   *
   * Bundle format: ephemeralPublicKey(32) + nonce(24) + ciphertext
   */
  static boxEncrypt(data: Uint8Array, recipientPublicKey: Uint8Array): Uint8Array {
    SodiumCrypto.ensureInitialized();
    const ephemeralKeyPair = SodiumFFI.cryptoBoxKeypair();
    const nonce = SodiumFFI.randomBytesBufNew(SodiumFFI.cryptoBoxNonceBytes);
    const encrypted = SodiumFFI.cryptoBoxEasy(data, nonce, recipientPublicKey, ephemeralKeyPair.secretKey);

    // Bundle format: ephemeral public key (32 bytes) + nonce (24 bytes) + encrypted data
    return BufferUtils.concat(ephemeralKeyPair.publicKey, nonce, encrypted);
  }

  /**
   * Decrypt data using NaCl Box.
   * Compatible with existing App/CLI decryptBox function.
   *
   * Expects bundle format: ephemeralPublicKey(32) + nonce(24) + ciphertext
   */
  static boxDecrypt(encryptedBundle: Uint8Array, recipientSecretKey: Uint8Array): Uint8Array | null {
    SodiumCrypto.ensureInitialized();
    if (encryptedBundle.length < SodiumFFI.cryptoBoxPublicKeyBytes + SodiumFFI.cryptoBoxNonceBytes +
      SodiumFFI.cryptoBoxMacBytes) {
      Logger.error(TAG, 'Encrypted bundle too short for box decryption');
      return null;
    }

    const ephemeralPublicKey = BufferUtils.slice(
      encryptedBundle,
      0,
      SodiumFFI.cryptoBoxPublicKeyBytes
    );
    const nonce = BufferUtils.slice(
      encryptedBundle,
      SodiumFFI.cryptoBoxPublicKeyBytes,
      SodiumFFI.cryptoBoxPublicKeyBytes + SodiumFFI.cryptoBoxNonceBytes
    );
    const ciphertext = BufferUtils.slice(
      encryptedBundle,
      SodiumFFI.cryptoBoxPublicKeyBytes + SodiumFFI.cryptoBoxNonceBytes
    );

    return SodiumFFI.cryptoBoxOpenEasy(ciphertext, nonce, ephemeralPublicKey, recipientSecretKey);
  }

  // --- NaCl SecretBox (symmetric encryption) ---

  /**
   * Encrypt data using NaCl SecretBox (XSalsa20-Poly1305).
   * Compatible with existing App/CLI encryptSecretBox function.
   *
   * Data is JSON-serialized before encryption.
   * Bundle format: nonce(24) + ciphertext
   */
  static secretBoxEncrypt(data: ESObject, secret: Uint8Array): Uint8Array {
    SodiumCrypto.ensureInitialized();
    const nonce = SodiumFFI.randomBytesBufNew(SodiumFFI.cryptoSecretboxNonceBytes);
    const plaintext = BufferUtils.fromUtf8String(JSON.stringify(data));
    const encrypted = SodiumFFI.cryptoSecretboxEasy(plaintext, nonce, secret);

    // Bundle format: nonce(24 bytes) + encrypted data
    return BufferUtils.concat(nonce, encrypted);
  }

  /**
   * Decrypt data using NaCl SecretBox.
   * Compatible with existing App/CLI decryptSecretBox function.
   *
   * Expects bundle format: nonce(24) + ciphertext
   * Returns parsed JSON object, or null on failure.
   */
  static secretBoxDecrypt(data: Uint8Array, secret: Uint8Array): ESObject | null {
    SodiumCrypto.ensureInitialized();
    if (data.length < SodiumFFI.cryptoSecretboxNonceBytes + SodiumFFI.cryptoSecretboxMacBytes) {
      Logger.error(TAG, 'Encrypted data too short for secretbox decryption');
      return null;
    }

    const nonce = BufferUtils.slice(data, 0, SodiumFFI.cryptoSecretboxNonceBytes);
    const ciphertext = BufferUtils.slice(data, SodiumFFI.cryptoSecretboxNonceBytes);

    const decrypted = SodiumFFI.cryptoSecretboxOpenEasy(ciphertext, nonce, secret);
    if (decrypted === null) {
      Logger.error(TAG, 'SecretBox decryption failed');
      return null;
    }

    const jsonString = BufferUtils.toUtf8String(decrypted);
    try {
      return JSON.parse(jsonString);
    } catch (e) {
      Logger.error(TAG, `Failed to parse decrypted JSON: ${e}`);
      return null;
    }
  }

  /**
   * Raw SecretBox encrypt (takes Uint8Array, returns nonce+ciphertext).
   * For use when plaintext is already bytes (not JSON).
   */
  static secretBoxEncryptRaw(plaintext: Uint8Array, secret: Uint8Array): Uint8Array {
    SodiumCrypto.ensureInitialized();
    const nonce = SodiumFFI.randomBytesBufNew(SodiumFFI.cryptoSecretboxNonceBytes);
    const encrypted = SodiumFFI.cryptoSecretboxEasy(plaintext, nonce, secret);
    return BufferUtils.concat(nonce, encrypted);
  }

  /**
   * Raw SecretBox decrypt (returns Uint8Array or null).
   */
  static secretBoxDecryptRaw(data: Uint8Array, secret: Uint8Array): Uint8Array | null {
    SodiumCrypto.ensureInitialized();
    if (data.length < SodiumFFI.cryptoSecretboxNonceBytes + SodiumFFI.cryptoSecretboxMacBytes) {
      return null;
    }

    const nonce = BufferUtils.slice(data, 0, SodiumFFI.cryptoSecretboxNonceBytes);
    const ciphertext = BufferUtils.slice(data, SodiumFFI.cryptoSecretboxNonceBytes);
    return SodiumFFI.cryptoSecretboxOpenEasy(ciphertext, nonce, secret);
  }

  // --- Internal ---

  private static ensureInitialized(): void {
    if (!SodiumFFI.isInitialized()) {
      SodiumCrypto.init();
    }
  }
}

export interface AuthChallengeResult {
  challenge: Uint8Array;
  signature: Uint8Array;
  publicKey: Uint8Array;
}
