/**
 * Pick machine page - Step 2 of session creation.
 *
 * Displays online machines from AppViewModel for the user to select.
 * On selection, navigates to PickPathPage to choose working directory
 * or confirm session creation.
 */
import { Machine } from 'common';
import { Logger } from 'common';
import { NavParams } from 'common';
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';
import { AppViewModel } from '../viewmodels/AppViewModel';
import { MachineCard } from '../components/MachineCard';
import { LoadingIndicator } from '../components/LoadingIndicator';
import { EmptyStateView } from '../components/EmptyStateView';
import router from '@ohos.router';

const TAG = 'PickMachinePage';
const NAV_BAR_HEIGHT: number = 56;
const NAV_BAR_PADDING_H: number = 8;
const BACK_BUTTON_WIDTH: number = 44;
const LIST_PADDING_H: number = 16;
const LIST_PADDING_V: number = 8;
const LIST_ITEM_MARGIN_BOTTOM: number = 8;
const BUTTON_HEIGHT: number = 48;
const BUTTON_RADIUS: number = 12;
const BUTTON_PADDING_H: number = 24;
const BUTTON_BOTTOM_MARGIN: number = 24;

@Entry
@Component
export struct PickMachinePage {
  @State machines: Machine[] = [];
  @State selectedMachineId: string = '';
  @State isLoading: boolean = true;
  private appViewModel: AppViewModel = AppViewModel.getInstance();
  private profile: string = 'default';
  private directory: string = '';
  private prompt: string = '';

  aboutToAppear(): void {
    Logger.info(TAG, 'PickMachinePage aboutToAppear');

    // Read params from router
    const params: NavParams = router.getParams() as NavParams;
    if (params !== null && params !== undefined) {
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

    // Load online machines
    this.machines = this.appViewModel.getOnlineMachines();
    this.isLoading = false;

    Logger.info(TAG, `Loaded ${this.machines.length} online machines`);
  }

  build() {
    Column() {
      // Navigation bar
      this.NavBar()

      // Content area
      if (this.isLoading) {
        Column() {
          LoadingIndicator({ message: 'Loading machines...' })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.machines.length === 0) {
        EmptyStateView({
          title: 'No Machines Online',
          description: 'Make sure the Happy daemon is running on your machine'
        })
      } else {
        // Machine list
        List({ space: LIST_ITEM_MARGIN_BOTTOM }) {
          ForEach(this.machines, (machine: Machine) => {
            ListItem() {
              MachineCard({
                machine: machine,
                isSelected: machine.id === this.selectedMachineId
              })
            }
            .onClick(() => {
              this.selectedMachineId = machine.id;
              Logger.info(TAG, `Machine selected: ${machine.id}`);
            })
          }, (machine: Machine) => machine.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: LIST_PADDING_H, right: LIST_PADDING_H, top: LIST_PADDING_V })
        .scrollBar(BarState.Auto)
        .cachedCount(5)
      }

      // Confirm button
      Button('Select Directory')
        .width('100%')
        .height(BUTTON_HEIGHT)
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.selectedMachineId !== '' ? LightColors.PRIMARY : LightColors.BORDER)
        .fontColor(this.selectedMachineId !== '' ? LightColors.PRIMARY_TEXT : LightColors.TEXT_TERTIARY)
        .borderRadius(BUTTON_RADIUS)
        .margin({ left: BUTTON_PADDING_H, right: BUTTON_PADDING_H, bottom: BUTTON_BOTTOM_MARGIN })
        .enabled(this.selectedMachineId !== '')
        .opacity(this.selectedMachineId !== '' ? 1.0 : 0.6)
        .onClick(() => {
          this.navigateToPickPath();
        })
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
      Text('Select Machine')
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

  /**
   * Navigate to PickPathPage with all accumulated session params.
   */
  private navigateToPickPath(): void {
    Logger.info(TAG, `Navigating to PickPathPage, machine: ${this.selectedMachineId}`);
    const params: NavParams = new NavParams();
    params.machineId = this.selectedMachineId;
    params.profile = this.profile;
    params.directory = this.directory;
    params.prompt = this.prompt;
    router.pushUrl({ url: 'pages/PickPathPage', params: params });
  }
}
