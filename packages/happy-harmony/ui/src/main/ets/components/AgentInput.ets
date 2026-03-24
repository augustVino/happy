/**
 * Agent input component.
 * Multi-line text input with send button for composing messages.
 * Uses callback class pattern to work around ArkTS function-prop restriction.
 */
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';

const INPUT_CONTAINER_PADDING_H: number = 12;
const INPUT_CONTAINER_PADDING_V: number = 10;
const INPUT_BORDER_RADIUS: number = 20;
const SEND_BUTTON_SIZE: number = 36;
const SEND_BUTTON_MARGIN_LEFT: number = 8;
const MAX_INPUT_LINES: number = 5;

/** Callback class for send action. */
export class AgentInputCallback {
  onSend: (text: string) => void = () => {};
}

@Component
export struct AgentInput {
  @Prop isThinking: boolean = false;
  @State inputText: string = '';
  sendCallback: AgentInputCallback | null = null;

  build() {
    Row() {
      // Text input area
      TextArea({
        text: this.inputText,
        placeholder: this.isThinking ? 'Agent is thinking...' : 'Type a message...'
      })
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(LightColors.TEXT_PRIMARY)
        .placeholderColor(LightColors.TEXT_TERTIARY)
        .placeholderFont({ size: AppTypography.BODY_MEDIUM })
        .backgroundColor(LightColors.INPUT_BACKGROUND)
        .borderRadius(INPUT_BORDER_RADIUS)
        .padding({ left: 16, right: 12, top: 10, bottom: 10 })
        .layoutWeight(1)
        .maxLines(MAX_INPUT_LINES)
        .onChange((value: string) => {
          this.inputText = value;
        })
        .enabled(!this.isThinking)
        .opacity(this.isThinking ? 0.6 : 1.0)

      // Send button
      Column() {
        Text('>')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(LightColors.PRIMARY_TEXT)
      }
      .width(SEND_BUTTON_SIZE)
      .height(SEND_BUTTON_SIZE)
      .borderRadius(SEND_BUTTON_SIZE / 2)
      .backgroundColor(this.canSend() ? LightColors.PRIMARY : LightColors.TEXT_TERTIARY)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ left: SEND_BUTTON_MARGIN_LEFT })
      .enabled(this.canSend())
      .opacity(this.canSend() ? 1.0 : 0.5)
      .onClick(() => {
        this.handleSend();
      })
    }
    .width('100%')
    .padding({
      left: INPUT_CONTAINER_PADDING_H,
      right: INPUT_CONTAINER_PADDING_H,
      top: INPUT_CONTAINER_PADDING_V,
      bottom: INPUT_CONTAINER_PADDING_V
    })
    .backgroundColor(LightColors.SURFACE)
  }

  private canSend(): boolean {
    return this.inputText.trim().length > 0 && !this.isThinking;
  }

  private handleSend(): void {
    if (!this.canSend()) {
      return;
    }
    const text: string = this.inputText.trim();
    this.inputText = '';
    if (this.sendCallback !== null) {
      this.sendCallback.onSend(text);
    }
  }
}
