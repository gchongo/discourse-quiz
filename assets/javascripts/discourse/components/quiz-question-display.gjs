import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";

export default class QuizQuestionDisplay extends Component {
  @tracked selectedIndex = null;

  @action
  selectOption(index) {
    if (this.args.disabled) return;
    this.selectedIndex = index;
  }

  @action
  submit() {
    if (this.selectedIndex !== null) {
      this.args.onSubmit(this.selectedIndex);
    }
  }

  get isSubmitDisabled() {
    return this.selectedIndex === null || this.args.disabled;
  }

  isSelected(index) {
    return this.selectedIndex === index;
  }

  <template>
    <div class="quiz-question-display">
      <div class="quiz-question-text">
        {{trustHTML @question.question_text}}
      </div>

      <div class="quiz-options-list">
        {{#each @question.options as |option index|}}
          <label class="quiz-option-item {{if (this.isSelected index) 'is-selected'}} {{if @disabled 'is-disabled'}}">
            <input
              type="radio"
              name="quiz-option"
              checked={{this.isSelected index}}
              disabled={{@disabled}}
              {{on "change" (fn this.selectOption index)}}
            />
            <span class="option-text">{{option}}</span>
          </label>
        {{/each}}
      </div>

      <div class="quiz-actions">
        <button
          class="btn btn-primary quiz-submit-btn"
          disabled={{this.isSubmitDisabled}}
          {{on "click" this.submit}}
        >
          {{i18n "gamified_quiz.submit"}}
        </button>
      </div>
    </div>
  </template>
}
