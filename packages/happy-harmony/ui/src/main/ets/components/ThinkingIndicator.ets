/**
 * Thinking indicator component.
 * Shows three animated dots when agent is processing.
 * Uses scale/opacity animation for optimal performance.
 */
import { LightColors } from '../theme/Colors';

const DOT_SIZE: number = 8;
const DOT_GAP: number = 6;
const ANIMATION_DURATION: number = 600;
const ANIMATION_DELAY: number = 200;

@Reusable
@Component
export struct ThinkingIndicator {
  @Prop isThinking: boolean = false;
  @Prop color: string = LightColors.PRIMARY;
  @State dotScale0: number = 0.6;
  @State dotScale1: number = 0.6;
  @State dotScale2: number = 0.6;
  @State dotOpacity0: number = 0.4;
  @State dotOpacity1: number = 0.4;
  @State dotOpacity2: number = 0.4;
  private animationTimer: number = -1;

  aboutToAppear(): void {
    this.startAnimation();
  }

  aboutToDisappear(): void {
    this.stopAnimation();
  }

  aboutToReuse(): void {
    this.startAnimation();
  }

  private startAnimation(): void {
    this.stopAnimation();
    if (!this.isThinking) {
      return;
    }
    this.animateDots();
    this.animationTimer = setInterval(() => {
      this.animateDots();
    }, ANIMATION_DURATION) as number;
  }

  private stopAnimation(): void {
    if (this.animationTimer !== -1) {
      clearInterval(this.animationTimer);
      this.animationTimer = -1;
    }
  }

  private animateDots(): void {
    // Dot 0
    animateTo({ duration: ANIMATION_DURATION, curve: Curve.EaseInOut }, () => {
      this.dotScale0 = 1.0;
      this.dotOpacity0 = 1.0;
    });
    setTimeout(() => {
      animateTo({ duration: ANIMATION_DURATION, curve: Curve.EaseInOut }, () => {
        this.dotScale0 = 0.6;
        this.dotOpacity0 = 0.4;
      });
    }, ANIMATION_DURATION * 0.6);

    // Dot 1 (delayed)
    setTimeout(() => {
      animateTo({ duration: ANIMATION_DURATION, curve: Curve.EaseInOut }, () => {
        this.dotScale1 = 1.0;
        this.dotOpacity1 = 1.0;
      });
      setTimeout(() => {
        animateTo({ duration: ANIMATION_DURATION, curve: Curve.EaseInOut }, () => {
          this.dotScale1 = 0.6;
          this.dotOpacity1 = 0.4;
        });
      }, ANIMATION_DURATION * 0.6);
    }, ANIMATION_DELAY);

    // Dot 2 (further delayed)
    setTimeout(() => {
      animateTo({ duration: ANIMATION_DURATION, curve: Curve.EaseInOut }, () => {
        this.dotScale2 = 1.0;
        this.dotOpacity2 = 1.0;
      });
      setTimeout(() => {
        animateTo({ duration: ANIMATION_DURATION, curve: Curve.EaseInOut }, () => {
          this.dotScale2 = 0.6;
          this.dotOpacity2 = 0.4;
        });
      }, ANIMATION_DURATION * 0.6);
    }, ANIMATION_DELAY * 2);
  }

  build() {
    if (this.isThinking) {
      Row({ space: DOT_GAP }) {
        Circle()
          .width(DOT_SIZE)
          .height(DOT_SIZE)
          .fill(this.color)
          .scale({ x: this.dotScale0, y: this.dotScale0 })
          .opacity(this.dotOpacity0)

        Circle()
          .width(DOT_SIZE)
          .height(DOT_SIZE)
          .fill(this.color)
          .scale({ x: this.dotScale1, y: this.dotScale1 })
          .opacity(this.dotOpacity1)

        Circle()
          .width(DOT_SIZE)
          .height(DOT_SIZE)
          .fill(this.color)
          .scale({ x: this.dotScale2, y: this.dotScale2 })
          .opacity(this.dotOpacity2)
      }
      .height(20)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
  }
}
