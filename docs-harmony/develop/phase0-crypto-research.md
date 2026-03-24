# Phase 0 加密 PoC 研究文档

> **创建日期**: 2026-03-23
> **负责人**: 加密工程师
> **状态**: 研究阶段

---

## 1. 现有加密实现分析

### 1.1 核心加密库依赖

| 平台 | 库 | 说明 |
|------|------|------|
| CLI (Node.js) | `tweetnacl` | 纯 JS 实现的 NaCl 加密库 |
| App (React Native) | `@more-tech/react-native-libsodium` | libsodium 的 RN 封装 |
| App (Web) | `libsodium` (WebAssembly) | 浏览器端 WASM 版本 |

### 1.2 核心加密操作

以下是从现有代码中提取的核心加密操作：

#### 1.2.1 Ed25519 签名认证

**文件**: `packages/happy-cli/src/api/encryption.ts`

```typescript
export function authChallenge(secret: Uint8Array): {
  challenge: Uint8Array
  publicKey: Uint8Array
  signature: Uint8Array
} {
  const keypair = tweetnacl.sign.keyPair.fromSeed(secret);
  const challenge = getRandomBytes(32);
  const signature = tweetnacl.sign.detached(challenge, keypair.secretKey);

  return {
    challenge,
    publicKey: keypair.publicKey,
    signature
  };
}
```

**关键点**:
- 使用 Ed25519 签名算法
- `secret` 是 32 字节种子
- `publicKey` 是 32 字节
- `signature` 是 64 字节

#### 1.2.2 crypto_box 公钥加密

**文件**: `packages/happy-cli/src/api/encryption.ts`

```typescript
export function libsodiumEncryptForPublicKey(data: Uint8Array, recipientPublicKey: Uint8Array): Uint8Array {
  const ephemeralKeyPair = tweetnacl.box.keyPair();
  const nonce = getRandomBytes(tweetnacl.box.nonceLength); // 24 bytes
  const encrypted = tweetnacl.box(data, nonce, recipientPublicKey, ephemeralKeyPair.secretKey);

  // Bundle: ephemeral pubkey(32) + nonce(24) + ciphertext
  const result = new Uint8Array(32 + 24 + encrypted.length);
  result.set(ephemeralKeyPair.publicKey, 0);
  result.set(nonce, 32);
  result.set(encrypted, 56);
  return result;
}
```

**Bundle 格式**: `[32字节临时公钥][24字节nonce][密文]`

#### 1.2.3 crypto_secretbox 对称加密

**文件**: `packages/happy-cli/src/api/encryption.ts`

```typescript
export function encryptLegacy(data: any, secret: Uint8Array): Uint8Array {
  const nonce = getRandomBytes(tweetnacl.secretbox.nonceLength); // 24 bytes
  const encrypted = tweetnacl.secretbox(
    new TextEncoder().encode(JSON.stringify(data)),
    nonce,
    secret
  );
  const result = new Uint8Array(nonce.length + encrypted.length);
  result.set(nonce);
  result.set(encrypted, nonce.length);
  return result;
}
```

**Bundle 格式**: `[24字节nonce][密文]`

#### 1.2.4 AES-256-GCM 加密 (dataKey 变体)

**文件**: `packages/happy-cli/src/api/encryption.ts`

```typescript
export function encryptWithDataKey(data: any, dataKey: Uint8Array): Uint8Array {
  const nonce = getRandomBytes(12); // GCM uses 12-byte nonces
  const cipher = createCipheriv('aes-256-gcm', dataKey, nonce);
  const plaintext = new TextEncoder().encode(JSON.stringify(data));
  const encrypted = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const authTag = cipher.getAuthTag();

  // Bundle: version(1) + nonce(12) + ciphertext + authTag(16)
  const bundle = new Uint8Array(12 + encrypted.length + 16 + 1);
  bundle.set([0], 0);
  bundle.set(nonce, 1);
  bundle.set(new Uint8Array(encrypted), 13);
  bundle.set(new Uint8Array(authTag), 13 + encrypted.length);

  return bundle;
}
```

**Bundle 格式**: `[1字节版本号=0][12字节nonce][密文][16字节authTag]`

#### 1.2.5 密钥派生树 (HMAC-SHA512)

**文件**: `packages/happy-agent/src/encryption.ts`

```typescript
export function deriveSecretKeyTreeRoot(seed: Uint8Array, usage: string): KeyTreeState {
  const I = hmac_sha512(new TextEncoder().encode(usage + ' Master Seed'), seed);
  return {
    key: I.slice(0, 32),
    chainCode: I.slice(32),
  };
}

export function deriveSecretKeyTreeChild(chainCode: Uint8Array, index: string): KeyTreeState {
  const data = new Uint8Array([0x00, ...new TextEncoder().encode(index)]);
  const I = hmac_sha512(chainCode, data);
  return {
    key: I.slice(0, 32),
    chainCode: I.slice(32),
  };
}
```

**关键点**:
- 使用 HMAC-SHA512 进行密钥派生
- 每次派生产生 64 字节输出
- 前 32 字节为 key，后 32 字节为 chainCode

### 1.3 固定测试向量

从 `packages/happy-agent/src/encryption.test.ts` 提取的测试向量：

```typescript
// 测试向量 1: deriveSecretKeyTreeRoot
seed = "test seed" (UTF-8)
usage = "test usage"
expected key = E6E55652456F9FE47D6FF46CA3614E85B499F77E7B340FBBB1553307CEDC1E74

// 测试向量 2: 完整派生路径
seed = "test seed" (UTF-8)
usage = "test usage"
path = ["child1", "child2"]
expected key = 1011C097D2105D27362B987A631496BBF68B836124D1D072E9D1613C6028CF75
```

### 1.4 App 端加密实现差异

**文件**: `packages/happy-app/sources/encryption/libsodium.ts`

```typescript
// App 端使用 libsodium 而非 tweetnacl
import sodium from '@/encryption/libsodium.lib';

export function getPublicKeyForBox(secretKey: Uint8Array): Uint8Array {
  return sodium.crypto_box_seed_keypair(secretKey).publicKey;
}

export function encryptBox(data: Uint8Array, recipientPublicKey: Uint8Array): Uint8Array {
  const ephemeralKeyPair = sodium.crypto_box_keypair();
  const nonce = getRandomBytes(sodium.crypto_box_NONCEBYTES);
  const encrypted = sodium.crypto_box_easy(data, nonce, recipientPublicKey, ephemeralKeyPair.privateKey);
  // ... bundle 格式与 CLI 相同
}
```

**关键差异** - ⚠️ **Phase 0 重点验证**:

| 平台 | `crypto_box_seed_keypair` 行为 |
|------|-------------------------------|
| **CLI (tweetnacl)** | 私钥 = SHA-512(seed)[0:32]，然后 `keyPair.fromSecretKey()` |
| **App (libsodium)** | 直接 `crypto_box_seed_keypair(seed)`，内部做 SHA-512 |
| **鸿蒙 (libsodium)** | **应该与 App 端一致** |

**CLI 端兼容处理**:
```typescript
export function libsodiumPublicKeyFromSecretKey(seed: Uint8Array): Uint8Array {
  // 手动 SHA-512 然后 tweetnacl.box.keyPair.fromSecretKey
  const hashedSeed = new Uint8Array(createHash('sha512').update(seed).digest());
  const secretKey = hashedSeed.slice(0, 32);
  return new Uint8Array(tweetnacl.box.keyPair.fromSecretKey(secretKey).publicKey);
}
```

**Phase 0 验证要求**:
1. 鸿蒙端使用 `crypto_box_seed_keypair`（与 App 端一致，而非 CLI 的手动 SHA-512）
2. 验证 CLI 加密包能在鸿蒙端解密（使用 `verify-crypto-test-vectors.cjs` 生成的测试向量）
3. 确保 `deriveContentKeyPair` 与 App 端行为一致

---

## 2. 鸿蒙 NDK / FFI 技术方案

### 2.1 NDK 构建系统

鸿蒙 NEXT NDK 默认使用 **CMake** 作为构建系统，提供 `ohos.toolchain.cmake` 工具链文件。

**参考文档**:
- [华为开发者文档 - 使用命令行 CMake 构建 NDK 项目](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/build-with-ndk-cmake)
- [三方动态链接库集成-NDK开发](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-dynamic-link-library)

### 2.2 FFI 方案选择

#### 方案 A: AKI 框架 (推荐)

**AKI** 是专为鸿蒙原生开发设计的 FFI 框架，用于解决 C/C++ 项目迁移到 HarmonyOS NEXT 的核心问题。

**特点**:
- 专为鸿蒙设计，文档完善
- 类型安全的 FFI 绑定
- 自动生成 ArkTS 到 C++ 的桥接代码

**参考文档**:
- [C/C++三方库移植到鸿蒙HarmonyOS平台详细教程](https://harmonyosdev.csdn.net/68a7f32b080e555a88dc1479.html)

#### 方案 B: @ohos.ffi (备选)

鸿蒙系统提供的官方 FFI API，直接在 ArkTS 中调用原生库。

**需要研究**:
- API 具体用法
- 类型转换规则
- 性能开销

### 2.3 libsodium 编译方案

#### 2.3.1 预编译库方案

**OpenHarmony-SIG 官方仓库**: [OpenHarmony-SIG/libsodium](https://gitee.com/openharmony-sig/libsodium)

**优点**:
- 已有针对 OpenHarmony 的移植版本
- 使用 GN 编译系统（鸿蒙标准）
- 可直接使用预编译的 .a 或 .so 文件

**参考文档**:
- [鸿蒙实战开发：OpenHarmony移植的加解密库—libsodium (GN编译)](https://blog.csdn.net/2401_88547687/article/details/144095684)
- [Ubuntu中用HarmonyOS Next的SDK编译libsodium](https://www.cnblogs.com/Fitz/p/19077518)

#### 2.3.2 交叉编译方案

**步骤**:
1. 使用 OpenHarmony SDK 的内置 clang 编译器
2. 配置交叉编译 sysroot
3. 生成 arm64-v8a 架构的 .so 文件

**关键配置**:
```cmake
# CMakeLists.txt
set(CMAKE_SYSTEM_NAME HarmonyOS)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(HOS_NDK ${HOS_SDK}/native)
set(CMAKE_SYSROOT ${HOS_NDK}/sysroot)

set(CMAKE_C_COMPILER ${HOS_NDK}/llvm/bin/clang)
set(CMAKE_CXX_COMPILER ${HOS_NDK}/llvm/bin/clang++)
```

### 2.4 .so 文件加载路径

鸿蒙项目中的 .so 文件标准路径：

```
packages/happy-harmony/
├── entry/
│   └── src/
│       └── main/
│           └── cpp/
│               ├── libs/
│               │   └── arm64-v8a/
│               │       └── libsodium.so
│               ├── CMakeLists.txt
│               └── cpp/
│                   └── sodium_ffi.cpp
```

**CMakeLists.txt 加载方式**:
```cmake
add_library(sodium SHARED IMPORTED)
set_target_properties(sodium PROPERTIES
    IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/libs/${OHOS_ARCH}/libsodium.so)

target_link_libraries(harmony sodium)
```

### 2.5 ABI 约束

鸿蒙支持的 ABI 架构：
- **arm64-v8a**: 64 位 ARM（推荐，主流设备）
- **armeabi-v7a**: 32 位 ARM（可选）

---

## 3. @ohos.security.cryptoFramework 能力评估

### 3.1 支持的算法

**参考文档**:
- [使用AES对称密钥（ECB模式）加解密(ArkTS)](https://developer.huawei.com/consumer/cn/forum/topic/0203201804468897265)
- [鸿蒙数据加密存储：AES加密本地敏感信息的最佳实践](http://www.huawei-cloud.com)

**支持的操作**:
- AES 对称加密（多种模式）
- RSA 非对称加密
- SM2 国密算法
- SHA-256、MD5 消息摘要
- HMAC

**核心 API**:
```typescript
import cryptoFramework from '@ohos.security.cryptoFramework';

// 创建对称密钥生成器
const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES256');
const symKey = await symKeyGenerator.generateSymKey();

// 创建加密器
const cipher = cryptoFramework.createCipher('AES256|ECB|PKCS7');
```

### 3.2 与 libsodium 的功能对比

| 功能 | libsodium | @ohos.security.cryptoFramework |
|------|-----------|-------------------------------|
| Ed25519 签名 | ✅ 支持 | ❌ 不支持 |
| crypto_box | ✅ 支持 | ❌ 不支持 |
| crypto_secretbox | ✅ 支持 | ❌ 不支持 |
| AES-256-GCM | ✅ 支持 | ✅ 支持 |
| HMAC-SHA512 | ✅ 支持 | ✅ 支持 |
| 随机数生成 | ✅ 支持 | ✅ 支持 |

**结论**: `@ohos.security.cryptoFramework` **无法替代** libsodium，因为不支持 Ed25519 和 NaCl 的 box 操作。

---

## 4. 风险评估与降级方案

### 4.1 主要风险

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| libsodium NDK 编译失败 | 高 | 中 | 使用 OpenHarmony-SIG 预编译版本 |
| FFI 调用不稳定 | 高 | 中 | 优先使用 AKI 框架 |
| 性能开销过大 | 中 | 低 | 批量操作减少跨语言调用 |
| 类型转换错误 | 高 | 低 | 完善单元测试覆盖 |

### 4.2 降级方案

#### 方案 A: 协议升级 (libsodium 不可用时)

如果 libsodium NDK 确实无法稳定工作：

1. **加密层迁移**: 将 Ed25519 和 crypto_box 迁移到 `@ohos.security.cryptoFramework` 支持的算法
   - Ed25519 → RSA-2048/4096 或 SM2
   - crypto_box → RSA-KEM + AES-256-GCM

2. **协议层适配**:
   - 服务端新增协议版本，支持多套加密套件
   - 现有客户端保持不变
   - 鸿蒙客户端使用新协议版本

3. **兼容性考虑**:
   - 会话密文需要重新加密迁移
   - 认证流程需要并行支持两套算法

**评估**: 此方案工作量较大，但可以作为备选路径。

#### 方案 B: 纯 JavaScript 实现 (临时方案)

使用 `tweetnacl` 或类似库的纯 JS/ArkTS 版本：

**优点**:
- 避免 NDK 编译问题
- 快速验证协议逻辑

**缺点**:
- 性能较差
- 不适合生产环境

**用途**: 仅用于 Phase 0 初步验证，不可作为长期方案。

---

## 5. 实施计划

### 5.1 Phase 0 任务拆分

1. **环境准备** (1-2 天)
   - [ ] 下载 OpenHarmony SDK 和 NDK
   - [ ] 配置 CMake 构建环境
   - [ ] 获取 libsodium 源码或预编译库

2. **libsodium 编译** (2-3 天)
   - [ ] 尝试使用 OpenHarmony-SIG 版本
   - [ ] 或使用交叉编译方案
   - [ ] 验证 .so 文件可正常加载

3. **FFI 桥接** (3-4 天)
   - [ ] 研究 AKI 框架用法
   - [ ] 实现基础 FFI 调用 (sodium_init)
   - [ ] 实现 BufferUtils (ArkTS ↔ C++ 内存交换)

4. **核心加密实现** (4-5 天)
   - [ ] 实现 SodiumFFI.ets
   - [ ] 实现 SodiumCrypto.ets
   - [ ] 实现 SodiumPath.ets

5. **一致性校验** (2-3 天)
   - [ ] 对照测试向量验证签名
   - [ ] 验证 crypto_box 加解密
   - [ ] 验证 crypto_secretbox 加解密

6. **认证 PoC** (2-3 天)
   - [ ] 调用 POST /v1/auth
   - [ ] 验证登录流程
   - [ ] 解密真实会话样本

### 5.2 产出文件清单

```
packages/happy-harmony/
├── libs/
│   └── arm64-v8a/
│       └── libsodium.so
├── common/src/main/ets/crypto/
│   ├── SodiumFFI.ets          # FFI 基础调用
│   ├── SodiumCrypto.ets        # 加密操作封装
│   ├── BufferUtils.ets         # 内存工具
│   └── SodiumPath.ets          # 密钥派生
└── common/src/main/ets/test/
    └── CryptoTest.ets          # 加密测试套件
```

---

## 6. 参考资料

### 6.1 官方文档
- [华为开发者文档中心 - NDK 开发](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/build-with-ndk-cmake)
- [三方动态链接库集成-NDK开发](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-dynamic-link-library)
- [@ohos.security.cryptoFramework 文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/huks-encryption-decryption-arkts)

### 6.2 社区资源
- [C/C++三方库移植到鸿蒙HarmonyOS平台详细教程](https://harmonyosdev.csdn.net/68a7f32b080e555a88dc1479.html)
- [鸿蒙实战开发：OpenHarmony移植的加解密库—libsodium](https://blog.csdn.net/2401_88547687/article/details/144095684)
- [Ubuntu中用HarmonyOS Next的SDK编译libsodium](https://www.cnblogs.com/Fitz/p/19077518)
- [OpenHarmony-SIG/libsodium (Gitee)](https://gitee.com/openharmony-sig/libsodium)

### 6.3 项目内部
- `packages/happy-cli/src/api/encryption.ts` - CLI 加密实现
- `packages/happy-agent/src/encryption.ts` - Agent 加密实现
- `packages/happy-app/sources/encryption/libsodium.ts` - App 加密实现
- `packages/happy-agent/src/encryption.test.ts` - 测试向量

---

## 7. 待确认事项

- [ ] 确认目标设备 ABI (是否需要同时支持 arm64-v8a 和 armeabi-v7a)
- [ ] 确认 libsodium 版本 (建议 1.0.18 或稳定版本)
- [ ] 确认 FFI 方案选择 (AKI vs @ohos.ffi)
- [ ] 确认是否需要支持热更新 (影响 .so 加载方式)
