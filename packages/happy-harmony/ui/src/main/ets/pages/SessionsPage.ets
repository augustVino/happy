/**
 * Sessions page - Main app view showing session list and machine list.
 * Uses Navigation as root container with title bar, LazyForEach session list,
 * and optional machine panel.
 */
import { Session, Machine } from 'common';
import { Logger } from 'common';
import { NavParams } from 'common';
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';
import { AppViewModel } from '../viewmodels/AppViewModel';
import { SessionDataSource } from '../datasource/SessionDataSource';
import { SessionItem } from '../components/SessionItem';
import { MachineList } from '../components/MachineList';
import { LoadingIndicator } from '../components/LoadingIndicator';
import { EmptyStateView } from '../components/EmptyStateView';
import router from '@ohos.router';

const TAG = 'SessionsPage';
const TITLE_PADDING: number = 16;
const MACHINE_PANEL_TOP_MARGIN: number = 8;
const MACHINE_PANEL_BOTTOM_MARGIN: number = 16;
const LIST_PADDING: number = 8;
const NEW_SESSION_BUTTON_SIZE: number = 36;

@Entry
@Component
export struct SessionsPage {
  private appViewModel: AppViewModel = AppViewModel.getInstance();
  private sessionDataSource: SessionDataSource = new SessionDataSource();
  @State showMachines: boolean = false;
  @State hasSessions: boolean = false;

  aboutToAppear(): void {
    Logger.info(TAG, 'SessionsPage aboutToAppear');
    this.syncSessionsToDataSource();
  }

  /**
   * Sync AppViewModel sessions to the LazyForEach data source.
   * Call this whenever AppViewModel sessions change (e.g., after WebSocket push).
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

      // Content area
      if (!this.appViewModel.isDataReady) {
        LoadingIndicator({ message: 'Loading sessions...' })
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
