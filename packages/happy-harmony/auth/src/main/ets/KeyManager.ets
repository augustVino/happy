/**
 * Key management wrapping SodiumCrypto.
 * Handles key generation, storage, and derivation.
 */
import { SodiumCrypto } from 'common';
import { SodiumFFI } from 'common';
import { BufferUtils } from 'common';
import { Base64Utils } from 'common';
import { QRAuthKeyPair } from 'common';
import { AuthChallengeResult } from 'common';
import { Logger } from 'common';

const TAG = 'KeyManager';

/** Result of account creation. */
export class CreateAccountResult {
  secret: Uint8Array = new Uint8Array(0);
  secretBase64Url: string = '';
  challenge: AuthChallengeResult | null = null;

  constructor(secret: Uint8Array, secretBase64Url: string, challenge: AuthChallengeResult) {
    this.secret = secret;
    this.secretBase64Url = secretBase64Url;
    this.challenge = challenge;
  }
}

class KeyManager {
  private static instance: KeyManager | null = null;

  private constructor() {}

  static getInstance(): KeyManager {
    if (KeyManager.instance === null) {
      KeyManager.instance = new KeyManager();
    }
    return KeyManager.instance;
  }

  /**
   * Generate a new random secret key (32 bytes).
   */
  generateSecret(): Uint8Array {
    return SodiumCrypto.randomBytes(32);
  }

  /**
   * Generate auth challenge for the given secret.
   */
  generateAuthChallenge(secret: Uint8Array): AuthChallengeResult {
    return SodiumCrypto.authChallenge(secret);
  }

  /**
   * Generate a temporary X25519 keypair for QR auth.
   */
  generateQRAuthKeyPair(): QRAuthKeyPair {
    const seed: Uint8Array = SodiumCrypto.randomBytes(32);
    const keypair = SodiumCrypto.boxPublicKeyFromSeed(seed);
    // We need the full keypair for decryption, so use boxSeedKeypair
    const fullKeypair = SodiumFFI.cryptoBoxSeedKeypair(seed);
    return new QRAuthKeyPair(fullKeypair.publicKey, fullKeypair.secretKey);
  }

  /**
   * Decrypt QR auth response using the temporary keypair.
   */
  decryptQRResponse(encryptedResponse: Uint8Array, secretKey: Uint8Array): Uint8Array | null {
    const decrypted: Uint8Array | null = SodiumCrypto.boxDecrypt(encryptedResponse, secretKey);
    if (decrypted === null) {
      Logger.error(TAG, 'Failed to decrypt QR auth response');
      return null;
    }
    return decrypted;
  }

  /**
   * Create a new account: generate secret + challenge.
   */
  createAccount(): CreateAccountResult {
    const secret: Uint8Array = this.generateSecret();
    const challenge: AuthChallengeResult = this.generateAuthChallenge(secret);
    const secretBase64Url: string = Base64Utils.encodeBase64Url(secret);
    return new CreateAccountResult(secret, secretBase64Url, challenge);
  }

  /**
   * Encode secret to backup string (Base32, 5-char groups).
   */
  encodeSecretForBackup(secret: Uint8Array): string {
    const base32: string = this.uint8ArrayToBase32(secret);
    return this.formatBase32Groups(base32);
  }

  /**
   * Decode backup string to secret bytes.
   */
  decodeSecretFromBackup(backupString: string): Uint8Array | null {
    try {
      const clean: string = backupString.replace(/-/g, '').toUpperCase();
      return this.base32ToUint8Array(clean);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Failed to decode backup key: ${errMsg}`);
      return null;
    }
  }

  // --- Base32 encoding/decoding ---

  private static readonly BASE32_ALPHABET: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  private uint8ArrayToBase32(bytes: Uint8Array): string {
    let bits: string = '';
    for (let i: number = 0; i < bytes.length; i++) {
      const byte: number = bytes[i];
      const binary: string = byte.toString(2).padStart(8, '0');
      bits = bits + binary;
    }
    // Pad to multiple of 5
    while (bits.length % 5 !== 0) {
      bits = bits + '0';
    }
    let result: string = '';
    for (let i: number = 0; i < bits.length; i = i + 5) {
      const chunk: string = bits.substring(i, i + 5);
      const index: number = parseInt(chunk, 2);
      result = result + KeyManager.BASE32_ALPHABET.charAt(index);
    }
    return result;
  }

  private base32ToUint8Array(base32: string): Uint8Array {
    let bits: string = '';
    for (let i: number = 0; i < base32.length; i++) {
      const char: string = base32.charAt(i);
      const index: number = KeyManager.BASE32_ALPHABET.indexOf(char);
      if (index === -1) {
        throw new Error(`Invalid Base32 character: ${char}`);
      }
      const binary: string = index.toString(2).padStart(5, '0');
      bits = bits + binary;
    }
    // Pad to multiple of 8
    while (bits.length % 8 !== 0) {
      bits = bits + '0';
    }
    const bytes: Uint8Array = new Uint8Array(Math.floor(bits.length / 8));
    for (let i: number = 0; i < bytes.length; i++) {
      bytes[i] = parseInt(bits.substring(i * 8, i * 8 + 8), 2);
    }
    return bytes;
  }

  private formatBase32Groups(base32: string): string {
    let result: string = '';
    for (let i: number = 0; i < base32.length; i = i + 5) {
      if (i > 0) {
        result = result + '-';
      }
      const end: number = Math.min(i + 5, base32.length);
      result = result + base32.substring(i, end);
    }
    return result;
  }
}

export { KeyManager };
