import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class QuizQuestionEditModal extends Component {
  @tracked categoryName;
  @tracked questionText;
  @tracked optionsText;
  @tracked correctIndex;
  @tracked explanation;
  @tracked active;
  @tracked saveError = null;
  @tracked saving = false;

  constructor() {
    super(...arguments);
    const question = this.args.model.question;

    this.categoryName = question.category_name || "";
    this.questionText = question.question_text || "";
    this.optionsText = (question.options || []).join("\n");
    this.correctIndex = question.correct_index ?? 0;
    this.explanation = question.explanation || "";
    this.active = question.active !== false;
  }

  get parsedOptions() {
    return this.optionsText
      .split(/\r?\n/)
      .map((option) => option.trim())
      .filter(Boolean);
  }

  @action
  updateCategory(event) {
    this.categoryName = event.target.value;
  }

  @action
  updateQuestionText(event) {
    this.questionText = event.target.value;
  }

  @action
  updateOptionsText(event) {
    this.optionsText = event.target.value;

    if (this.correctIndex >= this.parsedOptions.length) {
      this.correctIndex = Math.max(0, this.parsedOptions.length - 1);
    }
  }

  @action
  selectCorrectIndex(index) {
    this.correctIndex = index;
  }

  @action
  updateExplanation(event) {
    this.explanation = event.target.value;
  }

  @action
  toggleActive(event) {
    this.active = event.target.checked;
  }

  @action
  async saveQuestion() {
    this.saveError = null;
    this.saving = true;

    try {
      await ajax(`/admin/quiz/questions/${this.args.model.question.id}.json`, {
        type: "PUT",
        data: {
          question: {
            category_name: this.categoryName,
            question_text: this.questionText,
            options: this.parsedOptions,
            correct_index: this.correctIndex,
            explanation: this.explanation,
            active: this.active,
          },
        },
      });

      await this.args.model.onSaved?.();
      this.args.closeModal();
    } catch (e) {
      this.saveError =
        e?.jqXHR?.responseJSON?.errors?.join(", ") ||
        e?.jqXHR?.responseJSON?.error ||
        i18n("discourse_quiz.admin.save_error");
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal @title={{i18n "discourse_quiz.admin.edit_title"}} @closeModal={{@closeModal}}>
      <:body>
        <div class="quiz-admin-form">
          <label class="quiz-admin-form__field">
            <span>{{i18n "discourse_quiz.admin.form.category"}}</span>
            <input type="text" value={{this.categoryName}} {{on "input" this.updateCategory}} />
          </label>

          <label class="quiz-admin-form__field">
            <span>{{i18n "discourse_quiz.admin.form.question"}}</span>
            <textarea rows="3" value={{this.questionText}} {{on "input" this.updateQuestionText}}></textarea>
          </label>

          <label class="quiz-admin-form__field">
            <span>{{i18n "discourse_quiz.admin.form.options"}}</span>
            <textarea rows="5" value={{this.optionsText}} {{on "input" this.updateOptionsText}}></textarea>
          </label>

          {{#if this.parsedOptions.length}}
            <fieldset class="quiz-admin-form__field">
              <legend>{{i18n "discourse_quiz.admin.form.correct_answer"}}</legend>
              {{#each this.parsedOptions as |option index|}}
                <label class="quiz-admin-form__radio">
                  <input
                    type="radio"
                    name="quiz-correct-index"
                    checked={{eq this.correctIndex index}}
                    {{on "change" (fn this.selectCorrectIndex index)}}
                  />
                  <span>{{option}}</span>
                </label>
              {{/each}}
            </fieldset>
          {{/if}}

          <label class="quiz-admin-form__field">
            <span>{{i18n "discourse_quiz.admin.form.explanation"}}</span>
            <textarea rows="3" value={{this.explanation}} {{on "input" this.updateExplanation}}></textarea>
          </label>

          <label class="quiz-admin-form__checkbox">
            <input type="checkbox" checked={{this.active}} {{on "change" this.toggleActive}} />
            <span>{{i18n "discourse_quiz.admin.form.active"}}</span>
          </label>

          {{#if this.saveError}}
            <p class="quiz-admin-error">{{this.saveError}}</p>
          {{/if}}
        </div>
      </:body>
      <:footer>
        <DButton @label="cancel" @action={{@closeModal}} class="btn-default" />
        <DButton
          @label={{if this.saving "discourse_quiz.admin.saving" "discourse_quiz.admin.save"}}
          @action={{this.saveQuestion}}
          @disabled={{this.saving}}
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
