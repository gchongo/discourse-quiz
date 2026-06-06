import Component from "@glimmer/component";
import { service } from "@ember/service";
import { fn } from "@ember/helper";
import { eq } from "discourse/truth-helpers";
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

  get submittedIndex() {
    return this.quiz.submittedAnswerIndex;
  }

  optionClass(index) {
    const classes = ["quiz-option-btn", "is-locked"];

    if (index === this.result.correct_index) {
      classes.push("is-correct");
    } else if (index === this.submittedIndex && !this.result.correct) {
      classes.push("is-incorrect");
    }

    return classes.join(" ");
  }

  <template>
    <div class="quiz-result-display">
      <div
        class="quiz-result-banner {{if this.result.correct 'is-correct' 'is-incorrect'}}"
      >
        {{#if this.result.correct}}
          {{i18n "discourse_quiz.correct"}}
        {{else}}
          {{i18n "discourse_quiz.incorrect" answer=this.result.correct_option}}
        {{/if}}
      </div>

      <ul class="quiz-options-list">
        {{#each this.question.options as |option index|}}
          <li>
            <span class={{this.optionClass index}}>
              {{option}}
            </span>
          </li>
        {{/each}}
      </ul>

      {{#if this.result.explanation}}
        <div class="quiz-explanation">
          <div class="quiz-explanation-label">{{i18n "discourse_quiz.explanation"}}</div>
          <div class="quiz-explanation-text">{{this.result.explanation}}</div>
        </div>
      {{/if}}

      <DButton
        @label="discourse_quiz.next_question"
        @action={{fn this.quiz.loadQuestion}}
        class="btn-primary quiz-next-btn"
      />
    </div>
  </template>
}
