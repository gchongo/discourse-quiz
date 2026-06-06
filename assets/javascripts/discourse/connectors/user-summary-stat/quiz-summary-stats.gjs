import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DUserStat from "discourse/ui-kit/d-user-stat";

export default class QuizSummaryStats extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked stats = null;

  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      siteSettings.quiz_plugin_enabled &&
      currentUser &&
      args.user?.id === currentUser.id
    );
  }

  constructor() {
    super(...arguments);
    this.loadStats();
  }

  get enabled() {
    return Boolean(this.stats);
  }

  async loadStats() {
    try {
      const data = await ajax("/quiz/summary_stats.json");
      this.stats = data.quiz_summary_stats;
    } catch {
      this.stats = null;
    }
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
