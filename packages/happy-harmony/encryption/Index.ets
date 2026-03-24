// Encryption module exports
// Phase 0: Re-export crypto primitives from common module
export { SodiumFFI } from 'common';
export { SodiumKeypair } from 'common';
export { SodiumCrypto } from 'common';
export { AuthChallengeResult } from 'common';
export { BufferUtils } from 'common';
export { HmacSha512Utils } from 'common';
export { KeyDerivation } from 'common';
export { KeyTreeState } from 'common';

// Secure credential storage
export { SecureStore } from './src/main/ets/SecureStore';

// Phase 3: Encryption services
export { EncryptionService } from './src/main/ets/EncryptionService';
export { DataKeyManager } from './src/main/ets/DataKeyManager';
export { AesGcmCrypto } from './src/main/ets/AesGcmCrypto';
export { SessionEncryption } from './src/main/ets/SessionEncryption';
export { MachineEncryption } from './src/main/ets/MachineEncryption';
