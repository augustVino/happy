/**
 * Code block display component.
 * Renders code with dark background, language label, and copy button.
 * Supports long text scrolling via nested Scroll component.
 */
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';
import { Logger } from 'common';
import { pasteboard } from '@kit.BasicServicesKit';

const TAG = 'CodeBlock';
const CODE_BG_COLOR: string = '#1E1E1E';
const TOOLBAR_HEIGHT: number = 36;
const CODE_PADDING: number = 12;

@Component
export struct CodeBlock {
  @Prop code: string = '';
  @Prop language: string = '';
  @State copied: boolean = false;
  private scrollController: Scroller = new Scroller();

  private copyCode(): void {
    if (this.code === '') {
      return;
    }
    try {
      const pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.code);
      const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setDataSync(pasteData);
      this.copied = true;
      Logger.info(TAG, 'Code copied to clipboard');
      setTimeout(() => {
        this.copied = false;
      }, 2000);
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      Logger.error(TAG, 'Failed to copy code: ' + errMsg);
    }
  }

  build() {
    Column() {
      // Toolbar: language label + copy button
      Row() {
        if (this.language !== '') {
          Text(this.language.toUpperCase())
            .fontSize(AppTypography.CAPTION)
            .fontColor('#8E8E93')
            .padding({ left: 12 })
        }

        Blank()

        Button(this.copied ? 'Copied' : 'Copy')
          .fontSize(AppTypography.CAPTION)
          .fontColor('#8E8E93')
          .backgroundColor(Color.Transparent)
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .onClick(() => {
            this.copyCode();
          })
      }
      .width('100%')
      .height(TOOLBAR_HEIGHT)
      .backgroundColor('#2D2D2D')
      .borderRadius({ topLeft: 8, topRight: 8 })

      // Code area with scrolling
      Scroll(this.scrollController) {
        Text(this.code)
          .fontSize(AppTypography.BODY_SMALL)
          .fontFamily('monospace')
          .fontColor('#D4D4D4')
          .padding(CODE_PADDING)
          .wordBreak(WordBreak.BREAK_ALL)
      }
      .scrollBar(BarState.Auto)
      .scrollBarColor('#424242')
      .scrollBarWidth(4)
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.TopStart)
    }
    .backgroundColor(CODE_BG_COLOR)
    .borderRadius(8)
    .clip(true)
  }
}
