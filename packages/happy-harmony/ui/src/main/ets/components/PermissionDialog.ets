/**
 * PermissionDialog - Permission approval dialog for agent tool calls.
 *
 * Displays tool name, description, parameter summary, and approval mode
 * selector. User can approve or deny the permission request.
 *
 * Uses callback class pattern to work around ArkTS function-prop restriction.
 * Uses @CustomDialog with CustomDialogController for modal behavior.
 */
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';

const TAG = 'PermissionDialog';

// Layout constants
const DIALOG_PADDING: number = 24;
const SECTION_BOTTOM_MARGIN: number = 16;
const TOOL_NAME_BOTTOM_MARGIN: number = 8;
const BUTTON_HEIGHT: number = 44;
const BUTTON_SPACING: number = 12;
const PARAM_BLOCK_PADDING: number = 12;
const PARAM_BORDER_RADIUS: number = 8;
const MODE_ITEM_HEIGHT: number = 44;
const MODE_ITEM_PADDING_H: number = 16;
const DIALOG_BORDER_RADIUS: number = 16;
const WARNING_BADGE_SIZE: number = 20;

/** Permission request data pushed from server. */
export class PermissionRequest {
  id: string = '';
  sessionId: string = '';
  toolName: string = '';
  title: string = '';
  description: string = '';
  args: string = '';
}

/** Callback class for permission dialog actions. */
export class PermissionDialogCallback {
  onApprove: (requestId: string, mode: string) => void = () => {};
  onDeny: (requestId: string) => void = () => {};
  onDismiss: () => void = () => {};
}

/** Approval mode option definition. */
class ApprovalMode {
  key: string = '';
  label: string = '';
  description: string = '';
  isRisky: boolean = false;
}

/** Create an ApprovalMode instance. */
function createApprovalMode(key: string, label: string, description: string, isRisky: boolean): ApprovalMode {
  const mode: ApprovalMode = new ApprovalMode();
  mode.key = key;
  mode.label = label;
  mode.description = description;
  mode.isRisky = isRisky;
  return mode;
}

/** Predefined approval modes. */
class ApprovalModes {
  static readonly DEFAULT: ApprovalMode = createApprovalMode('default', 'Default', 'Approve this request only', false);
  static readonly ACCEPT_EDITS: ApprovalMode = createApprovalMode('acceptEdits', 'Accept Edits', 'Auto-approve file edits', false);
  static readonly PLAN: ApprovalMode = createApprovalMode('plan', 'Plan Mode', 'Agent plans without executing', false);
  static readonly READ_ONLY: ApprovalMode = createApprovalMode('read-only', 'Read Only', 'Agent can only read files', false);
  static readonly BYPASS_PERMISSIONS: ApprovalMode = createApprovalMode('bypassPermissions', 'Bypass Permissions', 'Skip all permission checks', true);
  static readonly SAFE_YOLO: ApprovalMode = createApprovalMode('safe-yolo', 'Safe Auto', 'Auto-approve safe operations', true);
  static readonly YOLO: ApprovalMode = createApprovalMode('yolo', 'Full Auto', 'Auto-approve all operations', true);

  static getAll(): ApprovalMode[] {
    return [
      ApprovalModes.DEFAULT,
      ApprovalModes.ACCEPT_EDITS,
      ApprovalModes.PLAN,
      ApprovalModes.READ_ONLY,
      ApprovalModes.BYPASS_PERMISSIONS,
      ApprovalModes.SAFE_YOLO,
      ApprovalModes.YOLO,
    ];
  }
}

@CustomDialog
export struct PermissionDialog {
  controller: CustomDialogController;
  @State request: PermissionRequest = new PermissionRequest();
  @State selectedMode: string = 'default';
  @State argsExpanded: boolean = false;
  private callback: PermissionDialogCallback = new PermissionDialogCallback();
  private modeOptions: ApprovalMode[] = ApprovalModes.getAll();

  aboutToAppear(): void {
    // Reset state when dialog appears
    this.selectedMode = 'default';
    this.argsExpanded = false;
  }

  build() {
    Column() {
      // Header row with warning icon and title
      Row({ space: 8 }) {
        // Warning badge
        Column() {
          Text('!')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(WARNING_BADGE_SIZE)
        .height(WARNING_BADGE_SIZE)
        .borderRadius(WARNING_BADGE_SIZE / 2)
        .backgroundColor(LightColors.WARNING)
        .justifyContent(FlexAlign.Center)

        Text('Permission Required')
          .fontSize(AppTypography.TITLE_SMALL)
          .fontWeight(FontWeight.Bold)
          .fontColor(LightColors.TEXT_PRIMARY)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: SECTION_BOTTOM_MARGIN })

      // Tool name
      Text(this.request.toolName)
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .fontColor(LightColors.PRIMARY)
        .margin({ bottom: TOOL_NAME_BOTTOM_MARGIN })

      // Description
      if (this.request.description !== '') {
        Text(this.request.description)
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(LightColors.TEXT_SECONDARY)
          .margin({ bottom: SECTION_BOTTOM_MARGIN })
      }

      // Parameters section (collapsible)
      if (this.request.args !== '') {
        Column() {
          // Parameters header row
          Row() {
            Text('Parameters')
              .fontSize(AppTypography.CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(LightColors.TEXT_TERTIARY)
              .layoutWeight(1)

            Text(this.argsExpanded ? 'Hide' : 'Show')
              .fontSize(AppTypography.CAPTION)
              .fontColor(LightColors.PRIMARY)
              .onClick(() => {
                this.argsExpanded = !this.argsExpanded;
              })
          }
          .width('100%')
          .margin({ bottom: 6 })

          if (this.argsExpanded) {
            Text(this.request.args)
              .fontSize(AppTypography.CAPTION)
              .fontColor(LightColors.TEXT_SECONDARY)
              .maxLines(8)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          } else {
            Text(this.request.args)
              .fontSize(AppTypography.CAPTION)
              .fontColor(LightColors.TEXT_SECONDARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
        }
        .width('100%')
        .padding(PARAM_BLOCK_PADDING)
        .backgroundColor(LightColors.INPUT_BACKGROUND)
        .borderRadius(PARAM_BORDER_RADIUS)
        .margin({ bottom: SECTION_BOTTOM_MARGIN })
        .onClick(() => {
          this.argsExpanded = !this.argsExpanded;
        })
      }

      // Mode selector section
      Column() {
        Text('Approval Mode')
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontWeight(FontWeight.Medium)
          .fontColor(LightColors.TEXT_PRIMARY)
          .margin({ bottom: 8 })

        // Mode options list
        List({ space: 4 }) {
          ForEach(this.modeOptions, (mode: ApprovalMode) => {
            ListItem() {
              Row({ space: 8 }) {
                // Radio indicator
                Column() {
                  if (this.selectedMode === mode.key) {
                    Column()
                      .width(16)
                      .height(16)
                      .borderRadius(8)
                      .backgroundColor(LightColors.PRIMARY)
                  } else {
                    Column()
                      .width(16)
                      .height(16)
                      .borderRadius(8)
                      .border({ width: 1.5, color: LightColors.BORDER })
                  }
                }
                .width(24)
                .height(24)
                .justifyContent(FlexAlign.Center)

                // Mode label and description
                Column({ space: 2 }) {
                  Row({ space: 4 }) {
                    Text(mode.label)
                      .fontSize(AppTypography.BODY_MEDIUM)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(LightColors.TEXT_PRIMARY)

                    if (mode.isRisky) {
                      Text('Risky')
                        .fontSize(9)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(LightColors.WARNING)
                        .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                        .backgroundColor('#FFF3E0')
                        .borderRadius(3)
                    }
                  }
                  Text(mode.description)
                    .fontSize(AppTypography.CAPTION)
                    .fontColor(LightColors.TEXT_TERTIARY)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .height(MODE_ITEM_HEIGHT)
              .padding({ left: MODE_ITEM_PADDING_H, right: MODE_ITEM_PADDING_H })
              .borderRadius(8)
              .backgroundColor(this.selectedMode === mode.key ? '#E8F0FE' : Color.Transparent)
              .onClick(() => {
                this.selectedMode = mode.key;
              })
            }
          }, (mode: ApprovalMode) => mode.key)
        }
        .width('100%')
        .divider({ strokeWidth: 0, color: Color.Transparent })
      }
      .width('100%')
      .margin({ bottom: SECTION_BOTTOM_MARGIN + 8 })

      // Button row
      Row({ space: BUTTON_SPACING }) {
        // Deny button
        Button('Deny')
          .fontSize(AppTypography.BODY_LARGE)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(Color.Transparent)
          .fontColor(LightColors.ERROR)
          .borderRadius(8)
          .height(BUTTON_HEIGHT)
          .layoutWeight(1)
          .border({ width: 1.5, color: LightColors.ERROR })
          .onClick(() => {
            this.callback.onDeny(this.request.id);
            this.controller.close();
          })

        // Approve button
        Button('Approve')
          .fontSize(AppTypography.BODY_LARGE)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(LightColors.PRIMARY)
          .fontColor(LightColors.PRIMARY_TEXT)
          .borderRadius(8)
          .height(BUTTON_HEIGHT)
          .layoutWeight(1)
          .onClick(() => {
            this.callback.onApprove(this.request.id, this.selectedMode);
            this.controller.close();
          })
      }
      .width('100%')
    }
    .padding(DIALOG_PADDING)
    .backgroundColor(Color.White)
    .borderRadius(DIALOG_BORDER_RADIUS)
  }
}
