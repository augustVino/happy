/**
 * Chat page.
 * Displays messages for a session with input, thinking indicator,
 * and navigation bar. Gets sessionId from router parameters.
 */
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';
import { SessionMessage } from 'common';
import { Logger } from 'common';
import { NavParams } from 'common';
import { SessionViewModel } from '../viewmodels/SessionViewModel';
import { AppViewModel } from '../viewmodels/AppViewModel';
import { MessageList } from '../components/MessageList';
import { ThinkingIndicator } from '../components/ThinkingIndicator';
import { AgentInput, AgentInputCallback } from '../components/AgentInput';
import { LoadingIndicator } from '../components/LoadingIndicator';
import router from '@ohos.router';

const TAG = 'ChatPage';
const NAV_BAR_HEIGHT: number = 56;
const NAV_BAR_PADDING_H: number = 8;
const NAV_TITLE_SIZE: number = 17;
const THINKING_ROW_PADDING_H: number = 16;
const THINKING_ROW_PADDING_V: number = 4;
const BACK_BUTTON_WIDTH: number = 44;
const MENU_BUTTON_WIDTH: number = 44;
const EMPTY_STATE_TOP: number = 100;

@Entry
@Component
export struct ChatPage {
  @State sessionId: string = '';
  @State isLoading: boolean = true;
  @State messages: SessionMessage[] = [];
  @State isThinking: boolean = false;
  @State sessionTitle: string = '';
  @State loadError: string = '';
  private sessionViewModel: SessionViewModel | null = null;
  private appViewModel: AppViewModel = AppViewModel.getInstance();
  private sendCallback: AgentInputCallback = new AgentInputCallback();

  aboutToAppear(): void {
    // Read sessionId from router params
    const params: NavParams = router.getParams() as NavParams;
    if (params !== null && params !== undefined && params.sessionId !== '') {
      this.sessionId = params.sessionId;
    }

    // Set up send callback
    this.sendCallback.onSend = (text: string) => {
      this.handleSend(text);
    };

    if (this.sessionId === '') {
      this.loadError = 'No session ID provided';
      this.isLoading = false;
      return;
    }

    this.loadSession();
  }

  aboutToDisappear(): void {
    this.sessionViewModel = null;
  }

  build() {
    Column() {
      // Navigation bar
      this.NavBar()

      if (this.isLoading) {
        // Loading state
        Column() {
          LoadingIndicator({ message: 'Loading messages...' })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadError !== '') {
        // Error state
        Column() {
          Text(this.loadError)
            .fontSize(AppTypography.BODY_MEDIUM)
            .fontColor(LightColors.ERROR)
            .textAlign(TextAlign.Center)
            .padding({ left: 32, right: 32 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        // Main content
        Column() {
          // Message list
          if (this.messages.length === 0) {
            this.EmptyChatState()
          } else {
            MessageList({ messages: this.messages })
          }

          // Thinking indicator
          if (this.isThinking) {
            Row() {
              ThinkingIndicator({ isThinking: true })
              Text('Thinking...')
                .fontSize(AppTypography.BODY_SMALL)
                .fontColor(LightColors.TEXT_SECONDARY)
                .margin({ left: 8 })
            }
            .padding({
              left: THINKING_ROW_PADDING_H,
              right: THINKING_ROW_PADDING_H,
              top: THINKING_ROW_PADDING_V,
              bottom: THINKING_ROW_PADDING_V
            })
            .alignItems(VerticalAlign.Center)
          }

          // Input area
          AgentInput({
            isThinking: this.isThinking,
            sendCallback: this.sendCallback
          })
        }
        .layoutWeight(1)
      }
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
          router.back();
        })

      // Title
      Text(this.sessionTitle !== '' ? this.sessionTitle : 'Chat')
        .fontSize(NAV_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(LightColors.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .padding({ left: 8, right: 8 })

      // Menu button placeholder
      Button('...')
        .fontSize(AppTypography.BODY_LARGE)
        .fontColor(LightColors.PRIMARY)
        .backgroundColor(Color.Transparent)
        .width(MENU_BUTTON_WIDTH)
        .height(MENU_BUTTON_WIDTH)
        .onClick(() => {
          // TODO: Open session menu (rename, delete, etc.)
          Logger.info(TAG, 'Menu button tapped');
        })
    }
    .width('100%')
    .height(NAV_BAR_HEIGHT)
    .padding({ left: NAV_BAR_PADDING_H, right: NAV_BAR_PADDING_H })
    .backgroundColor(LightColors.SURFACE)
    .alignItems(VerticalAlign.Center)
    .borderRadius({ bottomLeft: 0, bottomRight: 0 })
    .shadow({
      radius: 2,
      color: 'rgba(0,0,0,0.05)',
      offsetY: 1
    })
  }

  @Builder EmptyChatState() {
    Column() {
      Text('No messages yet')
        .fontSize(AppTypography.TITLE_SMALL)
        .fontColor(LightColors.TEXT_SECONDARY)
        .margin({ bottom: 8 })

      Text('Send a message to start the conversation')
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(LightColors.TEXT_TERTIARY)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Start)
    .padding({ top: EMPTY_STATE_TOP })
  }

  private async loadSession(): Promise<void> {
    if (this.sessionId === '') {
      return;
    }

    this.isLoading = true;
    this.loadError = '';

    try {
      // Resolve session title from AppViewModel
      const session = this.appViewModel.getActiveSession();
      if (session !== null && session.id === this.sessionId) {
        this.sessionTitle = session.decryptedTitle;
      } else {
        // Search all sessions
        this.resolveTitleFromSessions();
      }

      // Create SessionViewModel and load messages
      this.sessionViewModel = new SessionViewModel(this.sessionId);
      await this.sessionViewModel.loadMessages();

      this.messages = this.sessionViewModel.messages;
      this.isThinking = this.sessionViewModel.isThinking;
      this.isLoading = false;

      Logger.info(TAG, `Session loaded: ${this.messages.length} messages`);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      this.loadError = 'Failed to load session: ' + errMsg;
      this.isLoading = false;
      Logger.error(TAG, `Load session failed: ${errMsg}`);
    }
  }

  private resolveTitleFromSessions(): void {
    const sessions = this.appViewModel.sessions;
    for (let i = 0; i < sessions.length; i++) {
      if (sessions[i].id === this.sessionId) {
        this.sessionTitle = sessions[i].decryptedTitle;
        return;
      }
    }
    this.sessionTitle = 'Chat';
  }

  private async handleSend(text: string): Promise<void> {
    if (this.sessionViewModel === null || text.trim() === '') {
      return;
    }

    try {
      await this.sessionViewModel.sendMessage(text);
      // Refresh local state from ViewModel
      this.messages = this.sessionViewModel.messages;
      this.isThinking = this.sessionViewModel.isThinking;
      Logger.info(TAG, 'Message sent successfully');
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, `Send message failed: ${errMsg}`);
    }
  }
}
