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
}
