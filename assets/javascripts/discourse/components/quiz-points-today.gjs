import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";

export default class QuizPointsToday extends Component {
  get earned() {
    return this.args.pointsToday ?? 0;
  }

  get max() {
    return this.args.dailyMax ?? 0;
  }

  get progressPercent() {
    if (this.max <= 0) {
      return 0;
    }

    return Math.min(100, Math.round((this.earned / this.max) * 100));
  }

  get progressStyle() {
    return htmlSafe(`width: ${this.progressPercent}%`);
  }

  get isCapReached() {
    return this.max > 0 && this.earned >= this.max;
  }

  <template>
    <div class="quiz-points-today {{if this.isCapReached 'is-cap-reached'}}">
      <div class="quiz-points-today__header">
        <span class="quiz-points-today__label">{{i18n "discourse_quiz.points_today_label"}}</span>
        <span class="quiz-points-today__value">
          {{i18n "discourse_quiz.points_today_value" earned=this.earned max=this.max}}
        </span>
      </div>
      <div
        class="quiz-points-today__track"
        role="progressbar"
        aria-valuenow={{this.earned}}
        aria-valuemin="0"
        aria-valuemax={{this.max}}
        aria-label={{i18n "discourse_quiz.points_today_value" earned=this.earned max=this.max}}
      >
        <div class="quiz-points-today__fill" style={{this.progressStyle}}></div>
      </div>
    </div>
  </template>
}
