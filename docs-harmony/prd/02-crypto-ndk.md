# 加密方案：libsodium NDK 移植

> **优先级：P0（唯一阻塞项）**
> **必须在写任何业务代码之前完成**

## 问题

现有项目使用 TweetNaCl (CLI) 和 libsodium (App) 实现认证和端到端加密。ArkTS `@ohos.security.cryptoFramework` 不支持 XSalsa20-Poly1305（NaCl Box/SecretBox 的核心算法），导致以下能力缺失：

- 认证签名后的密钥推导（`crypto_box_seed_keypair`）
- Data Encryption Key 的加密存储（`crypto_box_easy`）
- Legacy 数据解密（`crypto_secretbox_open_easy`）

## 方案选择

### 方案 A：协议升级（服务端改 v2 加密）

```
优点：用 CryptoFramework 原生 API（AES-256-GCM + ECDH）
缺点：需改 Server + 现有数据需迁移 + 鸿蒙与旧数据不兼容
```

### 方案 B：libsodium NDK 移植（推荐）

```
优点：100% 兼容现有协议，零服务端改动
缺点：需维护 NDK 编译 + FFI 调用有性能开销
```

### 选定方案 B 的理由

1. **不再维护 Android/iOS** — 不需要多平台交叉编译，只编译鸿蒙一个目标
2. **零 Server 改动** — Server 的加密逻辑完全不动
3. **现有用户数据无需迁移** — 鸿蒙 App 直接解密现有会话
4. **一次性工作** — 编译一次 .so，所有加密全部解决
5. **libsodium 是成熟 C 库** — 鸿蒙 NDK 基于 clang/llvm，适配工作量小

## 现有加密原语清单

### A. 认证签名（Ed25519）

| 原语 | 算法 | 调用位置 |
|------|------|---------|
| `crypto_sign_seed_keypair(seed)` | Ed25519 | `cli/encryption.ts:204`、`app/authChallenge.ts:5` |
| `crypto_sign_detached(challenge, sk)` | Ed25519 | `cli/encryption.ts:206`、`app/authChallenge.ts:7` |
| `crypto_sign_detached.verify(ch, sig, pk)` | Ed25519 | `server/authRoutes.ts:22` |

### B. 非对称加密（Box）

| 原语 | 算法 | 调用位置 |
|------|------|---------|
| `crypto_box_seed_keypair(seed)` | X25519 | `app/libsodium.ts:5` |
| `crypto_box_easy(data, nonce, pk, sk)` | X25519 + XSalsa20-Poly1305 | `app/libsodium.ts:11`、`cli/encryption.ts:70` |
| `crypto_box_open_easy(enc, nonce, pk, sk)` | X25519 + XSalsa20-Poly1305 | `app/libsodium.ts:24`、`cli/encryption.ts:76` |

Bundle 格式：`ephemeralPublicKey(32) + nonce(24) + ciphertext`

### C. 对称加密 — Legacy (SecretBox)

| 原语 | 算法 | 调用位置 |
|------|------|---------|
| `crypto_secretbox_easy(data, nonce, key)` | XSalsa20-Poly1305 | `app/libsodium.ts:38`、`cli/encryption.ts:88` |
| `crypto_secretbox_open_easy(enc, nonce, key)` | XSalsa20-Poly1305 | `app/libsodium.ts:46`、`cli/encryption.ts:103` |

Bundle 格式：`nonce(24) + ciphertext`

### D. 对称加密 — DataKey (AES-256-GCM)

| 原语 | 算法 | 调用位置 |
|------|------|---------|
| `createCipheriv('aes-256-gcm', key, nonce)` | AES-256-GCM | `cli/encryption.ts:122` |
| `createDecipheriv('aes-256-gcm', key, nonce)` | AES-256-GCM | `cli/encryption.ts:165` |

Bundle 格式：`version(1) + nonce(12) + ciphertext + authTag(16)`

### E. 辅助

| 原语 | 用途 |
|------|------|
| `crypto_box_seal` / `crypto_box_seal_open` | 加密封装（如使用） |
| `randombytes_buf(n)` | CSPRNG |
| `crypto_hash_sha512` | SHA-512（公钥推导） |

## NDK 移植实施

### Step 1: 交叉编译 libsodium

libsodium 使用 CMake 构建系统，鸿蒙 NDK 支持 CMake。

**CMakeLists.txt 适配**：

```cmake
# CMakeLists.txt (鸿蒙 NDK 适配)
cmake_minimum_required(VERSION 3.16)
project(libsodium_ohos C)

set(CMAKE_SYSTEM_NAME OHOS)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# 禁用不需要的组件
set(ENABLE_MINIMAL "ON")
set(SODIUM_MINIMAL "ON")
set(SODIUM_BUILD_SHARED "ON")

# 编译选项
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fvisibility=hidden")
set(CMAKE_SHARED_LINKER_FLAGS "-Wl,--gc-sections")

add_subdirectory(libsodium)
```

**构建命令**：

```bash
# 使用 DevEco Studio 的 NDK 工具链
cmake -B build \
  -DCMAKE_TOOLCHAIN_FILE=${OHOS_NDK_HOME}/native/build/cmake/ohos.toolchain.cmake \
  -DOHOS_ARCH=arm64-v8a \
  -DOHOS_API_LEVEL=12 \
  -DENABLE_MINIMAL=ON

cmake --build build --parallel
```

**输出**：`build/libsodium/lib/libsodium.so`

### Step 2: ArkTS FFI 绑定

鸿蒙 `@ohos.ffi` (API 12+) 提供 C 函数调用能力。

```typescript
// common/src/main/ets/crypto/SodiumFFI.ets

import ffi from '@ohos.ffi'
import { libsodiumPath } from './SodiumPath'

// 加载 .so
const sodiumLib = ffi.loadLibSync(libsodiumPath)

// FFI 函数签名定义
const sodium_init = sodiumLib.defineFunction(
  'sodium_init',         // 函数名
  ffi.DataType.SINT32,   // 返回值: int
  []                     // 参数: 无
)

const crypto_sign_seed_keypair = sodiumLib.defineFunction(
  'crypto_sign_seed_keypair',
  ffi.DataType.SINT32,
  [
    ffi.DataType.POINTER, // publicKey (output, 32 bytes)
    ffi.DataType.POINTER, // secretKey (output, 64 bytes)
    ffi.DataType.POINTER, // seed (input, 32 bytes)
  ]
)

const crypto_sign_detached = sodiumLib.defineFunction(
  'crypto_sign_detached',
  ffi.DataType.SINT32,
  [
    ffi.DataType.POINTER, // signature (output, 64 bytes)
    ffi.DataType.POINTER, // sigLen (output, size_t*)
    ffi.DataType.POINTER, // message (input)
    ffi.DataType.UINT64,  // messageLen
    ffi.DataType.POINTER, // secretKey (input, 64 bytes)
  ]
)

const crypto_box_seed_keypair = sodiumLib.defineFunction(
  'crypto_box_seed_keypair',
  ffi.DataType.SINT32,
  [
    ffi.DataType.POINTER, // publicKey (output, 32 bytes)
    ffi.DataType.POINTER, // secretKey (output, 32 bytes)
    ffi.DataType.POINTER, // seed (input, 32 bytes)
  ]
)

const crypto_box_easy = sodiumLib.defineFunction(
  'crypto_box_easy',
  ffi.DataType.SINT32,
  [
    ffi.DataType.POINTER, // ciphertext (output)
    ffi.DataType.POINTER, // message (input)
    ffi.DataType.UINT64,  // messageLen
    ffi.DataType.POINTER, // nonce (input, 24 bytes)
    ffi.DataType.POINTER, // publicKey (input, 32 bytes)
    ffi.DataType.POINTER, // secretKey (input, 32 bytes)
  ]
)

const crypto_box_open_easy = sodiumLib.defineFunction(
  'crypto_box_open_easy',
  ffi.DataType.SINT32,
  [
    ffi.DataType.POINTER, // plaintext (output)
    ffi.DataType.POINTER, // ciphertext (input)
    ffi.DataType.UINT64,  // ciphertextLen
    ffi.DataType.POINTER, // nonce (input, 24 bytes)
    ffi.DataType.POINTER, // publicKey (input, 32 bytes)
    ffi.DataType.POINTER, // secretKey (input, 32 bytes)
  ]
)

const crypto_secretbox_easy = sodiumLib.defineFunction(
  'crypto_secretbox_easy',
  ffi.DataType.SINT32,
  [
    ffi.DataType.POINTER, // ciphertext (output)
    ffi.DataType.POINTER, // message (input)
    ffi.DataType.UINT64,  // messageLen
    ffi.DataType.POINTER, // nonce (input, 24 bytes)
    ffi.DataType.POINTER, // key (input, 32 bytes)
  ]
)

const crypto_secretbox_open_easy = sodiumLib.defineFunction(
  'crypto_secretbox_open_easy',
  ffi.DataType.SINT32,
  [
    ffi.DataType.POINTER, // plaintext (output)
    ffi.DataType.POINTER, // ciphertext (input)
    ffi.DataType.UINT64,  // ciphertextLen
    ffi.DataType.POINTER, // nonce (input, 24 bytes)
    ffi.DataType.POINTER, // key (input, 32 bytes)
  ]
)

const randombytes_buf = sodiumLib.defineFunction(
  'randombytes_buf',
  ffi.DataType.VOID,
  [
    ffi.DataType.POINTER, // buf (output)
    ffi.DataType.UINT64,  // size
  ]
)

// 初始化
let initialized = false
export function sodiumInit(): void {
  if (initialized) return
  sodium_init()
  initialized = true
}
```

### Step 3: 高级封装

```typescript
// common/src/main/ets/crypto/SodiumCrypto.ets

import { sodiumInit, crypto_sign_seed_keypair, crypto_sign_detached,
  crypto_box_seed_keypair, crypto_box_easy, crypto_box_open_easy,
  crypto_secretbox_easy, crypto_secretbox_open_easy, randombytes_buf }
  from './SodiumFFI'
import { allocBuffer, readBuffer, toUint8Array } from './BufferUtils'

export class SodiumCrypto {
  // ─── 认证签名 ───

  static signKeyPairFromSeed(seed: Uint8Array): { publicKey: Uint8Array; secretKey: Uint8Array } {
    sodiumInit()
    const publicKey = allocBuffer(32)
    const secretKey = allocBuffer(64)
    crypto_sign_seed_keypair(publicKey.ptr, secretKey.ptr, toUint8Array(seed).ptr)
    return { publicKey: readBuffer(publicKey, 32), secretKey: readBuffer(secretKey, 64) }
  }

  static signDetached(message: Uint8Array, secretKey: Uint8Array): Uint8Array {
    sodiumInit()
    const signature = allocBuffer(64)
    const sigLen = allocBuffer(8) // size_t
    crypto_sign_detached(
      signature.ptr, sigLen.ptr,
      toUint8Array(message).ptr, BigInt(message.length),
      toUint8Array(secretKey).ptr
    )
    return readBuffer(signature, 64)
  }

  // ─── 非对称加密 (Box) ───

  static boxKeyPairFromSeed(seed: Uint8Array): { publicKey: Uint8Array; secretKey: Uint8Array } {
    sodiumInit()
    const publicKey = allocBuffer(32)
    const secretKey = allocBuffer(32)
    crypto_box_seed_keypair(publicKey.ptr, secretKey.ptr, toUint8Array(seed).ptr)
    return { publicKey: readBuffer(publicKey, 32), secretKey: readBuffer(secretKey, 32) }
  }

  static boxEncrypt(message: Uint8Array, nonce: Uint8Array,
    publicKey: Uint8Array, secretKey: Uint8Array): Uint8Array {
    sodiumInit()
    const ciphertext = allocBuffer(message.length + 16) // +16 for MAC
    crypto_box_easy(
      ciphertext.ptr, toUint8Array(message).ptr, BigInt(message.length),
      toUint8Array(nonce).ptr, toUint8Array(publicKey).ptr, toUint8Array(secretKey).ptr
    )
    return readBuffer(ciphertext, message.length + 16)
  }

  static boxDecrypt(ciphertext: Uint8Array, nonce: Uint8Array,
    publicKey: Uint8Array, secretKey: Uint8Array): Uint8Array | null {
    sodiumInit()
    const plaintext = allocBuffer(ciphertext.length - 16)
    const result = crypto_box_open_easy(
      plaintext.ptr, toUint8Array(ciphertext).ptr, BigInt(ciphertext.length),
      toUint8Array(nonce).ptr, toUint8Array(publicKey).ptr, toUint8Array(secretKey).ptr
    )
    if (result !== 0) return null
    return readBuffer(plaintext, ciphertext.length - 16)
  }

  // ─── 对称加密 (SecretBox) ───

  static secretboxEncrypt(message: Uint8Array, nonce: Uint8Array, key: Uint8Array): Uint8Array {
    sodiumInit()
    const ciphertext = allocBuffer(message.length + 16)
    crypto_secretbox_easy(
      ciphertext.ptr, toUint8Array(message).ptr, BigInt(message.length),
      toUint8Array(nonce).ptr, toUint8Array(key).ptr
    )
    return readBuffer(ciphertext, message.length + 16)
  }

  static secretboxDecrypt(ciphertext: Uint8Array, nonce: Uint8Array, key: Uint8Array): Uint8Array | null {
    sodiumInit()
    const plaintext = allocBuffer(ciphertext.length - 16)
    const result = crypto_secretbox_open_easy(
      plaintext.ptr, toUint8Array(ciphertext).ptr, BigInt(ciphertext.length),
      toUint8Array(nonce).ptr, toUint8Array(key).ptr
    )
    if (result !== 0) return null
    return readBuffer(plaintext, ciphertext.length - 16)
  }

  // ─── 随机数 ───

  static randomBytes(n: number): Uint8Array {
    sodiumInit()
    const buf = allocBuffer(n)
    randombytes_buf(buf.ptr, BigInt(n))
    return readBuffer(buf, n)
  }
}
```

## PoC 验证清单

所有测试在鸿蒙真机或模拟器上运行，与现有 CLI 输出对比。

### PoC-1: libsodium 编译 + FFI 调用

```
验证:
  1. CMake 交叉编译 libsodium 生成 .so
  2. ArkTS @ohos.ffi 加载 .so
  3. 调用 sodium_init() 返回 0

通过标准: 无编译错误，FFI 调用成功
```

### PoC-2: Ed25519 签名兼容性

```
输入: 固定种子 (32 bytes hex: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
      + 固定 challenge (64 bytes)

验证:
  1. ArkTS 用种子生成 Ed25519 keypair
  2. 对 challenge 签名
  3. 对比 CLI 的 tweetnacl.sign.detached() 输出
  4. 用 CLI 的公钥在服务端验签

通过标准: 签名完全一致（64 bytes hex 相同）
```

### PoC-3: crypto_box 兼容性

```
输入: 固定 seed (32 bytes) + 固定 nonce (24 bytes) + 固定 plaintext

验证:
  1. ArkTS 用 seed 生成 X25519 keypair
  2. 加密 plaintext
  3. 对比 CLI 的 tweetnacl.box() 输出
  4. CLI 加密 → ArkTS 解密（交叉验证）
  5. ArkTS 加密 → CLI 解密（交叉验证）

通过标准: 密文一致，交叉解密成功
```

### PoC-4: crypto_secretbox 兼容性

```
输入: 固定 key (32 bytes) + 固定 nonce (24 bytes) + 固定 plaintext

验证:
  1. ArkTS 加密
  2. 对比 CLI 的 tweetnacl.secretbox() 输出
  3. 交叉解密

通过标准: 密文一致，交叉解密成功
```

### PoC-5: 完整认证流程

```
验证:
  1. 生成 32 字节随机 secret
  2. Ed25519 签名 challenge
  3. POST /v1/auth 获取 JWT token
  4. 用 token 调用 GET /v1/sessions

通过标准: 认证成功，能拉取会话列表
```

### PoC-6: 完整加密流程

```
验证:
  1. 用现有账户的 secret
  2. 推导 content key pair
  3. 解密现有 session 的 data encryption key
  4. 用 DEK 解密现有消息

通过标准: 能解密真实会话数据
```

## 备选方案（如果 NDK 编译失败）

如果 libsodium NDK 移植遇到不可逾越的问题，启用备选方案 A：

**服务端协议升级（v2 加密）**

```
1. Server 新增 v2 加密路径：
   - 新账户：ECDH-P256 + AES-256-GCM（CryptoFramework 原生支持）
   - 现有账户：服务端桥接（v1 密文 → 解密 → v2 重新加密）

2. 鸿蒙客户端：
   - 新账户：用 CryptoFramework 原生 API
   - 旧账户：调用 Server 桥接 API 解密数据

3. 迁移期：
   - 数据库同时存储 v1 + v2 密文
   - 新消息用 v2 加密
   - 旧消息按需桥接解密
```

**触发条件**：PoC-1 或 PoC-2 失败且 3 天内无法修复。

## .so 集成到鸿蒙项目

```
packages/happy-harmony/
├── libs/
│   └── arm64-v8a/
│       └── libsodium.so          # 编译产物
├── entry/src/main/
│   ├── ets/
│   │   └── crypto/
│   │       ├── SodiumFFI.ets      # FFI 函数定义
│   │       ├── SodiumCrypto.ets   # 高级封装
│   │       ├── BufferUtils.ets    # FFI Buffer 工具
│   │       └── SodiumPath.ets     # .so 路径配置
│   └── module.json5               # NDK 配置
```

`module.json5` 中声明 NDK 依赖：

```json5
{
  "module": {
    "name": "entry",
    "type": "entry",
    "requestPermissions": [
      { "name": "ohos.permission.INTERNET" }
    ]
  }
}
```

## 工作量估算

| 步骤 | 预估时间 |
|------|---------|
| CMake 适配 + 交叉编译 | 0.5 天 |
| FFI 绑定（函数签名定义） | 0.5 天 |
| 高级封装（SodiumCrypto 类） | 0.5 天 |
| PoC 验证（6 项） | 1 天 |
| Buffer 工具 + 集成到项目 | 0.5 天 |
| **合计** | **3 天** |
