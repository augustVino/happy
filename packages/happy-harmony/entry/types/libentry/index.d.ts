/**
 * Type declarations for libentry.so NAPI module.
 * Re-exports all sodium functions registered via the native entry point.
 */
export const sodiumInit: () => number;
export const randomBytesBuf: (buffer: Uint8Array, length: number) => void;
export const randomBytesBufNew: (length: number) => Uint8Array;
export const cryptoSignSeedKeypair: (seed: Uint8Array) => { publicKey: Uint8Array; secretKey: Uint8Array };
export const cryptoSignDetached: (message: Uint8Array, secretKey: Uint8Array) => Uint8Array;
export const cryptoSignVerifyDetached: (signature: Uint8Array, message: Uint8Array, publicKey: Uint8Array) => boolean;
export const cryptoBoxKeypair: () => { publicKey: Uint8Array; secretKey: Uint8Array };
export const cryptoBoxSeedKeypair: (seed: Uint8Array) => { publicKey: Uint8Array; secretKey: Uint8Array };
export const cryptoBoxEasy: (plaintext: Uint8Array, nonce: Uint8Array, recipientPublicKey: Uint8Array, senderSecretKey: Uint8Array) => Uint8Array;
export const cryptoBoxOpenEasy: (ciphertext: Uint8Array, nonce: Uint8Array, senderPublicKey: Uint8Array, recipientSecretKey: Uint8Array) => Uint8Array | null;
export const cryptoSecretboxEasy: (plaintext: Uint8Array, nonce: Uint8Array, key: Uint8Array) => Uint8Array;
export const cryptoSecretboxOpenEasy: (ciphertext: Uint8Array, nonce: Uint8Array, key: Uint8Array) => Uint8Array | null;
export const CRYPTO_BOX_NONCEBYTES: () => number;
export const CRYPTO_BOX_PUBLICKEYBYTES: () => number;
export const CRYPTO_BOX_SECRETKEYBYTES: () => number;
export const CRYPTO_BOX_MACBYTES: () => number;
export const CRYPTO_SECRETBOX_KEYBYTES: () => number;
export const CRYPTO_SECRETBOX_NONCEBYTES: () => number;
export const CRYPTO_SECRETBOX_MACBYTES: () => number;
export const CRYPTO_SIGN_PUBLICKEYBYTES: () => number;
export const CRYPTO_SIGN_SECRETKEYBYTES: () => number;
export const CRYPTO_SIGN_BYTES: () => number;
export const CRYPTO_SIGN_SEEDBYTES: () => number;
export const CRYPTO_BOX_SEEDBYTES: () => number;
