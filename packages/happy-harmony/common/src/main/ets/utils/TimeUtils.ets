export class TimeUtils {
  private constructor() {}

  static now(): number {
    return Date.now();
  }

  static formatTimestamp(ts: number): string {
    const date = new Date(ts);
    return date.toLocaleString();
  }

  static toSeconds(ts: number): number {
    return Math.floor(ts / 1000);
  }
}
