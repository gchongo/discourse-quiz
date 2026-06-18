import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import DButton from "discourse/ui-kit/d-button";
import QuizQuestionMeta from "./quiz-question-meta";
import QuizCookedText from "./quiz-cooked-text";

export default class QuizResultDisplay extends Component {
  @service quiz;

  get question() {
    return this.args.question;
  }

  get result() {
    return this.args.result;
  }

  get isMultipleChoice() {
    return this.result.question_type === "multiple_choice";
  }

  get isTrueFalse() {
    return this.result.question_type === "true_false";
  }

  get questionTypeLabel() {
    const type = this.result.question_type || this.question.question_type;
    return i18n(`discourse_quiz.admin.form.question_types.${type}`);
  }

  get submittedIndex() {
    return this.quiz.submittedAnswerIndex;
  }

  get incorrectPrefix() {
    if (this.result.correct) {
      return null;
    }

    if (this.isMultipleChoice) {
      return i18n("discourse_quiz.incorrect_multiple_prefix");
    }

    return i18n("discourse_quiz.incorrect_prefix");
  }

  get correctOptions() {
    return this.result.correct_options || [];
  }

  get multipleChoiceResultOptions() {
    const correctIndices = new Set(this.result.correct_indices || []);
    const submittedIndices = new Set(this.quiz.submittedAnswerIndices || []);

    return (this.question.options || []).map((option, index) => {
      const classes = ["quiz-option-btn", "quiz-option-check", "is-locked"];

      if (correctIndices.has(index)) {
        classes.push("is-correct");
      }

      if (submittedIndices.has(index) && !this.result.correct) {
        classes.push("is-incorrect");
      }

      return {
        option,
        index,
        className: classes.join(" "),
        checked: submittedIndices.has(index),
      };
    });
  }

  get radioGroupName() {
    return `quiz-result-${this.question.id}`;
  }

  get authorLabel() {
    const username = this.question.author_hidden
      ? i18n("discourse_quiz.question_author_unknown")
      : this.question.author_username || i18n("discourse_quiz.question_author_admin_default");
    return i18n("discourse_quiz.question_author", { username });
  }

  get singleChoiceResultOptions() {
    return (this.question.options || []).map((option, index) => {
      const classes = ["quiz-option-btn", "quiz-option-radio", "is-locked"];

      if (index === this.result.correct_index) {
        classes.push("is-correct");
      }

      if (index === this.submittedIndex && !this.result.correct) {
        classes.push("is-incorrect");
      }

      return {
        option,
        index,
        className: classes.join(" "),
        checked: index === this.submittedIndex,
      };
    });
  }

  @action
  nextQuestion() {
    this.quiz.loadQuestion();
  }

  <template>
    {{#if this.result}}
      <div
        class="quiz-result-display {{if this.isTrueFalse 'quiz-result-display--true-false'}}"
      >
        <QuizQuestionMeta
          @typeLabel={{this.questionTypeLabel}}
          @categoryName={{this.question.category_name}}
        />
        <QuizCookedText
          class="quiz-question-text quiz-cooked-block"
          @rawText={{this.question.question_text}}
        />

        {{#if this.question.options}}
          <ul class="quiz-options-list">
            {{#if this.isMultipleChoice}}
              {{#each this.multipleChoiceResultOptions as |entry|}}
                <li>
                  <label class={{entry.className}}>
                    <input type="checkbox" checked={{entry.checked}} disabled />
                    <QuizCookedText class="quiz-cooked-inline" @rawText={{entry.option}} />
                  </label>
                </li>
              {{/each}}
            {{else}}
              {{#each this.singleChoiceResultOptions as |entry|}}
                <li>
                  <label class={{entry.className}}>
                    <input
                      type="radio"
                      name={{this.radioGroupName}}
                      checked={{entry.checked}}
                      disabled
                    />
                    <QuizCookedText class="quiz-cooked-inline" @rawText={{entry.option}} />
                  </label>
                </li>
              {{/each}}
            {{/if}}
          </ul>
        {{/if}}

        <p class="quiz-question-author">{{this.authorLabel}}</p>

        <div
          class="quiz-result-banner {{if this.result.correct 'is-correct' 'is-incorrect'}}"
        >
          <span class="quiz-result-banner__message">
            {{#if this.result.correct}}
              {{i18n "discourse_quiz.correct"}}
            {{else}}
              <span class="quiz-result-banner__prefix">{{this.incorrectPrefix}}</span>
              {{#if this.isMultipleChoice}}
                <span class="quiz-result-banner__answers">
                  {{#each this.correctOptions as |option index|}}
                    {{#if index}}
                      <span class="quiz-result-banner__separator">、</span>
                    {{/if}}
                    <QuizCookedText class="quiz-result-banner__answer quiz-cooked-inline" @rawText={{option}} />
                  {{/each}}
                </span>
              {{else}}
                <QuizCookedText
                  class="quiz-result-banner__answer quiz-cooked-inline"
                  @rawText={{this.result.correct_option}}
                />
              {{/if}}
            {{/if}}
          </span>
          {{#if this.result.points_awarded}}
            <span class="quiz-points-earned">
              {{i18n "discourse_quiz.points_earned" count=this.result.points_awarded}}
            </span>
          {{/if}}
        </div>

        {{#if this.result.explanation}}
          <div class="quiz-explanation">
            <div class="quiz-explanation-label">{{i18n "discourse_quiz.explanation"}}</div>
            <QuizCookedText
              class="quiz-explanation-text quiz-cooked-block"
              @rawText={{this.result.explanation}}
            />
          </div>
        {{/if}}

        <DButton
          @label="discourse_quiz.next_question"
          @action={{this.nextQuestion}}
          class="btn-primary quiz-next-btn"
        />
      </div>
    {{/if}}
  </template>
}
