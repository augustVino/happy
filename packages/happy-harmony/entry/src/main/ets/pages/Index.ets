/**
 * Index page - Application entry point.
 * Initializes sodium, checks auth state, and routes accordingly.
 */
import { SodiumFFI } from 'common';
import { AuthState } from 'common';
import { AuthService } from 'auth';
import { LightColors } from 'ui';
import { AppTypography } from 'ui';
import { Logger } from 'common';
import router from '@ohos.router';
import sodiumWrapper from 'libentry.so';

const TAG = 'IndexPage';

@Entry
@Component
struct Index {
  @State authState: AuthState = AuthState.UNKNOWN;
  @State errorMessage: string = '';

  aboutToAppear(): void {
    Logger.info(TAG, 'Index page aboutToAppear');
    this.initializeApp();
  }

  async initializeApp(): Promise<void> {
    try {
      // Step 1: Initialize libsodium
      SodiumFFI.setNativeModule(sodiumWrapper as ESObject);
      SodiumFFI.sodiumInit();
      Logger.info(TAG, 'libsodium initialized');

      // Step 2: Check stored credentials
      const authService: AuthService = AuthService.getInstance();
      const result = await authService.restoreSession();

      if (result.success) {
        this.authState = AuthState.AUTHENTICATED;
        Logger.info(TAG, 'User authenticated, navigating to sessions');
        router.replaceUrl({ url: 'pages/SessionsPage' });
      } else {
        this.authState = AuthState.UNAUTHENTICATED;
        Logger.info(TAG, 'No stored credentials');
      }
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, 'Init failed: ' + errMsg);
      this.errorMessage = errMsg;
      this.authState = AuthState.UNAUTHENTICATED;
    }
  }

  build() {
    Column() {
      if (this.authState === AuthState.UNKNOWN) {
        this.buildLoadingContent();
      } else if (this.authState === AuthState.AUTHENTICATED) {
        this.buildAuthenticatedContent();
      } else {
        this.buildUnauthenticatedContent();
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildLoadingContent() {
    Column() {
      Text('Loading...')
        .fontSize(AppTypography.BODY_LARGE)
        .fontColor(LightColors.TEXT_SECONDARY)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(LightColors.BACKGROUND)
  }

  @Builder
  buildAuthenticatedContent() {
    Column() {
      Text('Happy Coder')
        .fontSize(AppTypography.TITLE_LARGE)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightColors.TEXT_PRIMARY)
        .margin({ bottom: 8 })

      Text('Account Connected')
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(LightColors.TEXT_SECONDARY)
        .margin({ bottom: 48 })

      Button('Continue')
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(LightColors.PRIMARY)
        .fontColor(LightColors.PRIMARY_TEXT)
        .borderRadius(12)
        .width('60%')
        .onClick(() => {
          Logger.info(TAG, 'Navigate to sessions');
          router.replaceUrl({ url: 'pages/SessionsPage' });
        })

      Button('Logout')
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(LightColors.ERROR)
        .backgroundColor(Color.Transparent)
        .margin({ top: 16 })
        .onClick(async () => {
          const authService: AuthService = AuthService.getInstance();
          await authService.logout();
          this.authState = AuthState.UNAUTHENTICATED;
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(LightColors.BACKGROUND)
  }

  @Builder
  buildUnauthenticatedContent() {
    Column() {
      Text('Happy Coder')
        .fontSize(AppTypography.TITLE_LARGE)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightColors.TEXT_PRIMARY)
        .margin({ bottom: 8 })

      Text('AI Coding Agent')
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(LightColors.TEXT_SECONDARY)
        .margin({ bottom: 48 })

      Button('Create Account')
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(LightColors.PRIMARY)
        .fontColor(LightColors.PRIMARY_TEXT)
        .borderRadius(12)
        .width('80%')
        .margin({ bottom: 16 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/LoginPage' });
        })

      Button('Restore Account')
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(Color.Transparent)
        .fontColor(LightColors.PRIMARY)
        .borderRadius(12)
        .width('80%')
        .border({ width: 1, color: LightColors.PRIMARY })
        .onClick(() => {
          router.pushUrl({ url: 'pages/RestorePage' });
        })

      if (this.errorMessage !== '') {
        Text(this.errorMessage)
          .fontSize(AppTypography.BODY_SMALL)
          .fontColor(LightColors.ERROR)
          .margin({ top: 24 })
          .padding({ left: 24, right: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(LightColors.BACKGROUND)
  }
}
