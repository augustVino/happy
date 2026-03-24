/**
 * New session page - Configuration step for creating a new AI session.
 *
 * Users configure:
 * - AI Profile (model preset)
 * - Working directory (optional, can be set later)
 * - Custom system prompt (optional)
 *
 * After configuration, navigates to PickMachinePage to select a machine.
 */
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';
import { Logger } from 'common';
import { NavParams } from 'common';
import router from '@ohos.router';

const TAG = 'NewSessionPage';
const NAV_BAR_HEIGHT: number = 56;
const NAV_BAR_PADDING_H: number = 8;
const BACK_BUTTON_WIDTH: number = 44;
const SECTION_PADDING_H: number = 24;
const SECTION_BOTTOM_MARGIN: number = 20;
const LABEL_BOTTOM_MARGIN: number = 8;
const INPUT_HEIGHT: number = 48;
const TEXT_AREA_HEIGHT: number = 120;
const BUTTON_HEIGHT: number = 48;
const BUTTON_RADIUS: number = 12;
const BUTTON_PADDING_H: number = 24;
const OPTION_RADIUS: number = 10;
const OPTION_HEIGHT: number = 48;
const OPTION_PADDING_H: number = 16;
const OPTION_MARGIN_BOTTOM: number = 8;
const DESCRIPTION_TOP_MARGIN: number = 4;
const DESCRIPTION_BOTTOM_MARGIN: number = 16;
const BUTTON_BOTTOM_MARGIN: number = 32;

/** AI profile option for session configuration. */
class ProfileOption {
  id: string = '';
  label: string = '';
  description: string = '';
}

/** Predefined AI profile options. */
const PROFILES: ProfileOption[] = createProfileOptions();

function createProfileOptions(): ProfileOption[] {
  const defaultProfile: ProfileOption = new ProfileOption();
  defaultProfile.id = 'default';
  defaultProfile.label = 'Default';
  defaultProfile.description = 'General-purpose AI assistant';

  const codingProfile: ProfileOption = new ProfileOption();
  codingProfile.id = 'coding';
  codingProfile.label = 'Coding';
  codingProfile.description = 'Optimized for software development';

  const analysisProfile: ProfileOption = new ProfileOption();
  analysisProfile.id = 'analysis';
  analysisProfile.label = 'Analysis';
  analysisProfile.description = 'Focused on code review and analysis';

  return [defaultProfile, codingProfile, analysisProfile];
}

@Entry
@Component
export struct NewSessionPage {
  @State selectedProfile: string = 'default';
  @State workingDirectory: string = '';
  @State customPrompt: string = '';

  build() {
    Column() {
      // Navigation bar
      this.NavBar()

      // Scrollable content
      Scroll() {
        Column() {
          // Profile selection section
          this.ProfileSection()

          // Working directory section
          this.WorkingDirectorySection()

          // Custom prompt section
          this.CustomPromptSection()

          // Create button
          this.NextButton()
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
          router.back();
        })

      // Title
      Text('New Session')
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

  @Builder ProfileSection() {
    Column() {
      Text('AI Profile')
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .fontColor(LightColors.TEXT_PRIMARY)
        .margin({ bottom: LABEL_BOTTOM_MARGIN })

      Text('Select the AI model configuration for this session')
        .fontSize(AppTypography.BODY_SMALL)
        .fontColor(LightColors.TEXT_SECONDARY)
        .margin({ bottom: DESCRIPTION_BOTTOM_MARGIN })

      // Profile options
      Column() {
        ForEach(PROFILES, (profile: ProfileOption) => {
          Row() {
            Column() {
              Text(profile.label)
                .fontSize(AppTypography.BODY_MEDIUM)
                .fontWeight(FontWeight.Medium)
                .fontColor(LightColors.TEXT_PRIMARY)

              Text(profile.description)
                .fontSize(AppTypography.CAPTION)
                .fontColor(LightColors.TEXT_SECONDARY)
                .margin({ top: DESCRIPTION_TOP_MARGIN })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            // Selection indicator
            if (this.selectedProfile === profile.id) {
              Circle()
                .width(20)
                .height(20)
                .fill(LightColors.PRIMARY)
            } else {
              Circle()
                .width(20)
                .height(20)
                .fill(Color.Transparent)
                .stroke(LightColors.BORDER)
                .strokeWidth(2)
            }
          }
          .width('100%')
          .height(OPTION_HEIGHT)
          .padding({ left: OPTION_PADDING_H, right: OPTION_PADDING_H })
          .borderRadius(OPTION_RADIUS)
          .backgroundColor(this.selectedProfile === profile.id ? LightColors.NAV_BAR : LightColors.SURFACE)
          .border(this.selectedProfile === profile.id
            ? { width: 1, color: LightColors.PRIMARY }
            : { width: 1, color: LightColors.BORDER })
          .onClick(() => {
            this.selectedProfile = profile.id;
          })
        }, (profile: ProfileOption) => profile.id)
      }
    }
    .width('100%')
    .padding({ left: SECTION_PADDING_H, right: SECTION_PADDING_H })
    .margin({ top: SECTION_BOTTOM_MARGIN })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder WorkingDirectorySection() {
    Column() {
      Text('Working Directory')
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .fontColor(LightColors.TEXT_PRIMARY)
        .margin({ bottom: LABEL_BOTTOM_MARGIN })

      Text('You can set this now or choose on the next step')
        .fontSize(AppTypography.BODY_SMALL)
        .fontColor(LightColors.TEXT_SECONDARY)
        .margin({ bottom: DESCRIPTION_BOTTOM_MARGIN })

      TextInput({ text: this.workingDirectory, placeholder: '/path/to/project' })
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(LightColors.TEXT_PRIMARY)
        .placeholderColor(LightColors.TEXT_TERTIARY)
        .placeholderFont({ size: AppTypography.BODY_MEDIUM })
        .backgroundColor(LightColors.INPUT_BACKGROUND)
        .borderRadius(8)
        .height(INPUT_HEIGHT)
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.workingDirectory = value;
        })
    }
    .width('100%')
    .padding({ left: SECTION_PADDING_H, right: SECTION_PADDING_H })
    .margin({ top: SECTION_BOTTOM_MARGIN })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder CustomPromptSection() {
    Column() {
      Text('Custom System Prompt')
        .fontSize(AppTypography.BODY_LARGE)
        .fontWeight(FontWeight.Medium)
        .fontColor(LightColors.TEXT_PRIMARY)
        .margin({ bottom: LABEL_BOTTOM_MARGIN })

      Text('Optional: Additional instructions for the AI agent')
        .fontSize(AppTypography.BODY_SMALL)
        .fontColor(LightColors.TEXT_SECONDARY)
        .margin({ bottom: DESCRIPTION_BOTTOM_MARGIN })

      TextArea({ text: this.customPrompt, placeholder: 'Additional instructions for the AI agent...' })
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(LightColors.TEXT_PRIMARY)
        .placeholderColor(LightColors.TEXT_TERTIARY)
        .placeholderFont({ size: AppTypography.BODY_MEDIUM })
        .backgroundColor(LightColors.INPUT_BACKGROUND)
        .borderRadius(8)
        .height(TEXT_AREA_HEIGHT)
        .padding(12)
        .onChange((value: string) => {
          this.customPrompt = value;
        })
    }
    .width('100%')
    .padding({ left: SECTION_PADDING_H, right: SECTION_PADDING_H })
    .margin({ top: SECTION_BOTTOM_MARGIN })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder NextButton() {
    Button('Select Machine')
      .width('100%')
      .height(BUTTON_HEIGHT)
      .fontSize(AppTypography.BODY_LARGE)
      .fontWeight(FontWeight.Medium)
      .backgroundColor(LightColors.PRIMARY)
      .fontColor(LightColors.PRIMARY_TEXT)
      .borderRadius(BUTTON_RADIUS)
      .margin({ left: BUTTON_PADDING_H, right: BUTTON_PADDING_H, top: 8 })
      .onClick(() => {
        Logger.info(TAG, 'Proceeding to machine selection');
        const params: NavParams = new NavParams();
        params.profile = this.selectedProfile;
        params.directory = this.workingDirectory;
        params.prompt = this.customPrompt;
        router.pushUrl({ url: 'pages/PickMachinePage', params: params });
      })
  }
}
