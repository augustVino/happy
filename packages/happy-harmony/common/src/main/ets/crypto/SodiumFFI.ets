import { Logger } from '../utils/Logger';

const TAG = 'SodiumFFI';

// Keypair type returned by seed-based keypair generation
export class SodiumKeypair {
  publicKey: Uint8Array;
  secretKey: Uint8Array;

  constructor(publicKey: Uint8Array, secretKey: Uint8Array) {
    this.publicKey = publicKey;
    this.secretKey = secretKey;
  }
}

export class SodiumFFI {
  private static initialized: boolean = false;
  private static nativeModuleRef: ESObject | null = null;

  private constructor() {}

  /**
   * Inject native module reference. Must be called from the entry module
   * which can import 'libsodium_wrapper.so' directly.
   */
  static setNativeModule(mod: ESObject): void {
    SodiumFFI.nativeModuleRef = mod;
    Logger.info(TAG, 'Native module injected');
  }

  private static getNativeModule(): ESObject {
    if (SodiumFFI.nativeModuleRef === null || SodiumFFI.nativeModuleRef === undefined) {
      throw new Error(
        'Native module not available. Ensure SodiumFFI.setNativeModule() was called with a valid native module. ' +
        'Note: N-API native libraries are NOT supported in DevEco Studio Previewer. Use Emulator or real device.'
      );
    }
    return SodiumFFI.nativeModuleRef;
  }

  static sodiumInit(): number {
    const nativeModule: ESObject = SodiumFFI.getNativeModule();
    const result: number = nativeModule.sodiumInit() as number;
    SodiumFFI.initialized = result === 0;
    if (SodiumFFI.initialized) {
      Logger.info(TAG, 'libsodium initialized successfully');
    } else {
      Logger.error(TAG, 'libsodium initialization failed');
    }
    return result;
  }

  static isInitialized(): boolean {
    return SodiumFFI.initialized;
  }

  // --- Constants ---

  static get cryptoBoxNonceBytes(): number {
    return SodiumFFI.getNativeModule().CRYPTO_BOX_NONCEBYTES() as number;
  }

  static get cryptoBoxPublicKeyBytes(): number {
    return SodiumFFI.getNativeModule().CRYPTO_BOX_PUBLICKEYBYTES() as number;
  }

  static get cryptoBoxSecretKeyBytes(): number {
    return SodiumFFI.getNativeModule().CRYPTO_BOX_SECRETKEYBYTES() as number;
  }

  static get cryptoBoxMacBytes(): number {
    return SodiumFFI.getNativeModule().CRYPTO_BOX_MACBYTES() as number;
  }

  static get cryptoSecretboxKeyBytes(): number {
    return SodiumFFI.getNativeModule().CRYPTO_SECRETBOX_KEYBYTES() as number;
  }

  static get cryptoSecretboxNonceBytes(): number {
    return SodiumFFI.getNativeModule().CRYPTO_SECRETBOX_NONCEBYTES() as number;
  }

  static get cryptoSecretboxMacBytes(): number {
    return SodiumFFI.getNativeModule().CRYPTO_SECRETBOX_MACBYTES() as number;
  }

  static get cryptoSignPublicKeyBytes(): number {
    return SodiumFFI.getNativeModule().CRYPTO_SIGN_PUBLICKEYBYTES() as number;
  }

  static get cryptoSignSecretKeyBytes(): number {
    return SodiumFFI.getNativeModule().CRYPTO_SIGN_SECRETKEYBYTES() as number;
  }

  static get cryptoSignBytes(): number {
    return SodiumFFI.getNativeModule().CRYPTO_SIGN_BYTES() as number;
  }

  static get cryptoSignSeedBytes(): number {
    return SodiumFFI.getNativeModule().CRYPTO_SIGN_SEEDBYTES() as number;
  }

  static get cryptoBoxSeedBytes(): number {
    return SodiumFFI.getNativeModule().CRYPTO_BOX_SEEDBYTES() as number;
  }

  // --- Random ---

  static randomBytesBuf(buffer: Uint8Array, length: number): void {
    SodiumFFI.getNativeModule().randomBytesBuf(buffer, length);
  }

  static randomBytesBufNew(length: number): Uint8Array {
    return SodiumFFI.getNativeModule().randomBytesBufNew(length) as Uint8Array;
  }

  // --- Ed25519 Sign ---

  static cryptoSignSeedKeypair(seed: Uint8Array): SodiumKeypair {
    const result: ESObject = SodiumFFI.getNativeModule().cryptoSignSeedKeypair(seed) as ESObject;
    return new SodiumKeypair(
      result.publicKey as Uint8Array,
      result.secretKey as Uint8Array,
    );
  }

  static cryptoSignDetached(message: Uint8Array, secretKey: Uint8Array): Uint8Array {
    return SodiumFFI.getNativeModule().cryptoSignDetached(message, secretKey) as Uint8Array;
  }

  static cryptoSignVerifyDetached(signature: Uint8Array, message: Uint8Array, publicKey: Uint8Array): boolean {
    return SodiumFFI.getNativeModule().cryptoSignVerifyDetached(signature, message, publicKey) as boolean;
  }

  // --- NaCl Box ---

  static cryptoBoxKeypair(): SodiumKeypair {
    const result: ESObject = SodiumFFI.getNativeModule().cryptoBoxKeypair() as ESObject;
    return new SodiumKeypair(
      result.publicKey as Uint8Array,
      result.secretKey as Uint8Array,
    );
  }

  static cryptoBoxSeedKeypair(seed: Uint8Array): SodiumKeypair {
    const result: ESObject = SodiumFFI.getNativeModule().cryptoBoxSeedKeypair(seed) as ESObject;
    return new SodiumKeypair(
      result.publicKey as Uint8Array,
      result.secretKey as Uint8Array,
    );
  }

  static cryptoBoxEasy(
    plaintext: Uint8Array,
    nonce: Uint8Array,
    recipientPublicKey: Uint8Array,
    senderSecretKey: Uint8Array,
  ): Uint8Array {
    return SodiumFFI.getNativeModule().cryptoBoxEasy(plaintext, nonce, recipientPublicKey, senderSecretKey) as Uint8Array;
  }

  static cryptoBoxOpenEasy(
    ciphertext: Uint8Array,
    nonce: Uint8Array,
    senderPublicKey: Uint8Array,
    recipientSecretKey: Uint8Array,
  ): Uint8Array | null {
    const nativeModule: ESObject = SodiumFFI.getNativeModule();
    const result: Object | null = nativeModule.cryptoBoxOpenEasy(ciphertext, nonce, senderPublicKey, recipientSecretKey) as Object | null;
    if (result === null) {
      return null;
    }
    return result as Uint8Array;
  }

  // --- NaCl SecretBox ---

  static cryptoSecretboxEasy(plaintext: Uint8Array, nonce: Uint8Array, key: Uint8Array): Uint8Array {
    return SodiumFFI.getNativeModule().cryptoSecretboxEasy(plaintext, nonce, key) as Uint8Array;
  }

  static cryptoSecretboxOpenEasy(ciphertext: Uint8Array, nonce: Uint8Array, key: Uint8Array): Uint8Array | null {
    const nativeModule: ESObject = SodiumFFI.getNativeModule();
    const result: Object | null = nativeModule.cryptoSecretboxOpenEasy(ciphertext, nonce, key) as Object | null;
    if (result === null) {
      return null;
    }
    return result as Uint8Array;
  }
}
