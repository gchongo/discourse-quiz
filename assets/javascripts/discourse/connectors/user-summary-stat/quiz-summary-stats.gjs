import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";

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
      <li class="user-summary-stat-outlet quiz-lifetime-correct">
        <div class="user-stat">
          <span
            class="value"
            title={{i18n "discourse_quiz.user_summary.lifetime_correct"}}
          >
            {{dNumber this.stats.lifetime_correct}}
          </span>
        </div>
      </li>
      <li class="user-summary-stat-outlet quiz-wrong-questions">
        <div class="user-stat">
          <span
            class="value"
            title={{i18n "discourse_quiz.user_summary.wrong_questions"}}
          >
            {{dNumber this.stats.wrong_questions}}
          </span>
        </div>
      </li>
    {{/if}}
  </template>
}
