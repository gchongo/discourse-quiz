import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
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

  get accuracyDisplay() {
    if (this.stats?.accuracy_rate === null || this.stats?.accuracy_rate === undefined) {
      return i18n("discourse_quiz.user_summary.accuracy_none");
    }

    return i18n("discourse_quiz.user_summary.accuracy_value", {
      rate: this.stats.accuracy_rate,
    });
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
      <li class="user-summary-stat-outlet quiz-lifetime-correct">
        <DUserStat
          @value={{this.stats.lifetime_correct}}
          @label="discourse_quiz.user_summary.lifetime_correct"
        />
      </li>
      <li class="user-summary-stat-outlet quiz-wrong-questions">
        <DUserStat
          @value={{this.stats.wrong_questions}}
          @label="discourse_quiz.user_summary.wrong_questions"
        />
      </li>
      <li class="user-summary-stat-outlet quiz-accuracy-rate">
        <DUserStat
          @value={{this.accuracyDisplay}}
          @label="discourse_quiz.user_summary.accuracy_rate"
        />
      </li>
    {{/if}}
  </template>
}
