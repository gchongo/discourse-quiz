import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { eq, not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import DButton from "discourse/ui-kit/d-button";

export default class QuizQuestionDisplay extends Component {
  @service quiz;

  @tracked selectedIndex = null;
  @tracked selectedIndices = [];

  get question() {
    return this.args.question;
  }

  get isMultipleChoice() {
    return this.question.question_type === "multiple_choice";
  }

  get isTrueFalse() {
    return this.question.question_type === "true_false";
  }

  get questionTypeLabel() {
    return i18n(`discourse_quiz.admin.form.question_types.${this.question.question_type}`);
  }

  get canSubmit() {
    if (this.quiz.submitting) {
      return false;
    }

    if (this.isMultipleChoice) {
      return this.normalizedSelectedIndices.length > 0;
    }

    return this.selectedIndex !== null;
  }

  get normalizedSelectedIndices() {
    return Array.isArray(this.selectedIndices) ? this.selectedIndices : [];
  }

  get multipleChoiceOptions() {
    const selected = new Set(this.normalizedSelectedIndices);

    return (this.question.options || []).map((option, index) => ({
      option,
      index,
      selected: selected.has(index),
    }));
  }

  @action
  resetSelection() {
    this.selectedIndex = null;
    this.selectedIndices = [];
  }

  @action
  selectOption(index) {
    this.selectedIndex = index;
  }

  @action
  toggleOption(index) {
    const current = this.normalizedSelectedIndices;

    if (current.includes(index)) {
      this.selectedIndices = current.filter((value) => value !== index);
    } else {
      this.selectedIndices = [...current, index].sort((a, b) => a - b);
    }
  }

  @action
  submitAnswer() {
    if (!this.canSubmit) {
      return;
    }

    if (this.isMultipleChoice) {
      this.quiz.submitAnswer(null, this.normalizedSelectedIndices);
      return;
    }

    this.quiz.submitAnswer(this.selectedIndex);
  }

  <template>
    <div
      class="quiz-question-display {{if this.isTrueFalse 'quiz-question-display--true-false'}}"
      {{didUpdate this.resetSelection this.question.id}}
    >
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
      <p class="quiz-status-hint quiz-current-range">{{this.quiz.currentRangeSummary}}</p>
      <p class="quiz-status-hint quiz-current-range">{{this.quiz.currentTypesSummary}}</p>
      <div class="quiz-question-type">{{this.questionTypeLabel}}</div>
      <div class="quiz-question-category">{{this.question.category_name}}</div>
      <div class="quiz-question-text">{{this.question.question_text}}</div>

      {{#if this.isMultipleChoice}}
        <p class="quiz-status-hint">{{i18n "discourse_quiz.select_multiple_hint"}}</p>
      {{/if}}

      <ul class="quiz-options-list">
        {{#if this.isMultipleChoice}}
          {{#each this.multipleChoiceOptions as |entry|}}
            <li>
              <label class="quiz-option-btn quiz-option-check {{if entry.selected 'is-selected'}}">
                <input
                  type="checkbox"
                  checked={{entry.selected}}
                  disabled={{this.quiz.submitting}}
                  {{on "change" (fn this.toggleOption entry.index)}}
                />
                <span>{{entry.option}}</span>
              </label>
            </li>
          {{/each}}
        {{else}}
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
        {{/if}}
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
