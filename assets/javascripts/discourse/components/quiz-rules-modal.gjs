import Component from "@glimmer/component";
import { service } from "@ember/service";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class QuizRulesModal extends Component {
  @service siteSettings;

  get customRules() {
    return this.siteSettings.quiz_rules_help?.trim() || "";
  }

  get useCustomRules() {
    return this.customRules.length > 0;
  }

  get tiersEnabled() {
    return this.siteSettings.quiz_tier1_upto_count > 0;
  }

  get showTier2Rule() {
    return this.siteSettings.quiz_tier2_upto_count > this.siteSettings.quiz_tier1_upto_count;
  }

  get showScoringRules() {
    return (
      this.siteSettings.quiz_daily_max_points > 0 &&
      (this.tiersEnabled || this.siteSettings.quiz_points_per_question > 0)
    );
  }

  get showCooldownRule() {
    return this.siteSettings.quiz_submit_cooldown_seconds > 0;
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
      @title={{i18n "discourse_quiz.rules_modal.title"}}
      @closeModal={{@closeModal}}
      class="quiz-rules-modal"
    >
      <div class="quiz-rules-modal__body">
        {{#if this.useCustomRules}}
          <div class="quiz-rules-modal__custom">{{this.customRules}}</div>
        {{else}}
          <h3>{{i18n "discourse_quiz.rules_modal.play_title"}}</h3>
          <ul>
            <li>{{i18n "discourse_quiz.rules_modal.play_types"}}</li>
            <li>{{i18n "discourse_quiz.rules_modal.play_categories"}}</li>
            <li>{{i18n "discourse_quiz.rules_modal.play_modes"}}</li>
          </ul>

          {{#if this.showScoringRules}}
            <h3>{{i18n "discourse_quiz.rules_modal.scoring_title"}}</h3>
            <ul>
              {{#if this.tiersEnabled}}
                <li>
                  {{i18n
                    "discourse_quiz.rules_modal.scoring_tier1"
                    count=this.siteSettings.quiz_tier1_upto_count
                    points=this.siteSettings.quiz_tier1_points
                  }}
                </li>
                {{#if this.showTier2Rule}}
                  <li>
                    {{i18n
                      "discourse_quiz.rules_modal.scoring_tier2"
                      count=this.siteSettings.quiz_tier2_upto_count
                      points=this.siteSettings.quiz_tier2_points
                    }}
                  </li>
                {{/if}}
                <li>
                  {{i18n
                    "discourse_quiz.rules_modal.scoring_tier3"
                    points=this.siteSettings.quiz_tier3_points
                  }}
                </li>
              {{else}}
                <li>
                  {{i18n
                    "discourse_quiz.rules_modal.scoring_per_question"
                    count=this.siteSettings.quiz_points_per_question
                  }}
                </li>
              {{/if}}
              <li>
                {{i18n
                  "discourse_quiz.rules_modal.scoring_daily_cap"
                  count=this.siteSettings.quiz_daily_max_points
                }}
              </li>
              <li>{{i18n "discourse_quiz.rules_modal.scoring_once_per_question"}}</li>
              <li>{{i18n "discourse_quiz.rules_modal.scoring_learning_only"}}</li>
              {{#if this.showSubmissionRewardRule}}
                <li>
                  {{i18n
                    "discourse_quiz.rules_modal.scoring_submission_reward"
                    points=this.siteSettings.quiz_submission_reward_points
                    cap=this.siteSettings.quiz_submission_reward_daily_cap
                  }}
                </li>
              {{/if}}
              <li>{{i18n "discourse_quiz.rules_modal.scoring_forum_interaction"}}</li>
            </ul>
          {{/if}}

          {{#if this.showCooldownRule}}
            <p>
              {{i18n
                "discourse_quiz.rules_modal.cooldown"
                seconds=this.siteSettings.quiz_submit_cooldown_seconds
              }}
            </p>
          {{/if}}
        {{/if}}
      </div>
    </DModal>
  </template>
}
