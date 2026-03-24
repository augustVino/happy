/**
 * Machine card component.
 * Displays machine name, online status indicator, daemon state,
 * and last active time. Supports selection highlight.
 */
import { Machine } from 'common';
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';
import { formatRelativeTime } from '../datasource/SessionDataSource';

const STATUS_DOT_SIZE: number = 10;
const NAME_BOTTOM_MARGIN: number = 4;

@Component
export struct MachineCard {
  @Prop machine: Machine = new Machine();
  @Prop isSelected: boolean = false;

  build() {
    Column() {
      // Name row with online status indicator
      Row() {
        // Online status dot
        if (this.machine.isOnline) {
          Circle()
            .width(STATUS_DOT_SIZE)
            .height(STATUS_DOT_SIZE)
            .fill(LightColors.SUCCESS)
        } else {
          Circle()
            .width(STATUS_DOT_SIZE)
            .height(STATUS_DOT_SIZE)
            .fill(LightColors.TEXT_TERTIARY)
        }

        // Machine name
        Text(this.machine.decryptedName !== '' ? this.machine.decryptedName : this.machine.name)
          .fontSize(AppTypography.BODY_LARGE)
          .fontWeight(FontWeight.Medium)
          .fontColor(LightColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 10 })
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // Daemon state
      if (this.machine.daemonState !== '') {
        Text(this.capitalizeDaemonState(this.machine.daemonState))
          .fontSize(AppTypography.BODY_SMALL)
          .fontColor(LightColors.TEXT_SECONDARY)
          .margin({ top: NAME_BOTTOM_MARGIN })
      }

      // Last active time
      if (this.machine.activeAt > 0) {
        Text('Last active ' + formatRelativeTime(this.machine.activeAt))
          .fontSize(AppTypography.CAPTION)
          .fontColor(LightColors.TEXT_TERTIARY)
          .margin({ top: 2 })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 16, top: 12, bottom: 16 })
    .borderRadius(12)
    .backgroundColor(this.isSelected ? LightColors.NAV_BAR : LightColors.CARD_BACKGROUND)
    .border(this.isSelected
      ? { width: 2, color: LightColors.PRIMARY }
      : { width: 1, color: LightColors.BORDER })
  }

  private capitalizeDaemonState(state: string): string {
    if (state.length === 0) {
      return state;
    }
    // Replace hyphens with spaces, then capitalize first letter
    const parts: string[] = state.split('-');
    const result: string[] = [];
    for (let i: number = 0; i < parts.length; i++) {
      const part: string = parts[i];
      if (part.length > 0) {
        const first: string = part.charAt(0).toUpperCase();
        const rest: string = part.substring(1);
        result.push(first + rest);
      }
    }
    return result.join(' ');
  }
}
