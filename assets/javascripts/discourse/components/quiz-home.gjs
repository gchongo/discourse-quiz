import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { eq, not, or } from "discourse/truth-helpers";
import { fn } from "@ember/helper";
import { i18n } from "discourse-i18n";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import QuizCategoryRow from "./quiz-category-row";

export default class QuizHome extends Component {
  @service quiz;

  @action
  startQuiz() {
    this.quiz.startQuiz();
  }

  @action
  resetSelection() {
    this.quiz.resetSelection();
  }

  <template>
    <div class="quiz-home">
      <div class="quiz-home-header">
        <h2 class="quiz-home-title">{{i18n "discourse_quiz.home_title"}}</h2>
        <p class="quiz-home-subtitle">{{i18n "discourse_quiz.home_subtitle"}}</p>
      </div>

      <div class="quiz-home-modes">
        <span class="quiz-home-modes__label">{{i18n "discourse_quiz.home_question_type"}}</span>
        <div class="quiz-home-modes__buttons" role="group">
          <button
            type="button"
            class="btn btn-default quiz-home-mode-btn {{if (this.quiz.isQuestionTypeSelected 'single_choice') 'active'}}"
            {{on "click" (fn this.quiz.toggleQuestionType "single_choice")}}
          >
            {{i18n "discourse_quiz.admin.form.question_types.single_choice"}}
          </button>
          <button
            type="button"
            class="btn btn-default quiz-home-mode-btn {{if (this.quiz.isQuestionTypeSelected 'true_false') 'active'}}"
            {{on "click" (fn this.quiz.toggleQuestionType "true_false")}}
          >
            {{i18n "discourse_quiz.admin.form.question_types.true_false"}}
          </button>
          <button
            type="button"
            class="btn btn-default quiz-home-mode-btn {{if (this.quiz.isQuestionTypeSelected 'multiple_choice') 'active'}}"
            {{on "click" (fn this.quiz.toggleQuestionType "multiple_choice")}}
          >
            {{i18n "discourse_quiz.admin.form.question_types.multiple_choice"}}
          </button>
        </div>
        <p class="quiz-status-hint">{{i18n "discourse_quiz.home_question_type_hint"}}</p>
      </div>

      <div class="quiz-home-modes">
        <span class="quiz-home-modes__label">{{i18n "discourse_quiz.home_practice_mode"}}</span>
        <div class="quiz-home-modes__buttons" role="group">
          <button
            type="button"
            class="btn btn-default quiz-home-mode-btn {{if (eq this.quiz.practiceMode 'normal') 'active'}}"
            {{on "click" (fn this.quiz.setPracticeMode "normal")}}
          >
            {{i18n "discourse_quiz.home_mode_normal"}}
          </button>
          <button
            type="button"
            class="btn btn-default quiz-home-mode-btn {{if (eq this.quiz.practiceMode 'wrong_only') 'active'}}"
            {{on "click" (fn this.quiz.setPracticeMode "wrong_only")}}
            disabled={{not this.quiz.canUsePracticeModes}}
          >
            {{i18n "discourse_quiz.home_mode_wrong_only"}}
          </button>
          <button
            type="button"
            class="btn btn-default quiz-home-mode-btn {{if (eq this.quiz.practiceMode 'unseen') 'active'}}"
            {{on "click" (fn this.quiz.setPracticeMode "unseen")}}
            disabled={{not this.quiz.canUsePracticeModes}}
          >
            {{i18n "discourse_quiz.home_mode_unseen"}}
          </button>
        </div>
        {{#unless this.quiz.canUsePracticeModes}}
          <p class="quiz-status-hint">{{i18n "discourse_quiz.home_mode_login_hint"}}</p>
        {{/unless}}
      </div>

      <div class="quiz-home-list">
        <div class="quiz-category-row">
          <span class="quiz-category-row__label">
            {{i18n "discourse_quiz.home_all_categories"}}
          </span>
          <DToggleSwitch
            @state={{this.quiz.selectAllMode}}
            {{on "click" this.quiz.toggleAllCategories}}
          />
        </div>

        {{#each this.quiz.availableCategories as |category|}}
          <QuizCategoryRow @category={{category}} />
        {{/each}}
      </div>

      {{#if this.quiz.quizStatus.is_guest}}
        <p class="quiz-status-hint">
          {{i18n
            "discourse_quiz.guest_attempts_left"
            count=this.quiz.quizStatus.attempts_left
          }}
        </p>
      {{/if}}

      {{#if this.quiz.isLearningOnly}}
        <p class="quiz-status-hint">{{i18n "discourse_quiz.learning_only"}}</p>
      {{/if}}

      <div class="quiz-home-footer">
        <p class="quiz-home-summary">{{this.quiz.selectedSummary}}</p>
        <p class="quiz-home-summary">{{this.quiz.selectedTypesSummary}}</p>

        <DButton
          @label="discourse_quiz.home_reset"
          @action={{this.resetSelection}}
          class="btn-default quiz-home-reset-btn"
        />

        <DButton
          @label="discourse_quiz.home_start"
          @action={{this.startQuiz}}
          @disabled={{or this.quiz.loading (not this.quiz.canStart)}}
          class="btn-primary quiz-home-start-btn"
        />
      </div>
    </div>
  </template>
}
