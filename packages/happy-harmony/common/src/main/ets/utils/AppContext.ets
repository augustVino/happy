/**
 * Application context holder.
 * Provides context to non-UI modules (preferences, etc.)
 * Must be initialized from EntryAbility.onCreate().
 */
import { common } from '@kit.AbilityKit';

class AppContext {
  private static appContext: common.Context | null = null;

  static setContext(ctx: common.Context): void {
    AppContext.appContext = ctx;
  }

  static getContext(): common.Context {
    if (AppContext.appContext !== null) {
      return AppContext.appContext;
    }
    throw new Error('AppContext not initialized. Call AppContext.setContext() from EntryAbility.onCreate().');
  }

  static reset(): void {
    AppContext.appContext = null;
  }
}

export { AppContext };
