import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class QuizQuestionDisplay extends Component {
  @tracked selectedIndex = null;

  get question() {
    return this.args.question;
  }

  @action
  selectOption(index) {
    this.selectedIndex = index;
  }

  <template>
    <div class="quiz-question-display">
      <div class="quiz-question-category">{{this.question.category_name}}</div>
      <div class="quiz-question-text">{{this.question.question_text}}</div>

      <ul class="quiz-options-list">
        {{#each this.question.options as |option index|}}
          <li>
            <button
              type="button"
              class="quiz-option-btn {{if (eq this.selectedIndex index) 'is-selected'}}"
              {{on "click" (fn this.selectOption index)}}
            >
              {{option}}
            </button>
          </li>
        {{/each}}
      </ul>

      <p class="quiz-submit-hint">{{i18n "discourse_quiz.submit_coming_soon"}}</p>
    </div>
  </template>
}
