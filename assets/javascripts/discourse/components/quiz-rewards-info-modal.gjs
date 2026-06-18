import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import DModal from "discourse/ui-kit/d-modal";

export default class QuizRewardsInfoModal extends Component {
  @service siteSettings;

  get customHelpText() {
    return this.siteSettings.quiz_rewards_help?.trim() || "";
  }

  get useCustomHelpText() {
    return this.customHelpText.length > 0;
  }

  get showSubmissionRewardRule() {
    return (
      this.siteSettings.quiz_submission_reward_enabled &&
      this.siteSettings.quiz_submission_reward_points > 0 &&
      this.siteSettings.quiz_submission_reward_daily_cap > 0
    );
  }

  <template>
    <DModal
      @title={{i18n "discourse_quiz.rewards.info_modal_title"}}
      @closeModal={{@closeModal}}
      class="quiz-rewards-info-modal"
    >
      <div class="quiz-rewards-info-modal__body">
        {{#if this.useCustomHelpText}}
          <div class="quiz-rewards-info-modal__custom">{{this.customHelpText}}</div>
        {{else}}
          <p>{{i18n "discourse_quiz.rewards.intro_default"}}</p>
          <h3>{{i18n "discourse_quiz.rewards.points_rules_title"}}</h3>
          <ul>
            <li>{{i18n "discourse_quiz.rewards.points_rule_quiz"}}</li>
            {{#if this.showSubmissionRewardRule}}
              <li>
                {{i18n
                  "discourse_quiz.rewards.points_rule_submission_reward"
                  points=this.siteSettings.quiz_submission_reward_points
                  cap=this.siteSettings.quiz_submission_reward_daily_cap
                }}
              </li>
            {{/if}}
            <li>{{i18n "discourse_quiz.rewards.points_rule_forum_interaction"}}</li>
          </ul>
        {{/if}}
      </div>
    </DModal>
  </template>
}
