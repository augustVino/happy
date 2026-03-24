import hilog from '@ohos.hilog';

const DOMAIN = 0x0001;

export class Logger {
  private constructor() {}

  static debug(tag: string, message: string): void {
    hilog.debug(DOMAIN, tag, message);
  }

  static info(tag: string, message: string): void {
    hilog.info(DOMAIN, tag, message);
  }

  static warn(tag: string, message: string): void {
    hilog.warn(DOMAIN, tag, message);
  }

  static error(tag: string, message: string): void {
    hilog.error(DOMAIN, tag, message);
  }
}
