#include <napi/native_api.h>
#include <sodium.h>
#include <string.h>
#include <stdlib.h>

// Helper: create napi_value from uint8 array
static napi_value createUint8Array(napi_env env, const unsigned char *data, size_t length) {
    void *buffer = nullptr;
    napi_value arrayBuffer = nullptr;
    napi_create_arraybuffer(env, length, &buffer, &arrayBuffer);
    if (data != nullptr && length > 0) {
        memcpy(buffer, data, length);
    }
    napi_value result = nullptr;
    napi_create_typedarray(env, napi_uint8_array, length, arrayBuffer, 0, &result);
    return result;
}

// Helper: get data pointer and length from a Uint8Array argument
static bool getUint8ArrayArg(napi_env env, napi_value arg, unsigned char **data, size_t *length) {
    bool isTypedArray = false;
    napi_is_typedarray(env, arg, &isTypedArray);
    if (!isTypedArray) {
        return false;
    }

    napi_typedarray_type type;
    napi_value arrayBuffer = nullptr;
    size_t offset = 0;
    napi_get_typedarray_info(env, arg, &type, length, reinterpret_cast<void **>(data), &arrayBuffer, &offset);

    return type == napi_uint8_array;
}

// sodium_init() -> number
static napi_value SodiumInit(napi_env env, napi_callback_info info) {
    int result = sodium_init();
    napi_value returnValue;
    napi_create_int32(env, result, &returnValue);
    return returnValue;
}

// randombytes_buf(buffer: Uint8Array, length: number) -> void
static napi_value RandomBytesBuf(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) {
        napi_throw_error(env, nullptr, "randombytes_buf requires 2 arguments: buffer, length");
        return nullptr;
    }

    unsigned char *buffer = nullptr;
    size_t bufferLength = 0;
    if (!getUint8ArrayArg(env, args[0], &buffer, &bufferLength)) {
        napi_throw_error(env, nullptr, "randombytes_buf: first argument must be Uint8Array");
        return nullptr;
    }

    int32_t length = 0;
    napi_get_value_int32(env, args[1], &length);

    if (length <= 0 || (size_t)length > bufferLength) {
        napi_throw_error(env, nullptr, "randombytes_buf: invalid length");
        return nullptr;
    }

    randombytes_buf(buffer, (size_t)length);

    napi_value undefined;
    napi_get_undefined(env, &undefined);
    return undefined;
}

// randombytes_buf_new(length: number) -> Uint8Array
static napi_value RandomBytesBufNew(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t length = 0;
    napi_get_value_int32(env, args[0], &length);

    if (length <= 0) {
        napi_throw_error(env, nullptr, "randombytes_buf_new: length must be positive");
        return nullptr;
    }

    unsigned char *buffer = (unsigned char *)malloc(length);
    if (!buffer) {
        napi_throw_error(env, nullptr, "randombytes_buf_new: allocation failed");
        return nullptr;
    }

    randombytes_buf(buffer, (size_t)length);
    napi_value result = createUint8Array(env, buffer, length);
    free(buffer);
    return result;
}

// crypto_sign_seed_keypair(seed: Uint8Array) -> { publicKey: Uint8Array, secretKey: Uint8Array }
static napi_value CryptoSignSeedKeypair(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    unsigned char *seed = nullptr;
    size_t seedLen = 0;
    if (!getUint8ArrayArg(env, args[0], &seed, &seedLen)) {
        napi_throw_error(env, nullptr, "crypto_sign_seed_keypair: argument must be Uint8Array");
        return nullptr;
    }

    if (seedLen != crypto_sign_SEEDBYTES) {
        napi_throw_error(env, nullptr, "crypto_sign_seed_keypair: seed must be 32 bytes");
        return nullptr;
    }

    unsigned char pk[crypto_sign_PUBLICKEYBYTES];
    unsigned char sk[crypto_sign_SECRETKEYBYTES];
    crypto_sign_seed_keypair(pk, sk, seed);

    napi_value result;
    napi_create_object(env, &result);

    napi_value pkValue = createUint8Array(env, pk, crypto_sign_PUBLICKEYBYTES);
    napi_value skValue = createUint8Array(env, sk, crypto_sign_SECRETKEYBYTES);

    napi_set_named_property(env, result, "publicKey", pkValue);
    napi_set_named_property(env, result, "secretKey", skValue);

    return result;
}

// crypto_sign_detached(message: Uint8Array, secretKey: Uint8Array) -> Uint8Array
static napi_value CryptoSignDetached(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    unsigned char *message = nullptr;
    size_t messageLen = 0;
    if (!getUint8ArrayArg(env, args[0], &message, &messageLen)) {
        napi_throw_error(env, nullptr, "crypto_sign_detached: message must be Uint8Array");
        return nullptr;
    }

    unsigned char *secretKey = nullptr;
    size_t skLen = 0;
    if (!getUint8ArrayArg(env, args[1], &secretKey, &skLen)) {
        napi_throw_error(env, nullptr, "crypto_sign_detached: secretKey must be Uint8Array");
        return nullptr;
    }

    if (skLen != crypto_sign_SECRETKEYBYTES) {
        napi_throw_error(env, nullptr, "crypto_sign_detached: secretKey must be 64 bytes");
        return nullptr;
    }

    unsigned char sig[crypto_sign_BYTES];
    crypto_sign_detached(sig, nullptr, message, messageLen, secretKey);

    return createUint8Array(env, sig, crypto_sign_BYTES);
}

// crypto_sign_verify_detached(signature: Uint8Array, message: Uint8Array, publicKey: Uint8Array) -> boolean
static napi_value CryptoSignVerifyDetached(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 3) {
        napi_throw_error(env, nullptr, "crypto_sign_verify_detached requires 3 arguments: signature, message, publicKey");
        return nullptr;
    }

    unsigned char *sig = nullptr;
    size_t sigLen = 0;
    if (!getUint8ArrayArg(env, args[0], &sig, &sigLen)) {
        napi_throw_error(env, nullptr, "crypto_sign_verify_detached: signature must be Uint8Array");
        return nullptr;
    }

    unsigned char *message = nullptr;
    size_t messageLen = 0;
    if (!getUint8ArrayArg(env, args[1], &message, &messageLen)) {
        napi_throw_error(env, nullptr, "crypto_sign_verify_detached: message must be Uint8Array");
        return nullptr;
    }

    unsigned char *publicKey = nullptr;
    size_t pkLen = 0;
    if (!getUint8ArrayArg(env, args[2], &publicKey, &pkLen)) {
        napi_throw_error(env, nullptr, "crypto_sign_verify_detached: publicKey must be Uint8Array");
        return nullptr;
    }

    int result = crypto_sign_verify_detached(sig, message, messageLen, publicKey);

    napi_value returnValue;
    napi_get_boolean(env, result == 0, &returnValue);
    return returnValue;
}

// crypto_box_keypair() -> { publicKey: Uint8Array, secretKey: Uint8Array }
static napi_value CryptoBoxKeypair(napi_env env, napi_callback_info info) {
    unsigned char pk[crypto_box_PUBLICKEYBYTES];
    unsigned char sk[crypto_box_SECRETKEYBYTES];
    crypto_box_keypair(pk, sk);

    napi_value result;
    napi_create_object(env, &result);

    napi_value pkValue = createUint8Array(env, pk, crypto_box_PUBLICKEYBYTES);
    napi_value skValue = createUint8Array(env, sk, crypto_box_SECRETKEYBYTES);

    napi_set_named_property(env, result, "publicKey", pkValue);
    napi_set_named_property(env, result, "secretKey", skValue);

    return result;
}

// crypto_box_seed_keypair(seed: Uint8Array) -> { publicKey: Uint8Array, secretKey: Uint8Array }
static napi_value CryptoBoxSeedKeypair(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    unsigned char *seed = nullptr;
    size_t seedLen = 0;
    if (!getUint8ArrayArg(env, args[0], &seed, &seedLen)) {
        napi_throw_error(env, nullptr, "crypto_box_seed_keypair: seed must be Uint8Array");
        return nullptr;
    }

    if (seedLen != crypto_box_SEEDBYTES) {
        napi_throw_error(env, nullptr, "crypto_box_seed_keypair: seed must be 32 bytes");
        return nullptr;
    }

    unsigned char pk[crypto_box_PUBLICKEYBYTES];
    unsigned char sk[crypto_box_SECRETKEYBYTES];
    crypto_box_seed_keypair(pk, sk, seed);

    napi_value result;
    napi_create_object(env, &result);

    napi_value pkValue = createUint8Array(env, pk, crypto_box_PUBLICKEYBYTES);
    napi_value skValue = createUint8Array(env, sk, crypto_box_SECRETKEYBYTES);

    napi_set_named_property(env, result, "publicKey", pkValue);
    napi_set_named_property(env, result, "secretKey", skValue);

    return result;
}

// crypto_box_easy(plaintext: Uint8Array, nonce: Uint8Array, recipientPublicKey: Uint8Array, senderSecretKey: Uint8Array) -> Uint8Array
static napi_value CryptoBoxEasy(napi_env env, napi_callback_info info) {
    size_t argc = 4;
    napi_value args[4] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 4) {
        napi_throw_error(env, nullptr, "crypto_box_easy requires 4 arguments: plaintext, nonce, recipientPublicKey, senderSecretKey");
        return nullptr;
    }

    unsigned char *plaintext = nullptr;
    size_t plaintextLen = 0;
    if (!getUint8ArrayArg(env, args[0], &plaintext, &plaintextLen)) {
        napi_throw_error(env, nullptr, "crypto_box_easy: plaintext must be Uint8Array");
        return nullptr;
    }

    unsigned char *nonce = nullptr;
    size_t nonceLen = 0;
    if (!getUint8ArrayArg(env, args[1], &nonce, &nonceLen)) {
        napi_throw_error(env, nullptr, "crypto_box_easy: nonce must be Uint8Array");
        return nullptr;
    }

    unsigned char *recipientPk = nullptr;
    size_t recipientPkLen = 0;
    if (!getUint8ArrayArg(env, args[2], &recipientPk, &recipientPkLen)) {
        napi_throw_error(env, nullptr, "crypto_box_easy: recipientPublicKey must be Uint8Array");
        return nullptr;
    }

    unsigned char *senderSk = nullptr;
    size_t senderSkLen = 0;
    if (!getUint8ArrayArg(env, args[3], &senderSk, &senderSkLen)) {
        napi_throw_error(env, nullptr, "crypto_box_easy: senderSecretKey must be Uint8Array");
        return nullptr;
    }

    size_t ciphertextLen = plaintextLen + crypto_box_MACBYTES;
    unsigned char *ciphertext = (unsigned char *)malloc(ciphertextLen);
    if (!ciphertext) {
        napi_throw_error(env, nullptr, "crypto_box_easy: allocation failed");
        return nullptr;
    }

    int result = crypto_box_easy(ciphertext, plaintext, plaintextLen, nonce, recipientPk, senderSk);
    if (result != 0) {
        free(ciphertext);
        napi_throw_error(env, nullptr, "crypto_box_easy: encryption failed");
        return nullptr;
    }

    napi_value returnValue = createUint8Array(env, ciphertext, ciphertextLen);
    free(ciphertext);
    return returnValue;
}

// crypto_box_open_easy(ciphertext: Uint8Array, nonce: Uint8Array, senderPublicKey: Uint8Array, recipientSecretKey: Uint8Array) -> Uint8Array | null
static napi_value CryptoBoxOpenEasy(napi_env env, napi_callback_info info) {
    size_t argc = 4;
    napi_value args[4] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 4) {
        napi_throw_error(env, nullptr, "crypto_box_open_easy requires 4 arguments: ciphertext, nonce, senderPublicKey, recipientSecretKey");
        return nullptr;
    }

    unsigned char *ciphertext = nullptr;
    size_t ciphertextLen = 0;
    if (!getUint8ArrayArg(env, args[0], &ciphertext, &ciphertextLen)) {
        napi_throw_error(env, nullptr, "crypto_box_open_easy: ciphertext must be Uint8Array");
        return nullptr;
    }

    unsigned char *nonce = nullptr;
    size_t nonceLen = 0;
    if (!getUint8ArrayArg(env, args[1], &nonce, &nonceLen)) {
        napi_throw_error(env, nullptr, "crypto_box_open_easy: nonce must be Uint8Array");
        return nullptr;
    }

    unsigned char *senderPk = nullptr;
    size_t senderPkLen = 0;
    if (!getUint8ArrayArg(env, args[2], &senderPk, &senderPkLen)) {
        napi_throw_error(env, nullptr, "crypto_box_open_easy: senderPublicKey must be Uint8Array");
        return nullptr;
    }

    unsigned char *recipientSk = nullptr;
    size_t recipientSkLen = 0;
    if (!getUint8ArrayArg(env, args[3], &recipientSk, &recipientSkLen)) {
        napi_throw_error(env, nullptr, "crypto_box_open_easy: recipientSecretKey must be Uint8Array");
        return nullptr;
    }

    if (ciphertextLen < crypto_box_MACBYTES) {
        napi_value nullValue;
        napi_get_null(env, &nullValue);
        return nullValue;
    }

    size_t plaintextLen = ciphertextLen - crypto_box_MACBYTES;
    unsigned char *plaintext = (unsigned char *)malloc(plaintextLen);
    if (!plaintext) {
        napi_throw_error(env, nullptr, "crypto_box_open_easy: allocation failed");
        return nullptr;
    }

    int result = crypto_box_open_easy(plaintext, ciphertext, ciphertextLen, nonce, senderPk, recipientSk);
    if (result != 0) {
        free(plaintext);
        napi_value nullValue;
        napi_get_null(env, &nullValue);
        return nullValue;
    }

    napi_value returnValue = createUint8Array(env, plaintext, plaintextLen);
    free(plaintext);
    return returnValue;
}

// crypto_secretbox_easy(plaintext: Uint8Array, nonce: Uint8Array, key: Uint8Array) -> Uint8Array
static napi_value CryptoSecretboxEasy(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 3) {
        napi_throw_error(env, nullptr, "crypto_secretbox_easy requires 3 arguments: plaintext, nonce, key");
        return nullptr;
    }

    unsigned char *plaintext = nullptr;
    size_t plaintextLen = 0;
    if (!getUint8ArrayArg(env, args[0], &plaintext, &plaintextLen)) {
        napi_throw_error(env, nullptr, "crypto_secretbox_easy: plaintext must be Uint8Array");
        return nullptr;
    }

    unsigned char *nonce = nullptr;
    size_t nonceLen = 0;
    if (!getUint8ArrayArg(env, args[1], &nonce, &nonceLen)) {
        napi_throw_error(env, nullptr, "crypto_secretbox_easy: nonce must be Uint8Array");
        return nullptr;
    }

    unsigned char *key = nullptr;
    size_t keyLen = 0;
    if (!getUint8ArrayArg(env, args[2], &key, &keyLen)) {
        napi_throw_error(env, nullptr, "crypto_secretbox_easy: key must be Uint8Array");
        return nullptr;
    }

    size_t ciphertextLen = plaintextLen + crypto_secretbox_MACBYTES;
    unsigned char *ciphertext = (unsigned char *)malloc(ciphertextLen);
    if (!ciphertext) {
        napi_throw_error(env, nullptr, "crypto_secretbox_easy: allocation failed");
        return nullptr;
    }

    int result = crypto_secretbox_easy(ciphertext, plaintext, plaintextLen, nonce, key);
    if (result != 0) {
        free(ciphertext);
        napi_throw_error(env, nullptr, "crypto_secretbox_easy: encryption failed");
        return nullptr;
    }

    napi_value returnValue = createUint8Array(env, ciphertext, ciphertextLen);
    free(ciphertext);
    return returnValue;
}

// crypto_secretbox_open_easy(ciphertext: Uint8Array, nonce: Uint8Array, key: Uint8Array) -> Uint8Array | null
static napi_value CryptoSecretboxOpenEasy(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 3) {
        napi_throw_error(env, nullptr, "crypto_secretbox_open_easy requires 3 arguments: ciphertext, nonce, key");
        return nullptr;
    }

    unsigned char *ciphertext = nullptr;
    size_t ciphertextLen = 0;
    if (!getUint8ArrayArg(env, args[0], &ciphertext, &ciphertextLen)) {
        napi_throw_error(env, nullptr, "crypto_secretbox_open_easy: ciphertext must be Uint8Array");
        return nullptr;
    }

    unsigned char *nonce = nullptr;
    size_t nonceLen = 0;
    if (!getUint8ArrayArg(env, args[1], &nonce, &nonceLen)) {
        napi_throw_error(env, nullptr, "crypto_secretbox_open_easy: nonce must be Uint8Array");
        return nullptr;
    }

    unsigned char *key = nullptr;
    size_t keyLen = 0;
    if (!getUint8ArrayArg(env, args[2], &key, &keyLen)) {
        napi_throw_error(env, nullptr, "crypto_secretbox_open_easy: key must be Uint8Array");
        return nullptr;
    }

    if (ciphertextLen < crypto_secretbox_MACBYTES) {
        napi_value nullValue;
        napi_get_null(env, &nullValue);
        return nullValue;
    }

    size_t plaintextLen = ciphertextLen - crypto_secretbox_MACBYTES;
    unsigned char *plaintext = (unsigned char *)malloc(plaintextLen);
    if (!plaintext) {
        napi_throw_error(env, nullptr, "crypto_secretbox_open_easy: allocation failed");
        return nullptr;
    }

    int result = crypto_secretbox_open_easy(plaintext, ciphertext, ciphertextLen, nonce, key);
    if (result != 0) {
        free(plaintext);
        napi_value nullValue;
        napi_get_null(env, &nullValue);
        return nullValue;
    }

    napi_value returnValue = createUint8Array(env, plaintext, plaintextLen);
    free(plaintext);
    return returnValue;
}

// crypto_box_NONCEBYTES -> number
static napi_value GetBoxNonceBytes(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_uint32(env, crypto_box_NONCEBYTES, &result);
    return result;
}

// crypto_box_PUBLICKEYBYTES -> number
static napi_value GetBoxPublicKeyBytes(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_uint32(env, crypto_box_PUBLICKEYBYTES, &result);
    return result;
}

// crypto_box_SECRETKEYBYTES -> number
static napi_value GetBoxSecretKeyBytes(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_uint32(env, crypto_box_SECRETKEYBYTES, &result);
    return result;
}

// crypto_box_MACBYTES -> number
static napi_value GetBoxMacBytes(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_uint32(env, crypto_box_MACBYTES, &result);
    return result;
}

// crypto_secretbox_KEYBYTES -> number
static napi_value GetSecretboxKeyBytes(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_uint32(env, crypto_secretbox_KEYBYTES, &result);
    return result;
}

// crypto_secretbox_NONCEBYTES -> number
static napi_value GetSecretboxNonceBytes(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_uint32(env, crypto_secretbox_NONCEBYTES, &result);
    return result;
}

// crypto_secretbox_MACBYTES -> number
static napi_value GetSecretboxMacBytes(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_uint32(env, crypto_secretbox_MACBYTES, &result);
    return result;
}

// crypto_sign_PUBLICKEYBYTES -> number
static napi_value GetSignPublicKeyBytes(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_uint32(env, crypto_sign_PUBLICKEYBYTES, &result);
    return result;
}

// crypto_sign_SECRETKEYBYTES -> number
static napi_value GetSignSecretKeyBytes(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_uint32(env, crypto_sign_SECRETKEYBYTES, &result);
    return result;
}

// crypto_sign_BYTES -> number
static napi_value GetSignBytes(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_uint32(env, crypto_sign_BYTES, &result);
    return result;
}

// crypto_sign_SEEDBYTES -> number
static napi_value GetSignSeedBytes(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_uint32(env, crypto_sign_SEEDBYTES, &result);
    return result;
}

// crypto_box_SEEDBYTES -> number
static napi_value GetBoxSeedBytes(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_uint32(env, crypto_box_SEEDBYTES, &result);
    return result;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        // Functions
        {"sodiumInit", nullptr, SodiumInit, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"randomBytesBuf", nullptr, RandomBytesBuf, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"randomBytesBufNew", nullptr, RandomBytesBufNew, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"cryptoSignSeedKeypair", nullptr, CryptoSignSeedKeypair, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"cryptoSignDetached", nullptr, CryptoSignDetached, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"cryptoSignVerifyDetached", nullptr, CryptoSignVerifyDetached, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"cryptoBoxKeypair", nullptr, CryptoBoxKeypair, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"cryptoBoxSeedKeypair", nullptr, CryptoBoxSeedKeypair, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"cryptoBoxEasy", nullptr, CryptoBoxEasy, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"cryptoBoxOpenEasy", nullptr, CryptoBoxOpenEasy, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"cryptoSecretboxEasy", nullptr, CryptoSecretboxEasy, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"cryptoSecretboxOpenEasy", nullptr, CryptoSecretboxOpenEasy, nullptr, nullptr, nullptr, napi_default, nullptr},

        // Constants
        {"CRYPTO_BOX_NONCEBYTES", nullptr, GetBoxNonceBytes, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"CRYPTO_BOX_PUBLICKEYBYTES", nullptr, GetBoxPublicKeyBytes, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"CRYPTO_BOX_SECRETKEYBYTES", nullptr, GetBoxSecretKeyBytes, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"CRYPTO_BOX_MACBYTES", nullptr, GetBoxMacBytes, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"CRYPTO_SECRETBOX_KEYBYTES", nullptr, GetSecretboxKeyBytes, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"CRYPTO_SECRETBOX_NONCEBYTES", nullptr, GetSecretboxNonceBytes, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"CRYPTO_SECRETBOX_MACBYTES", nullptr, GetSecretboxMacBytes, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"CRYPTO_SIGN_PUBLICKEYBYTES", nullptr, GetSignPublicKeyBytes, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"CRYPTO_SIGN_SECRETKEYBYTES", nullptr, GetSignSecretKeyBytes, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"CRYPTO_SIGN_BYTES", nullptr, GetSignBytes, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"CRYPTO_SIGN_SEEDBYTES", nullptr, GetSignSeedBytes, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"CRYPTO_BOX_SEEDBYTES", nullptr, GetBoxSeedBytes, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = "entry",
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterSodiumWrapperModule() {
    napi_module_register(&module);
}
