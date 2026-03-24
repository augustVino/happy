# Phase 0 原生构建方案修订：交叉编译 libsodium

> **状态**: 待审批
> **日期**: 2026-03-24
> **背景**: 自建 CMakeLists.txt 方案因未知风险被否决，改为使用 HarmonyOS NDK 交叉编译上游 libsodium 生成 `.a` 静态库

---

## 1. 问题回顾

### 1.1 当前状态

- `sodium_wrapper.cpp` N-API 封装层已完成，功能正确
- `SodiumFFI.ets`、`SodiumCrypto.ets`、`BufferUtils.ets`、`KeyDerivation.ets` 等 ArkTS 文件已完成
- **构建失败**：自建 `libsodium/CMakeLists.txt`（170+ 源文件列表）导致编译错误：
  1. 头文件路径不匹配（`core.h` 找不到）
  2. 缺少 `configure` 生成的版本宏（`SODIUM_VERSION_STRING` 等）
  3. 未知风险：手动维护源文件列表难以覆盖所有依赖

### 1.2 方案排除

| 方案 | 排除原因 |
|------|---------|
| 自建 CMakeLists.txt | 用户否决，未知风险太多 |
| libsodium 官方 CMake 分支 | 不存在（stable/master 均无 CMakeLists.txt） |
| OpenHarmony-SIG/libsodium GN 移植 | API 9 (OH 3.1 Beta)，与 API 22 (HarmonyOS NEXT) 不兼容 |

### 1.3 最终方案：NDK 交叉编译

使用 HarmonyOS NDK 的 clang 工具链，通过 libsodium 官方 autotools（`./configure`）交叉编译，产出 `libsodium.a` 静态库，再通过 CMake `IMPORTED` 目标引入项目。

**核心优势**：
- 使用 libsodium 官方构建系统，零自建风险
- 官方 `configure` 正确处理所有头文件、宏、依赖关系
- 静态库 `.a` 链接到 `sodium_wrapper.so`，最终只产出一个 .so 文件

---

## 2. 交叉编译流程

### 2.1 前置条件

- macOS 开发机（当前环境）
- HarmonyOS SDK NDK `6.0.2(22)` 已安装
  - 默认路径：`~/Library/Huawei/Sdk/openharmony/native` 或 DevEco 配置的路径
- autotools 工具链：`autoconf`、`automake`、`libtool`

### 2.2 编译步骤

```bash
# 1. 进入 libsodium 源码目录（已存在于项目中）
cd packages/happy-harmony/common/src/main/cpp/libsodium

# 2. 设置 NDK 环境变量（根据实际 SDK 路径调整）
export NDK_HOME=~/Library/Huawei/Sdk/openharmony/native
export TOOLCHAIN=$NDK_HOME/llvm
export TARGET=aarch64-linux-ohos

# 3. 运行 autogen.sh 生成 configure 脚本
./autogen.sh

# 4. 配置交叉编译
./configure \
    --host=$TARGET \
    CC=$TOOLCHAIN/bin/clang \
    AR=$TOOLCHAIN/bin/llvm-ar \
    RANLIB=$TOOLCHAIN/bin/llvm-ranlib \
    NM=$TOOLCHAIN/bin/llvm-nm \
    STRIP=$TOOLCHAIN/bin/llvm-strip \
    CFLAGS="-target aarch64-linux-ohos -fPIC -O2" \
    --disable-shared \
    --enable-static \
    --prefix=$PWD/../libsodium-prebuilt

# 5. 编译并安装
make -j$(sysctl -n hw.ncpu)
make install
```

### 2.3 预期产出

```
packages/happy-harmony/common/src/main/cpp/libsodium-prebuilt/
├── include/
│   └── sodium.h          # 公共头文件
│   └── sodium/
│       ├── core.h
│       ├── crypto_box.h
│       ├── crypto_sign.h
│       ├── crypto_secretbox.h
│       ├── randombytes.h
│       ├── utils.h
│       └── ...           # 完整的公共头文件
└── lib/
    └── libsodium.a       # arm64-v8a 静态库
```

### 2.4 备选方案：CMake 交叉编译

如果 autotools 编译遇到问题，可使用 CMake 交叉编译：

```bash
cd packages/happy-harmony/common/src/main/cpp/libsodium

mkdir build-ohos && cd build-ohos

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$NDK_HOME/build/cmake/ohos.toolchain.cmake \
    -DOHOS_ARCH=arm64-v8a \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_INSTALL_PREFIX=../libsodium-prebuilt

cmake --build . -j$(sysctl -n hw.ncpu)
cmake --install .
```

> **注意**：libsodium 官方 stable 分支没有 CMakeLists.txt，但 `forked` 版本或最新 `master` 分支可能包含。需要检查实际 clone 的源码。

---

## 3. 项目集成改动

### 3.1 文件变更清单

| 操作 | 文件路径 | 说明 |
|------|---------|------|
| **修改** | `common/CMakeLists.txt` | 改用 IMPORTED 静态库 |
| **删除** | `common/src/main/cpp/libsodium/CMakeLists.txt` | 移除自建构建文件 |
| **新增** | `common/src/main/cpp/libsodium-prebuilt/` | 交叉编译产出目录（.gitignore） |
| **保留** | `common/src/main/cpp/sodium_wrapper.cpp` | N-API 封装层（不变） |
| **保留** | `common/src/main/cpp/libsodium/` | 保留源码（编译用） |
| **修改** | `.gitignore` | 忽略预编译产物 |
| **保留** | `common/build-profile.json5` | 不变 |

### 3.2 新的 CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.5)
project(common)

# Import pre-built libsodium static library
add_library(sodium STATIC IMPORTED)
set_target_properties(sodium PROPERTIES
    IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/libsodium-prebuilt/lib/libsodium.a
    INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp/libsodium-prebuilt/include
)

# N-API wrapper library
add_library(sodium_wrapper SHARED
    src/main/cpp/sodium_wrapper.cpp
)

target_include_directories(sodium_wrapper PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src/main/cpp
)

target_link_libraries(sodium_wrapper
    sodium
    ace_napi.z
)

# Compiler warnings
target_compile_options(sodium_wrapper PRIVATE
    -Wall -Wextra
)
```

### 3.3 .gitignore 追加

```
# libsodium pre-built artifacts
packages/happy-harmony/common/src/main/cpp/libsodium-prebuilt/
```

---

## 4. 验证步骤

### 4.1 编译验证

1. 在 DevEco Studio 中执行 `Build > Build Hap(s)/APP(s) > Build APP(s)`
2. 预期结果：构建成功，无编译错误
3. 验证产物：`libsodium_wrapper.so` 包含 libsodium 符号

```bash
# 在构建产物中验证
nm entry/.preview/default/arm64-v8a/libsodium_wrapper.so | grep sodium_init
# 预期输出类似：
# 00000000 T sodium_init
```

### 4.2 运行时验证

在设备/模拟器上验证 `SodiumFFI` 能正常加载：

1. 调用 `SodiumFFI.init()` → 应返回 `0`
2. 调用 `SodiumFFI.randomBytes(32)` → 应返回 32 字节
3. 调用 `SodiumFFI.cryptoBoxKeypair()` → 应返回 64 字节密钥对

### 4.3 加密兼容性验证

使用 CLI 端 `verify-crypto-test-vectors.cjs` 生成的测试向量，在鸿蒙端验证：

1. **Ed25519 签名验证**：CLI 签名的 challenge 能在鸿蒙端验证
2. **crypto_box 加解密**：CLI 加密的数据能在鸿蒙端解密
3. **crypto_secretbox 加解密**：CLI 加密的数据能在鸿蒙端解密
4. **密钥派生一致性**：HMAC-SHA512 树派生结果与 CLI 端一致

---

## 5. 风险与降级

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| autotools 在 macOS 上交叉编译失败 | 中 | 高 | 使用 CMake 交叉编译备选方案 |
| NDK 路径不匹配 | 低 | 低 | 检查 DevEco 配置，灵活调整 |
| `randombytes_sysrandom.c` 不兼容鸿蒙 | 低 | 高 | 可替换为 `/dev/urandom` 或 `getrandom()` |
| `.a` 与 NDK clang ABI 不兼容 | 低 | 高 | 确保使用同一 NDK 工具链编译 |

### 降级方案：纯 ArkTS tweetnacl

如果所有原生编译方案均失败，可临时使用纯 JS 的 `tweetnacl` 实现：
- 复制 `tweetnacl` 源码到项目中（无 NPM 依赖）
- 在 ArkTS 中直接调用
- 性能较低，但可快速验证协议兼容性
- 仅作为 Phase 0 PoC 的临时方案

---

## 6. 执行顺序

1. 确认 NDK 路径并安装 autotools
2. 执行交叉编译，生成 `libsodium.a`
3. 更新 `common/CMakeLists.txt` 为 IMPORTED 模式
4. 删除自建 `libsodium/CMakeLists.txt`
5. 更新 `.gitignore`
6. DevEco Studio 构建验证
7. 运行时功能验证
8. 加密兼容性交叉验证
