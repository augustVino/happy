/**
 * Configuration for libsodium native library.
 *
 * The libsodium source must be placed at:
 *   common/src/main/cpp/libsodium/
 *
 * To set up:
 *   cd packages/happy-harmony/common/src/main/cpp
 *   git clone --depth 1 --branch stable https://github.com/jedisct1/libsodium.git
 */
export class SodiumPath {
  private constructor() {}

  /**
   * Relative path to the libsodium source directory from the module root.
   */
  static readonly LIBSODIUM_SOURCE_RELATIVE: string = 'src/main/cpp/libsodium';

  /**
   * N-API module name used for registration in sodium_wrapper.cpp.
   */
  static readonly NAPI_MODULE_NAME: string = 'sodium_wrapper';
}
