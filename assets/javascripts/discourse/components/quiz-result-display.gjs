import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import DButton from "discourse/ui-kit/d-button";

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

  get incorrectMessage() {
    if (this.result.correct) {
      return null;
    }

    if (this.isMultipleChoice) {
      return i18n("discourse_quiz.incorrect_multiple", {
        answers: (this.result.correct_options || []).join("、"),
      });
    }

    return i18n("discourse_quiz.incorrect", { answer: this.result.correct_option });
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
        {{#if this.quiz.isLearningOnly}}
          <p class="quiz-learning-notice">{{i18n "discourse_quiz.learning_only"}}</p>
        {{/if}}

        <div class="quiz-question-type">{{this.questionTypeLabel}}</div>
        <div class="quiz-question-category">{{this.question.category_name}}</div>
        <div class="quiz-question-text">{{this.question.question_text}}</div>

        {{#if this.question.options}}
          <ul class="quiz-options-list">
            {{#if this.isMultipleChoice}}
              {{#each this.multipleChoiceResultOptions as |entry|}}
                <li>
                  <label class={{entry.className}}>
                    <input type="checkbox" checked={{entry.checked}} disabled />
                    <span>{{entry.option}}</span>
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
                    <span>{{entry.option}}</span>
                  </label>
                </li>
              {{/each}}
            {{/if}}
          </ul>
        {{/if}}

        <div
          class="quiz-result-banner {{if this.result.correct 'is-correct' 'is-incorrect'}}"
        >
          <span class="quiz-result-banner__message">
            {{#if this.result.correct}}
              {{i18n "discourse_quiz.correct"}}
            {{else}}
              {{this.incorrectMessage}}
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
            <div class="quiz-explanation-text">{{this.result.explanation}}</div>
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
