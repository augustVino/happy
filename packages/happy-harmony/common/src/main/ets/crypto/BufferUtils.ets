import { util } from '@kit.ArkTS';

/**
 * Buffer utilities for FFI data exchange.
 * Provides helper functions for working with Uint8Array and ArrayBuffer.
 */
export class BufferUtils {
  private constructor() {}

  /**
   * Concatenate multiple Uint8Arrays into one.
   */
  static concat(...arrays: Uint8Array[]): Uint8Array {
    let totalLength = 0;
    for (let i = 0; i < arrays.length; i++) {
      totalLength += arrays[i].length;
    }
    const result = new Uint8Array(totalLength);
    let offset = 0;
    for (let i = 0; i < arrays.length; i++) {
      result.set(arrays[i], offset);
      offset += arrays[i].length;
    }
    return result;
  }

  /**
   * Create a Uint8Array from ArrayBuffer.
   */
  static fromArrayBuffer(buffer: ArrayBuffer): Uint8Array {
    return new Uint8Array(buffer);
  }

  /**
   * Get ArrayBuffer from Uint8Array.
   */
  static toArrayBuffer(array: Uint8Array): ArrayBuffer {
    return array.buffer.slice(array.byteOffset, array.byteOffset + array.byteLength);
  }

  /**
   * Slice a Uint8Array (returns a new copy).
   */
  static slice(array: Uint8Array, start: number, end?: number): Uint8Array {
    if (end === undefined) {
      return new Uint8Array(array.buffer.slice(array.byteOffset + start, array.byteOffset + array.length));
    }
    return new Uint8Array(array.buffer.slice(array.byteOffset + start, array.byteOffset + end));
  }

  /**
   * Convert a string to Uint8Array using UTF-8 encoding.
   */
  static fromUtf8String(str: string): Uint8Array {
    const helper = new util.TextEncoder();
    const result = helper.encodeInto(str);
    return new Uint8Array(result);
  }

  /**
   * Convert Uint8Array to UTF-8 string.
   */
  static toUtf8String(data: Uint8Array): string {
    const helper = new util.TextDecoder();
    return helper.decode(new Uint8Array(data));
  }

  /**
   * Convert Uint8Array to hex string.
   */
  static toHex(data: Uint8Array): string {
    const hexChars = '0123456789abcdef';
    let hex = '';
    for (let i = 0; i < data.length; i++) {
      const byte: number = data[i];
      const high: number = (byte >> 4) & 0x0f;
      const low: number = byte & 0x0f;
      hex += hexChars.charAt(high);
      hex += hexChars.charAt(low);
    }
    return hex;
  }

  /**
   * Convert hex string to Uint8Array.
   */
  static fromHex(hex: string): Uint8Array {
    if (hex.length % 2 !== 0) {
      throw new Error('Hex string must have even length');
    }
    const result = new Uint8Array(hex.length / 2);
    for (let i = 0; i < hex.length; i += 2) {
      const high = parseInt(hex.substring(i, i + 2), 16);
      result[i / 2] = high;
    }
    return result;
  }

  /**
   * Compare two Uint8Arrays for equality.
   */
  static equals(a: Uint8Array, b: Uint8Array): boolean {
    if (a.length !== b.length) {
      return false;
    }
    for (let i = 0; i < a.length; i++) {
      if (a[i] !== b[i]) {
        return false;
      }
    }
    return true;
  }

  /**
   * Zero out a Uint8Array (secure memory clearing).
   */
  static zeroOut(array: Uint8Array): void {
    for (let i = 0; i < array.length; i++) {
      array[i] = 0;
    }
  }

  /**
   * Create a Uint8Array filled with zeros.
   */
  static zeros(length: number): Uint8Array {
    return new Uint8Array(length);
  }
}
