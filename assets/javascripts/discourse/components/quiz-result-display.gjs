import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and, eq, not } from "discourse/truth-helpers";
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

  @action
  nextQuestion() {
    this.quiz.loadQuestion();
  }

  <template>
    {{#if this.result}}
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

        {{#if this.question.options}}
          <ul class="quiz-options-list">
            {{#each this.question.options as |option index|}}
              <li>
                <span
                  class="quiz-option-btn is-locked
                    {{if (eq index this.result.correct_index) 'is-correct'}}
                    {{if (and (eq index this.submittedIndex) (not this.result.correct)) 'is-incorrect'}}"
                >
                  {{option}}
                </span>
              </li>
            {{/each}}
          </ul>
        {{/if}}

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
