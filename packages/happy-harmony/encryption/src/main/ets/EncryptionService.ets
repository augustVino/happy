/**
 * Unified encryption service entry point.
 *
 * Manages the content keypair derived from the master secret.
 * The content keypair (X25519) is used for DEK (Data Encryption Key)
 * decryption via NaCl Box.
 *
 * Master Secret -> deriveKey('Happy EnCoder', ['content']) -> contentSeed
 *   -> cryptoBoxSeedKeypair(contentSeed) -> X25519 contentKeyPair
 */
import { SecureStore } from './SecureStore';
import { KeyDerivation } from 'common';
import { SodiumCrypto } from 'common';
import { SodiumFFI } from 'common';
import { BufferUtils } from 'common';
import { Logger } from 'common';

const TAG = 'EncryptionService';

class EncryptionService {
  private static instance: EncryptionService | null = null;
  private isInitialized: boolean = false;
  private contentPublicKey: Uint8Array = new Uint8Array(0);
  private contentSecretKey: Uint8Array = new Uint8Array(0);
  private masterSecret: Uint8Array = new Uint8Array(0);

  private constructor() {}

  static getInstance(): EncryptionService {
    if (EncryptionService.instance === null) {
      EncryptionService.instance = new EncryptionService();
    }
    return EncryptionService.instance;
  }

  /**
   * Initialize the encryption service.
   * Reads master secret from SecureStore, derives content keypair.
   *
   * @returns true if initialization succeeded
   */
  async initialize(): Promise<boolean> {
    if (this.isInitialized) {
      Logger.info(TAG, 'Already initialized');
      return true;
    }

    try {
      // Ensure libsodium is initialized
      SodiumCrypto.init();

      // Get master secret from SecureStore
      const secureStore = await SecureStore.getInstance();
      const credentials = await secureStore.getCredentials();
      if (credentials === null) {
        Logger.error(TAG, 'No credentials found in SecureStore');
        return false;
      }

      const secretHex: string = credentials.secret;
      if (secretHex.length === 0) {
        Logger.error(TAG, 'Master secret is empty');
        return false;
      }

      this.masterSecret = BufferUtils.fromHex(secretHex);
      if (this.masterSecret.length !== 32) {
        Logger.error(TAG, `Master secret must be 32 bytes, got ${this.masterSecret.length}`);
        return false;
      }

      // Derive content seed: deriveKey(masterSecret, 'Happy EnCoder', ['content'])
      const contentSeed: Uint8Array = await KeyDerivation.deriveKey(
        this.masterSecret,
        'Happy EnCoder',
        ['content']
      );

      // Derive X25519 keypair from content seed
      const keypair = SodiumFFI.cryptoBoxSeedKeypair(contentSeed);
      this.contentPublicKey = keypair.publicKey;
      this.contentSecretKey = keypair.secretKey;

      this.isInitialized = true;
      Logger.info(TAG, 'Encryption service initialized successfully');
      return true;
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Initialization failed: ${errMsg}`);
      return false;
    }
  }

  /**
   * Get the content public key (X25519).
   * Used by the server to encrypt DEK for this client.
   */
  getContentPublicKey(): Uint8Array {
    return this.contentPublicKey;
  }

  /**
   * Get the content secret key (X25519).
   * Used to decrypt DEK received from the server.
   */
  getContentSecretKey(): Uint8Array {
    return this.contentSecretKey;
  }

  /**
   * Get the master secret (32 bytes).
   * Used for legacy SecretBox decryption.
   */
  getMasterSecret(): Uint8Array {
    return this.masterSecret;
  }

  /**
   * Check if the encryption service is ready for use.
   */
  isReady(): boolean {
    return this.isInitialized;
  }

  /**
   * Reset the service state. Used for logout / re-initialization.
   */
  reset(): void {
    this.isInitialized = false;
    BufferUtils.zeroOut(this.contentPublicKey);
    BufferUtils.zeroOut(this.contentSecretKey);
    BufferUtils.zeroOut(this.masterSecret);
    this.contentPublicKey = new Uint8Array(0);
    this.contentSecretKey = new Uint8Array(0);
    this.masterSecret = new Uint8Array(0);
    Logger.info(TAG, 'Encryption service reset');
  }
}

export { EncryptionService };
