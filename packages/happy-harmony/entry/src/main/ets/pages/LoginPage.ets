/**
 * Login page - Create a new account.
 */
import { AuthService } from 'auth';
import { AuthResult } from 'auth';
import { LightColors } from 'ui';
import { AppTypography } from 'ui';
import { Logger } from 'common';
import router from '@ohos.router';

const TAG = 'LoginPage';

@Entry
@Component
export struct LoginPage {
  @State isCreating: boolean = false;
  @State errorMessage: string = '';
  @State showSuccess: boolean = false;
  @State backupKey: string = '';

  aboutToAppear(): void {
    Logger.info(TAG, 'LoginPage appeared');
  }

  async createAccount(): Promise<void> {
    if (this.isCreating) {
      return;
    }
    this.isCreating = true;
    this.errorMessage = '';

    try {
      // Create account and authenticate with server
      const authService: AuthService = AuthService.getInstance();
      const result: AuthResult = await authService.createAccount();

      if (result.success) {
        this.backupKey = result.backupKey;
        this.showSuccess = true;
        Logger.info(TAG, 'Account created successfully');
      } else {
        this.errorMessage = result.errorMessage;
      }
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      this.errorMessage = errMsg;
      Logger.error(TAG, 'Create account error: ' + errMsg);
    } finally {
      this.isCreating = false;
    }
  }

  build() {
    Column() {
      // Back button
      Row() {
        Button('< Back')
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(LightColors.PRIMARY)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            router.back();
          })
      }
      .width('100%')
      .padding({ left: 16, top: 16 })
      .justifyContent(FlexAlign.Start)

      // Content
      Column() {
        Text('Create Account')
          .fontSize(AppTypography.TITLE_LARGE)
          .fontWeight(FontWeight.Bold)
          .fontColor(LightColors.TEXT_PRIMARY)
          .margin({ bottom: 12 })

        Text('A unique secret key will be generated for your account. Save it securely to restore your account later.')
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(LightColors.TEXT_SECONDARY)
          .margin({ bottom: 32 })

        if (!this.showSuccess) {
          // Create button
          Button(this.isCreating ? 'Creating...' : 'Create Account')
            .fontSize(AppTypography.BODY_LARGE)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.isCreating ? LightColors.TEXT_TERTIARY : LightColors.PRIMARY)
            .fontColor(LightColors.PRIMARY_TEXT)
            .borderRadius(12)
            .width('100%')
            .enabled(!this.isCreating)
            .onClick(() => {
              this.createAccount();
            })

          if (this.errorMessage !== '') {
            Text(this.errorMessage)
              .fontSize(AppTypography.BODY_SMALL)
              .fontColor(LightColors.ERROR)
              .margin({ top: 16 })
          }
        } else {
          // Success state - show backup key
          Column() {
            Text('Account Created!')
              .fontSize(AppTypography.TITLE_MEDIUM)
              .fontWeight(FontWeight.Bold)
              .fontColor(LightColors.SUCCESS)
              .margin({ bottom: 24 })

            Text('Save your recovery key')
              .fontSize(AppTypography.BODY_MEDIUM)
              .fontWeight(FontWeight.Medium)
              .fontColor(LightColors.TEXT_PRIMARY)
              .margin({ bottom: 8 })

            Text('Store this key in a safe place. You will need it to restore your account on a new device.')
              .fontSize(AppTypography.BODY_SMALL)
              .fontColor(LightColors.TEXT_SECONDARY)
              .margin({ bottom: 16 })

            // Backup key display
            Column() {
              Text(this.backupKey)
                .fontSize(AppTypography.BODY_MEDIUM)
                .fontWeight(FontWeight.Bold)
                .fontColor(LightColors.TEXT_PRIMARY)
                .textAlign(TextAlign.Center)
                .wordBreak(WordBreak.BREAK_ALL)
                .padding(16)
            }
            .width('100%')
            .backgroundColor(LightColors.INPUT_BACKGROUND)
            .borderRadius(12)
            .margin({ bottom: 24 })

            Button('Copy Key')
              .fontSize(AppTypography.BODY_MEDIUM)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(LightColors.PRIMARY)
              .fontColor(LightColors.PRIMARY_TEXT)
              .borderRadius(12)
              .width('100%')
              .margin({ bottom: 12 })
              .onClick(() => {
                Logger.info(TAG, 'Copy key to clipboard');
              })

            Button('Continue')
              .fontSize(AppTypography.BODY_LARGE)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(Color.Transparent)
              .fontColor(LightColors.PRIMARY)
              .borderRadius(12)
              .width('100%')
              .border({ width: 1, color: LightColors.PRIMARY })
              .onClick(() => {
                Logger.info(TAG, 'Navigate to sessions (Phase 3)');
              })
          }
          .width('100%')
        }
      }
      .padding({ left: 24, right: 24 })
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(LightColors.BACKGROUND)
  }
}
