import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import DButton from "discourse/ui-kit/d-button";
import QuizQuestionMeta from "./quiz-question-meta";
import QuizCookedText from "./quiz-cooked-text";

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

  get radioGroupName() {
    return `quiz-question-${this.question.id}`;
  }

  get authorLabel() {
    const username = this.question.author_hidden
      ? i18n("discourse_quiz.question_author_unknown")
      : this.question.author_username || i18n("discourse_quiz.question_author_admin_default");
    return i18n("discourse_quiz.question_author", { username });
  }

  get singleChoiceOptions() {
    return (this.question.options || []).map((option, index) => ({
      option,
      index,
      selected: this.selectedIndex === index,
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
        <p class="quiz-learning-notice">{{i18n "discourse_quiz.learning_only"}}</p>
      {{/if}}
      {{#if this.quiz.quizStatus.is_guest}}
        <p class="quiz-status-hint">
          {{i18n
            "discourse_quiz.guest_attempts_left"
            count=this.quiz.quizStatus.attempts_left
          }}
        </p>
      {{/if}}
      <QuizQuestionMeta
        @typeLabel={{this.questionTypeLabel}}
        @categoryName={{this.question.category_name}}
      />
      <QuizCookedText
        class="quiz-question-text quiz-cooked-block"
        @rawText={{this.question.question_text}}
      />

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
                <QuizCookedText class="quiz-cooked-inline" @rawText={{entry.option}} />
              </label>
            </li>
          {{/each}}
        {{else}}
          {{#each this.singleChoiceOptions as |entry|}}
            <li>
              <label class="quiz-option-btn quiz-option-radio {{if entry.selected 'is-selected'}}">
                <input
                  type="radio"
                  name={{this.radioGroupName}}
                  checked={{entry.selected}}
                  disabled={{this.quiz.submitting}}
                  {{on "change" (fn this.selectOption entry.index)}}
                />
                <QuizCookedText class="quiz-cooked-inline" @rawText={{entry.option}} />
              </label>
            </li>
          {{/each}}
        {{/if}}
      </ul>

      <p class="quiz-question-author">{{this.authorLabel}}</p>

      <DButton
        @label={{if this.quiz.submitting "discourse_quiz.submitting" "discourse_quiz.submit"}}
        @action={{this.submitAnswer}}
        @disabled={{not this.canSubmit}}
        class="btn-primary quiz-submit-btn"
      />
    </div>
  </template>
}
