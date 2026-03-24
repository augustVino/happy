/**
 * Restore page - Restore an existing account via QR code or manual key.
 */
import { AuthService } from 'auth';
import { AuthResult } from 'auth';
import { KeyManager } from 'auth';
import { QRAuthKeyPair } from 'common';
import { RestoreMethod } from 'common';
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';
import { Base64Utils } from 'common';
import { Logger } from 'common';
import { QrCodeView } from '../components/QrCodeView';
import router from '@ohos.router';

const TAG = 'RestorePage';

@Component
export struct RestorePage {
  @State restoreMethod: RestoreMethod = RestoreMethod.QR_CODE;
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State statusMessage: string = '';
  @State qrKeyPair: QRAuthKeyPair | null = null;
  @State qrData: string = '';
  @State showQrView: boolean = false;
  @State pollingDots: number = 0;
  @State manualKeyInput: string = '';
  @State restoreSuccess: boolean = false;
  private cancelPolling: boolean = false;

  aboutToAppear(): void {
    Logger.info(TAG, 'RestorePage appeared');
  }

  aboutToDisappear(): void {
    this.cancelPolling = true;
  }

  async startQRRestore(): Promise<void> {
    if (this.isLoading) {
      return;
    }
    this.isLoading = true;
    this.errorMessage = '';
    this.statusMessage = 'Registering with server...';

    try {
      const authService: AuthService = AuthService.getInstance();
      const keypair: QRAuthKeyPair | null = await authService.startQRRestore();

      if (keypair === null) {
        this.errorMessage = 'Failed to register with server. Please try again.';
        this.isLoading = false;
        return;
      }

      this.qrKeyPair = keypair;
      // Generate QR data: happy:///account?{base64url(publicKey)}
      const publicKeyBase64Url: string = Base64Utils.encodeBase64Url(keypair.publicKey);
      this.qrData = 'happy:///account?' + publicKeyBase64Url;
      this.statusMessage = 'Waiting for authorization' + this.getDotsString(0);

      // Delay QrCodeView rendering to the next frame so the Web component
      // mounts in a clean state (avoids crash from loadData before attachment).
      setTimeout(() => {
        this.showQrView = true;
      }, 100);

      // Start polling in background
      this.pollForAuthorization(keypair);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      this.errorMessage = errMsg;
      this.isLoading = false;
    }
  }

  async pollForAuthorization(keypair: QRAuthKeyPair): Promise<void> {
    const authService: AuthService = AuthService.getInstance();
    const result: AuthResult = await authService.pollQRRestore(
      keypair,
      (dots: number) => {
        this.pollingDots = dots;
        this.statusMessage = 'Waiting for authorization' + this.getDotsString(dots);
      },
      () => {
        return this.cancelPolling;
      }
    );

    if (result.success) {
      this.restoreSuccess = true;
      this.statusMessage = '';
    } else {
      this.errorMessage = result.errorMessage || 'Restore failed';
      this.isLoading = false;
    }
  }

  async restoreWithKey(): Promise<void> {
    if (this.isLoading || this.manualKeyInput.trim() === '') {
      return;
    }
    this.isLoading = true;
    this.errorMessage = '';

    try {
      const authService: AuthService = AuthService.getInstance();
      const result: AuthResult = await authService.restoreWithKey(this.manualKeyInput.trim());

      if (result.success) {
        this.restoreSuccess = true;
      } else {
        this.errorMessage = result.errorMessage || 'Invalid key';
      }
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      this.errorMessage = errMsg;
    } finally {
      this.isLoading = false;
    }
  }

  cancelRestore(): void {
    this.cancelPolling = true;
    this.isLoading = false;
    this.qrKeyPair = null;
    this.statusMessage = '';
    this.pollingDots = 0;
  }

  private getDotsString(count: number): string {
    const n: number = count % 4;
    let dots: string = '';
    for (let i: number = 0; i < n; i++) {
      dots = dots + '.';
    }
    return dots;
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
            if (this.isLoading) {
              this.cancelRestore();
            } else {
              // Pop back
            }
          })
      }
      .width('100%')
      .padding({ left: 16, top: 16 })
      .justifyContent(FlexAlign.Start)

      if (this.restoreSuccess) {
        // Success state
        Column() {
          Text('Account Restored!')
            .fontSize(AppTypography.TITLE_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(LightColors.SUCCESS)
            .margin({ bottom: 24 })

          Text('Your account has been successfully restored on this device.')
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(LightColors.TEXT_SECONDARY)
            .margin({ bottom: 32 })

          Button('Continue')
            .fontSize(AppTypography.BODY_LARGE)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(LightColors.PRIMARY)
            .fontColor(LightColors.PRIMARY_TEXT)
            .borderRadius(12)
            .width('80%')
            .onClick(() => {
              router.replaceUrl({ url: 'pages/SessionsPage' });
            })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.restoreMethod === RestoreMethod.QR_CODE) {
        // QR restore
        Column() {
          Text('Restore Account')
            .fontSize(AppTypography.TITLE_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(LightColors.TEXT_PRIMARY)
            .margin({ bottom: 12 })

          Text('Scan the QR code below with your existing device to authorize this new device.')
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(LightColors.TEXT_SECONDARY)
            .margin({ bottom: 24 })

          if (this.qrKeyPair === null && !this.isLoading) {
            // Initial state - show start button
            Button('Start QR Restore')
              .fontSize(AppTypography.BODY_LARGE)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(LightColors.PRIMARY)
              .fontColor(LightColors.PRIMARY_TEXT)
              .borderRadius(12)
              .width('80%')
              .onClick(() => {
                this.startQRRestore();
              })
          } else if (this.qrKeyPair !== null && this.showQrView) {
            // Show QR code (rendered only after showQrView is set via setTimeout)
            QrCodeView({ data: this.qrData, qrCodeSize: 240 })

            if (this.statusMessage !== '') {
              Text(this.statusMessage)
                .fontSize(AppTypography.BODY_MEDIUM)
                .fontColor(LightColors.TEXT_SECONDARY)
                .margin({ top: 16 })
            }

            Button('Cancel')
              .fontSize(AppTypography.BODY_MEDIUM)
              .fontColor(LightColors.ERROR)
              .backgroundColor(Color.Transparent)
              .margin({ top: 24 })
              .onClick(() => {
                this.cancelRestore();
              })
          }

          // Switch to manual key
          Button('Enter Key Manually')
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(LightColors.PRIMARY)
            .backgroundColor(Color.Transparent)
            .margin({ top: 32 })
            .onClick(() => {
              this.restoreMethod = RestoreMethod.MANUAL_KEY;
            })

          if (this.errorMessage !== '') {
            Text(this.errorMessage)
              .fontSize(AppTypography.BODY_SMALL)
              .fontColor(LightColors.ERROR)
              .margin({ top: 16 })
              .padding({ left: 24, right: 24 })
          }
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Start)
        .padding({ left: 24, right: 24 })
      } else {
        // Manual key restore
        Column() {
          Text('Enter Recovery Key')
            .fontSize(AppTypography.TITLE_LARGE)
            .fontWeight(FontWeight.Bold)
            .fontColor(LightColors.TEXT_PRIMARY)
            .margin({ bottom: 12 })

          Text('Enter your recovery key (Base32 format, e.g. ABCDE-FGHIJ-KLMNO-PQRST-U-VWXY-Z)')
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(LightColors.TEXT_SECONDARY)
            .margin({ bottom: 24 })

          TextInput({ placeholder: 'ABCDE-FGHIJ-...', text: this.manualKeyInput })
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(LightColors.TEXT_PRIMARY)
            .backgroundColor(LightColors.INPUT_BACKGROUND)
            .borderRadius(12)
            .padding(16)
            .onChange((value: string) => {
              this.manualKeyInput = value.toUpperCase();
            })

          Button(this.isLoading ? 'Restoring...' : 'Restore')
            .fontSize(AppTypography.BODY_LARGE)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.isLoading ? LightColors.TEXT_TERTIARY : LightColors.PRIMARY)
            .fontColor(LightColors.PRIMARY_TEXT)
            .borderRadius(12)
            .width('100%')
            .margin({ top: 24 })
            .enabled(!this.isLoading && this.manualKeyInput.trim() !== '')
            .onClick(() => {
              this.restoreWithKey();
            })

          // Switch to QR
          Button('Scan QR Code Instead')
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(LightColors.PRIMARY)
            .backgroundColor(Color.Transparent)
            .margin({ top: 16 })
            .onClick(() => {
              this.restoreMethod = RestoreMethod.QR_CODE;
            })

          if (this.errorMessage !== '') {
            Text(this.errorMessage)
              .fontSize(AppTypography.BODY_SMALL)
              .fontColor(LightColors.ERROR)
              .margin({ top: 16 })
          }
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Start)
        .padding({ left: 24, right: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(LightColors.BACKGROUND)
  }
}
