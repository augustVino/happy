/**
 * Pick path page - Step 3 of session creation.
 *
 * Allows the user to confirm or enter the working directory for the
 * new AI session, then calls MachineRpc.spawnHappySession() to create it.
 *
 * Note: Phase 3 uses manual directory input. File browsing via
 * SessionRpc.listDirectory() requires an active session, which does not
 * exist yet at this stage. A file browser UI placeholder is included
 * for future enhancement.
 */
import { Logger } from 'common';
import { NavParams } from 'common';
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';
import { MachineRpc } from 'rpc';
import { RpcResult } from 'rpc';
import router from '@ohos.router';

const TAG = 'PickPathPage';
const NAV_BAR_HEIGHT: number = 56;
const NAV_BAR_PADDING_H: number = 8;
const BACK_BUTTON_WIDTH: number = 44;
const SECTION_PADDING_H: number = 24;
const SECTION_TOP_MARGIN: number = 24;
const LABEL_BOTTOM_MARGIN: number = 8;
const INPUT_HEIGHT: number = 48;
const DESCRIPTION_BOTTOM_MARGIN: number = 16;
const BUTTON_HEIGHT: number = 48;
const BUTTON_RADIUS: number = 12;
const BUTTON_PADDING_H: number = 24;
const BUTTON_BOTTOM_MARGIN: number = 24;
const ERROR_TOP_MARGIN: number = 16;
const ERROR_PADDING_H: number = 24;
const LOADING_TOP_MARGIN: number = 16;

@Entry
@Component
export struct PickPathPage {
  @State directory: string = '';
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  private machineId: string = '';
  private profile: string = 'default';
  private prompt: string = '';
  private machineRpc: MachineRpc = MachineRpc.getInstance();

  aboutToAppear(): void {
    Logger.info(TAG, 'PickPathPage aboutToAppear');

    // Read params from router
    const params: NavParams = router.getParams() as NavParams;
    if (params !== null && params !== undefined) {
      if (params.machineId !== '') {
        this.machineId = params.machineId;
      }
      if (params.profile !== '') {
        this.profile = params.profile;
      }
      if (params.directory !== '') {
        this.directory = params.directory;
      }
      if (params.prompt !== '') {
        this.prompt = params.prompt;
      }
    }

    Logger.info(TAG, `Machine: ${this.machineId}, directory: ${this.directory}`);
  }

  build() {
    Column() {
      // Navigation bar
      this.NavBar()

      // Scrollable content
      Scroll() {
        Column() {
          // Directory input section
          this.DirectorySection()

          // File browser placeholder
          this.FileBrowserPlaceholder()

          // Error message
          if (this.errorMessage !== '') {
            Text(this.errorMessage)
              .fontSize(AppTypography.BODY_SMALL)
              .fontColor(LightColors.ERROR)
              .width('100%')
              .padding({ left: ERROR_PADDING_H, right: ERROR_PADDING_H })
              .margin({ top: ERROR_TOP_MARGIN })
          }

          // Loading indicator
          if (this.isLoading) {
            Text('Creating session...')
              .fontSize(AppTypography.BODY_MEDIUM)
              .fontColor(LightColors.TEXT_SECONDARY)
              .margin({ top: LOADING_TOP_MARGIN })
          }

          // Create button
          this.CreateButton()
        }
        .width('100%')
        .padding({ bottom: BUTTON_BOTTOM_MARGIN })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .scrollBarColor(LightColors.DIVIDER)
      .scrollBarWidth(4)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(LightColors.BACKGROUND)
  }

  @Builder NavBar() {
    Row() {
      // Back button
      Button('<')
        .fontSize(AppTypography.BODY_LARGE)
        .fontColor(LightColors.PRIMARY)
        .backgroundColor(Color.Transparent)
        .width(BACK_BUTTON_WIDTH)
        .height(BACK_BUTTON_WIDTH)
        .onClick(() => {
          if (!this.isLoading) {
            router.back();
          }
        })

      // Title
      Text('Working Directory')
        .fontSize(AppTypography.TITLE_SMALL)
        .fontWeight(FontWeight.Medium)
        .fontColor(LightColors.TEXT_PRIMARY)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .padding({ left: 8, right: 8 })

      // Spacer to balance back button
      Row()
        .width(BACK_BUTTON_WIDTH)
        .height(BACK_BUTTON_WIDTH)
    }
    .width('100%')
    .height(NAV_BAR_HEIGHT)
    .padding({ left: NAV_BAR_PADDING_H, right: NAV_BAR_PADDING_H })
    .backgroundColor(LightColors.SURFACE)
    .alignItems(VerticalAlign.Center)
    .shadow({
      radius: 2,
      color: 'rgba(0,0,0,0.05)',
      offsetY: 1
    })
  }

  @Builder DirectorySection() {
    Column() {
      Text('Working Directory')
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .fontColor(LightColors.TEXT_PRIMARY)
        .margin({ bottom: LABEL_BOTTOM_MARGIN })

      Text('Enter the working directory for the AI session')
        .fontSize(AppTypography.BODY_SMALL)
        .fontColor(LightColors.TEXT_SECONDARY)
        .margin({ bottom: DESCRIPTION_BOTTOM_MARGIN })

      TextInput({ text: this.directory, placeholder: '/home/user/project' })
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(LightColors.TEXT_PRIMARY)
        .placeholderColor(LightColors.TEXT_TERTIARY)
        .placeholderFont({ size: AppTypography.BODY_MEDIUM })
        .backgroundColor(LightColors.INPUT_BACKGROUND)
        .borderRadius(8)
        .height(INPUT_HEIGHT)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.directory = value;
          // Clear error when user edits
          if (this.errorMessage !== '') {
            this.errorMessage = '';
          }
        })
    }
    .width('100%')
    .padding({ left: SECTION_PADDING_H, right: SECTION_PADDING_H })
    .margin({ top: SECTION_TOP_MARGIN })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder FileBrowserPlaceholder() {
    Column() {
      Text('Browse Files')
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .fontColor(LightColors.TEXT_PRIMARY)
        .margin({ bottom: LABEL_BOTTOM_MARGIN })

      // Placeholder for future file browser
      Column() {
        Text('File browser coming soon')
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(LightColors.TEXT_TERTIARY)
      }
      .width('100%')
      .height(120)
      .borderRadius(8)
      .backgroundColor(LightColors.INPUT_BACKGROUND)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding({ left: SECTION_PADDING_H, right: SECTION_PADDING_H })
    .margin({ top: SECTION_TOP_MARGIN })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder CreateButton() {
    Button('Create Session')
      .width('100%')
      .height(BUTTON_HEIGHT)
      .fontSize(AppTypography.BODY_LARGE)
      .fontWeight(FontWeight.Medium)
      .backgroundColor(this.directory.trim() !== '' && !this.isLoading
        ? LightColors.PRIMARY
        : LightColors.BORDER)
      .fontColor(this.directory.trim() !== '' && !this.isLoading
        ? LightColors.PRIMARY_TEXT
        : LightColors.TEXT_TERTIARY)
      .borderRadius(BUTTON_RADIUS)
      .margin({ left: BUTTON_PADDING_H, right: BUTTON_PADDING_H, top: 8 })
      .enabled(this.directory.trim() !== '' && !this.isLoading)
      .opacity(this.directory.trim() !== '' && !this.isLoading ? 1.0 : 0.6)
      .onClick(() => {
        this.createSession();
      })
  }

  /**
   * Call MachineRpc to spawn a new session on the selected machine.
   */
  private async createSession(): Promise<void> {
    if (this.directory.trim() === '' || this.machineId === '') {
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    try {
      Logger.info(TAG, `Creating session on ${this.machineId}, dir: ${this.directory}`);

      // Build optional env with custom prompt if provided
      let env: NavParams | undefined = undefined;
      if (this.prompt.trim() !== '') {
        const envObj: NavParams = new NavParams();
        envObj.prompt = this.prompt;
        env = envObj;
      }

      const result: RpcResult = await this.machineRpc.spawnHappySession(
        this.machineId,
        this.directory,
        undefined, // sessionId - let server generate
        this.profile !== 'default' ? this.profile : undefined,
        env
      );

      if (result.ok) {
        Logger.info(TAG, 'Session created successfully');
        this.navigateToChat(result.result);
      } else {
        this.errorMessage = result.error !== '' ? result.error : 'Failed to create session';
        Logger.error(TAG, `Session creation failed: ${this.errorMessage}`);
      }
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      this.errorMessage = 'Failed to create session: ' + errMsg;
      Logger.error(TAG, `Session creation error: ${errMsg}`);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Navigate to ChatPage with the new session ID.
   */
  private navigateToChat(sessionResult: string): void {
    // Parse session ID from result
    let sessionId: string = '';
    try {
      const parsed: NavParams = JSON.parse(sessionResult) as NavParams;
      if (parsed.sessionId !== '' && parsed.sessionId !== undefined && parsed.sessionId !== null) {
        sessionId = parsed.sessionId;
      }
    } catch (_e) {
      // If parsing fails, use raw result as sessionId
      sessionId = sessionResult;
    }

    if (sessionId === '') {
      this.errorMessage = 'Failed to parse session ID from response';
      return;
    }

    Logger.info(TAG, `Navigating to ChatPage, sessionId: ${sessionId}`);
    const navParams: NavParams = new NavParams();
    navParams.sessionId = sessionId;
    router.replaceUrl({
      url: 'pages/ChatPage',
      params: navParams
    });
  }
}
