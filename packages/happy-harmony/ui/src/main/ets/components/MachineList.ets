/**
 * Machine list component.
 * Displays a scrollable list of MachineCards with optional selection state.
 * Used in SessionsPage to show available CLI daemons.
 */
import { Machine } from 'common';
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';
import { MachineCard } from './MachineCard';

const TITLE_BOTTOM_MARGIN: number = 12;
const CARD_BOTTOM_MARGIN: number = 8;
const LIST_PADDING: number = 16;

@Component
export struct MachineList {
  @Prop machines: Machine[] = [];
  @Prop selectedMachineId: string = '';
  onMachineSelected: (machine: Machine) => void = (): void => {};

  build() {
    Column() {
      // Section title
      Text('Machines')
        .fontSize(AppTypography.TITLE_SMALL)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightColors.TEXT_PRIMARY)
        .margin({ bottom: TITLE_BOTTOM_MARGIN })

      if (this.machines.length === 0) {
        Text('No machines connected')
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(LightColors.TEXT_TERTIARY)
          .textAlign(TextAlign.Center)
          .padding(24)
      } else {
        List({ space: CARD_BOTTOM_MARGIN }) {
          ForEach(this.machines, (machine: Machine): void => {
            ListItem() {
              MachineCard({
                machine: machine,
                isSelected: machine.id === this.selectedMachineId
              })
            }
            .onClick(() => {
              this.onMachineSelected(machine);
            })
          }, (machine: Machine): string => {
            return machine.id;
          })
        }
        .width('100%')
        .padding({ left: LIST_PADDING, right: LIST_PADDING })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
  }
}
