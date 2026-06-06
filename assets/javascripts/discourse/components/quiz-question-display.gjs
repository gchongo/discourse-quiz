import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { eq, not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import DButton from "discourse/ui-kit/d-button";

export default class QuizQuestionDisplay extends Component {
  @service quiz;

  @tracked selectedIndex = null;

  get question() {
    return this.args.question;
  }

  get canSubmit() {
    return this.selectedIndex !== null && !this.quiz.submitting;
  }

  @action
  selectOption(index) {
    this.selectedIndex = index;
  }

  @action
  submitAnswer() {
    if (!this.canSubmit) {
      return;
    }

    this.quiz.submitAnswer(this.selectedIndex);
  }

  <template>
    <div class="quiz-question-display">
      {{#if this.quiz.isLearningOnly}}
        <p class="quiz-status-hint">{{i18n "discourse_quiz.learning_only"}}</p>
      {{/if}}
      {{#if this.quiz.quizStatus.is_guest}}
        <p class="quiz-status-hint">
          {{i18n
            "discourse_quiz.guest_attempts_left"
            count=this.quiz.quizStatus.attempts_left
          }}
        </p>
      {{/if}}
      <p class="quiz-range-hint">
        {{#if this.quiz.selectedCategory}}
          {{i18n "discourse_quiz.current_range" category=this.quiz.selectedCategory}}
        {{else}}
          {{i18n "discourse_quiz.current_range_all"}}
        {{/if}}
      </p>
      <div class="quiz-question-category">{{this.question.category_name}}</div>
      <div class="quiz-question-text">{{this.question.question_text}}</div>

      <ul class="quiz-options-list">
        {{#each this.question.options as |option index|}}
          <li>
            <button
              type="button"
              class="quiz-option-btn {{if (eq this.selectedIndex index) 'is-selected'}}"
              disabled={{this.quiz.submitting}}
              {{on "click" (fn this.selectOption index)}}
            >
              {{option}}
            </button>
          </li>
        {{/each}}
      </ul>

      <DButton
        @label={{if this.quiz.submitting "discourse_quiz.submitting" "discourse_quiz.submit"}}
        @action={{this.submitAnswer}}
        @disabled={{not this.canSubmit}}
        class="btn-primary quiz-submit-btn"
      />
    </div>
  </template>
}
