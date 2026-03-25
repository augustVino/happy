/**
 * Sessions page - Main app view showing session list and machine list.
 * Uses Navigation as root container with title bar, LazyForEach session list,
 * and optional machine panel.
 */
import { Session, Machine } from 'common';
import { Logger } from 'common';
import { NavParams } from 'common';
import { AppStateKeys } from 'common';
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';
import { AppViewModel } from '../viewmodels/AppViewModel';
import { SessionDataSource } from '../datasource/SessionDataSource';
import { SessionItem } from '../components/SessionItem';
import { MachineList } from '../components/MachineList';
import { LoadingIndicator } from '../components/LoadingIndicator';
import { EmptyStateView } from '../components/EmptyStateView';
import { AuthService } from 'auth';
import router from '@ohos.router';

const TAG = 'SessionsPage';
const TITLE_PADDING: number = 16;
const MACHINE_PANEL_TOP_MARGIN: number = 8;
const MACHINE_PANEL_BOTTOM_MARGIN: number = 16;
const LIST_PADDING: number = 8;
const NEW_SESSION_BUTTON_SIZE: number = 36;
const INIT_TIMEOUT_MS: number = 20000;

@Entry
@Component
export struct SessionsPage {
  private appViewModel: AppViewModel = AppViewModel.getInstance();
  private sessionDataSource: SessionDataSource = new SessionDataSource();
  @State showMachines: boolean = false;
  @State hasSessions: boolean = false;
  @State initError: string = '';
  @State dataReady: boolean = false;
  private initStarted: boolean = false;

  async aboutToAppear(): Promise<void> {
    Logger.info(TAG, 'SessionsPage aboutToAppear');

    if (!this.initStarted) {
      this.initStarted = true;
      const token: string | undefined = AppStorage.get<string>(AppStateKeys.JWT_TOKEN);
      if (token !== undefined && token !== null && token !== '') {
        try {
          const ok: boolean = await this.withTimeout(this.appViewModel.initialize(token), INIT_TIMEOUT_MS);
          if (!ok) {
            this.initError = this.appViewModel.errorMessage !== ''
              ? this.appViewModel.errorMessage
              : 'Initialization failed';
          }
        } catch (e) {
          const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
          this.initError = 'Timeout or error: ' + errMsg;
          Logger.error(TAG, 'Init error: ' + errMsg);
        }
      }
      this.dataReady = this.appViewModel.isDataReady;
      this.syncSessionsToDataSource();
    }
  }

  /**
   * Wrap a promise with a timeout to avoid hanging forever.
   */
  private async withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
    return new Promise<T>((resolve: (value: T) => void, reject: (reason: Error) => void) => {
      const timer = setTimeout(() => {
        reject(new Error('Operation timed out after ' + ms + 'ms'));
      }, ms);
      promise.then((value: T) => {
        clearTimeout(timer);
        resolve(value);
      }).catch((err: Error) => {
        clearTimeout(timer);
        reject(err);
      });
    });
  }

  /**
   * Logout and navigate back to Index page.
   */
  async onLogout(): Promise<void> {
    Logger.info(TAG, 'Logout requested');
    this.appViewModel.dispose();
    const authService: AuthService = AuthService.getInstance();
    await authService.logout();
    router.replaceUrl({ url: 'pages/Index' });
  }

  /**
   * Sync AppViewModel sessions to the LazyForEach data source.
   */
  syncSessionsToDataSource(): void {
    this.sessionDataSource.updateData(this.appViewModel.sessions);
    this.hasSessions = this.appViewModel.sessions.length > 0;
  }

  /**
   * Handle session item tap: set active session and navigate to chat.
   */
  onSessionClicked(session: Session): void {
    Logger.info(TAG, 'Session clicked: ' + session.id);
    this.appViewModel.setActiveSession(session.id);
    const params: NavParams = new NavParams();
    params.sessionId = session.id;
    router.pushUrl({ url: 'pages/ChatPage', params: params });
  }

  /**
   * Handle new session button tap.
   */
  onNewSession(): void {
    Logger.info(TAG, 'New session requested');
    router.pushUrl({ url: 'pages/NewSessionPage' });
  }

  /**
   * Handle machine selection.
   */
  onMachineSelected(machine: Machine): void {
    Logger.info(TAG, 'Machine selected: ' + machine.id);
  }

  build() {
    Column() {
      // Top title bar
      Row() {
        Text('Sessions')
          .fontSize(AppTypography.TITLE_LARGE)
          .fontWeight(FontWeight.Bold)
          .fontColor(LightColors.TEXT_PRIMARY)
          .layoutWeight(1)

        // Logout button (always visible for debugging)
        Button() {
          Text('Logout')
            .fontSize(AppTypography.BODY_SMALL)
            .fontColor(LightColors.TEXT_SECONDARY)
        }
        .type(ButtonType.Capsule)
        .backgroundColor(Color.Transparent)
        .height(NEW_SESSION_BUTTON_SIZE)
        .padding({ left: 12, right: 12 })
        .margin({ right: 8 })
        .onClick(() => {
          this.onLogout();
        })

        // Machine toggle button
        Button() {
          Text('Machines')
            .fontSize(AppTypography.BODY_SMALL)
            .fontColor(this.showMachines ? LightColors.PRIMARY : LightColors.TEXT_SECONDARY)
        }
        .type(ButtonType.Capsule)
        .backgroundColor(this.showMachines ? LightColors.NAV_BAR : Color.Transparent)
        .height(NEW_SESSION_BUTTON_SIZE)
        .padding({ left: 12, right: 12 })
        .margin({ right: 8 })
        .onClick(() => {
          this.showMachines = !this.showMachines;
        })

        // New session button
        Button() {
          Text('+')
            .fontSize(AppTypography.TITLE_MEDIUM)
            .fontColor(LightColors.PRIMARY_TEXT)
        }
        .type(ButtonType.Circle)
        .width(NEW_SESSION_BUTTON_SIZE)
        .height(NEW_SESSION_BUTTON_SIZE)
        .backgroundColor(LightColors.PRIMARY)
        .onClick(() => {
          this.onNewSession();
        })
      }
      .width('100%')
      .padding({ left: TITLE_PADDING, right: TITLE_PADDING, top: TITLE_PADDING })
      .alignItems(VerticalAlign.Center)

      // Machine list panel (collapsible)
      if (this.showMachines) {
        Column() {
          MachineList({
            machines: this.appViewModel.machines,
            selectedMachineId: '',
            onMachineSelected: (machine: Machine): void => {
              this.onMachineSelected(machine);
            }
          })
        }
        .width('100%')
        .padding({ top: MACHINE_PANEL_TOP_MARGIN, bottom: MACHINE_PANEL_BOTTOM_MARGIN })
        .animation({ duration: 200, curve: Curve.EaseInOut })
      }

      // Content area - uses local @State for reliable reactivity
      if (!this.dataReady) {
        if (this.initError !== '') {
          Column() {
            Text('Initialization Failed')
              .fontSize(AppTypography.TITLE_MEDIUM)
              .fontWeight(FontWeight.Bold)
              .fontColor(LightColors.ERROR)
              .margin({ bottom: 12 })

            Text(this.initError)
              .fontSize(AppTypography.BODY_SMALL)
              .fontColor(LightColors.TEXT_SECONDARY)
              .margin({ bottom: 24 })
              .padding({ left: 24, right: 24 })
              .wordBreak(WordBreak.BREAK_ALL)

            Button('Logout & Retry')
              .fontSize(AppTypography.BODY_MEDIUM)
              .fontColor(LightColors.ERROR)
              .backgroundColor(Color.Transparent)
              .borderRadius(12)
              .width('60%')
              .onClick(() => {
                this.onLogout();
              })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(LightColors.BACKGROUND)
        } else {
          LoadingIndicator({ message: 'Loading sessions...' })
        }
      } else if (!this.hasSessions) {
        EmptyStateView({
          title: 'No Sessions',
          description: 'Create a new session to get started'
        })
      } else {
        List({ space: LIST_PADDING }) {
          LazyForEach(this.sessionDataSource, (session: Session): void => {
            ListItem() {
              SessionItem({
                session: session,
                isActive: session.id === this.appViewModel.activeSessionId
              })
            }
            .onClick(() => {
              this.onSessionClicked(session);
            })
          }, (session: Session): string => {
            return session.id;
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: LIST_PADDING, right: LIST_PADDING })
        .scrollBar(BarState.Auto)
        .cachedCount(5)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(LightColors.BACKGROUND)
  }
}
