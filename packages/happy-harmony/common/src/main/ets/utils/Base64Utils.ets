import util from '@ohos.util';

export class Base64Utils {
  private constructor() {}

  static encode(data: Uint8Array): string {
    const helper = new util.Base64Helper();
    return helper.encodeToStringSync(data);
  }

  static decode(str: string): Uint8Array {
    const helper = new util.Base64Helper();
    return helper.decodeSync(str);
  }

  /** Encode to base64url (URL-safe: replace + with -, / with _, remove padding). */
  static encodeBase64Url(data: Uint8Array): string {
    const base64: string = Base64Utils.encode(data);
    return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  /** Decode from base64url (add padding, restore + and /). */
  static decodeBase64Url(str: string): Uint8Array {
    let base64: string = str.replace(/-/g, '+').replace(/_/g, '/');
    while (base64.length % 4 !== 0) {
      base64 = base64 + '=';
    }
    return Base64Utils.decode(base64);
  }
}
