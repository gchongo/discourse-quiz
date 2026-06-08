import Component from "@glimmer/component";
import { service } from "@ember/service";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class QuizRulesModal extends Component {
  @service siteSettings;
  @service currentUser;

  get quizStatus() {
    return this.args.model?.quizStatus;
  }

  get showScoringRules() {
    return (
      this.siteSettings.quiz_points_per_question > 0 &&
      this.siteSettings.quiz_daily_max_points > 0
    );
  }

  get showCooldownRule() {
    return this.siteSettings.quiz_submit_cooldown_seconds > 0;
  }

  get showGuestRules() {
    return !this.currentUser && this.siteSettings.quiz_enable_guest_demo;
  }

  get showLoggedInStatus() {
    return this.currentUser && this.quizStatus && !this.quizStatus.is_guest;
  }

  <template>
    <DModal
      @title={{i18n "discourse_quiz.rules_modal.title"}}
      @closeModal={{@closeModal}}
      class="quiz-rules-modal"
    >
      <div class="quiz-rules-modal__body">
        <p>{{i18n "discourse_quiz.rules_modal.intro"}}</p>

        <h3>{{i18n "discourse_quiz.rules_modal.play_title"}}</h3>
        <ul>
          <li>{{i18n "discourse_quiz.rules_modal.play_types"}}</li>
          <li>{{i18n "discourse_quiz.rules_modal.play_categories"}}</li>
          <li>{{i18n "discourse_quiz.rules_modal.play_modes"}}</li>
        </ul>

        {{#if this.showScoringRules}}
          <h3>{{i18n "discourse_quiz.rules_modal.scoring_title"}}</h3>
          <ul>
            <li>
              {{i18n
                "discourse_quiz.rules_modal.scoring_per_question"
                count=this.siteSettings.quiz_points_per_question
              }}
            </li>
            <li>
              {{i18n
                "discourse_quiz.rules_modal.scoring_daily_cap"
                count=this.siteSettings.quiz_daily_max_points
              }}
            </li>
            <li>{{i18n "discourse_quiz.rules_modal.scoring_once_per_question"}}</li>
            <li>{{i18n "discourse_quiz.rules_modal.scoring_learning_only"}}</li>
          </ul>
        {{/if}}

        {{#if this.showLoggedInStatus}}
          <p class="quiz-rules-modal__status">
            {{i18n
              "discourse_quiz.rules_modal.points_today"
              earned=this.quizStatus.points_today
              max=this.quizStatus.daily_max
            }}
          </p>
        {{/if}}

        {{#if this.showGuestRules}}
          <h3>{{i18n "discourse_quiz.rules_modal.guest_title"}}</h3>
          <ul>
            <li>
              {{i18n
                "discourse_quiz.rules_modal.guest_attempt_limit"
                count=this.siteSettings.quiz_guest_attempt_limit
              }}
            </li>
            <li>{{i18n "discourse_quiz.rules_modal.guest_login_hint"}}</li>
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
      </div>
    </DModal>
  </template>
}
