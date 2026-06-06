import Component from "@glimmer/component";
import { service } from "@ember/service";
import DUserStat from "discourse/ui-kit/d-user-stat";

export default class QuizSummaryStats extends Component {
  @service siteSettings;

  get stats() {
    return this.args.outletArgs?.model?.quiz_summary_stats;
  }

  get enabled() {
    return this.siteSettings.quiz_plugin_enabled && this.stats;
  }

  <template>
    {{#if this.enabled}}
      <li class="user-summary-stat-outlet quiz-today-correct">
        <DUserStat
          @value={{this.stats.today_correct}}
          @label="discourse_quiz.user_summary.today_correct"
          @icon="circle-check"
        />
      </li>
      <li class="user-summary-stat-outlet quiz-today-incorrect">
        <DUserStat
          @value={{this.stats.today_incorrect}}
          @label="discourse_quiz.user_summary.today_incorrect"
          @icon="circle-xmark"
        />
      </li>
      <li class="user-summary-stat-outlet quiz-wrong-pending">
        <DUserStat
          @value={{this.stats.wrong_pending}}
          @label="discourse_quiz.user_summary.wrong_pending"
          @icon="circle-question"
        />
      </li>
    {{/if}}
  </template>
}
