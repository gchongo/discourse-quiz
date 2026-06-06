import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { eq, not, or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class QuizQuestionEditModal extends Component {
  @tracked categoryName;
  @tracked newCategoryName = "";
  @tracked useNewCategory = false;
  @tracked questionText;
  @tracked optionsText;
  @tracked correctIndex;
  @tracked explanation;
  @tracked active;
  @tracked saveError = null;
  @tracked saving = false;

  constructor() {
    super(...arguments);
    const question = this.args.model.question || {};

    this.categoryName = question.category_name || "";
    this.questionText = question.question_text || "";
    this.optionsText = (question.options || []).join("\n");
    this.correctIndex = question.correct_index ?? 0;
    this.explanation = question.explanation || "";
    this.active = question.active !== false;
    const categories = this.args.model.categories || [];
    const isNew = !question.id;

    if (isNew && !this.categoryName && categories.length) {
      this.categoryName = [...categories].sort((a, b) => a.localeCompare(b, "zh-CN"))[0];
    }

    this.useNewCategory = isNew && !categories.length;
  }

  get isNew() {
    return !this.args.model.question?.id;
  }

  get modalTitle() {
    return i18n(this.isNew ? "discourse_quiz.admin.create_title" : "discourse_quiz.admin.edit_title");
  }

  get parsedOptions() {
    return this.optionsText
      .split(/\r?\n/)
      .map((option) => option.trim())
      .filter(Boolean);
  }

  get baseCategories() {
    return this.args.model.categories || [];
  }

  get categoryOptions() {
    const categories = [...this.baseCategories];
    const current = this.categoryName?.trim();

    if (current && !categories.includes(current)) {
      categories.push(current);
    }

    return categories.sort((a, b) => a.localeCompare(b, "zh-CN"));
  }

  get effectiveCategoryName() {
    if (this.useNewCategory) {
      return this.newCategoryName.trim();
    }

    if (!this.baseCategories.length && !this.categoryName) {
      return this.newCategoryName.trim();
    }

    return this.categoryName?.trim() || "";
  }

  @action
  updateCategory(event) {
    this.categoryName = event.target.value;
    this.useNewCategory = false;
  }

  @action
  enableNewCategory() {
    this.useNewCategory = true;
    this.newCategoryName = "";
  }

  @action
  useExistingCategories() {
    this.useNewCategory = false;
    this.newCategoryName = "";
  }

  @action
  updateNewCategory(event) {
    this.newCategoryName = event.target.value;
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

  questionPayload() {
    return {
      category_name: this.effectiveCategoryName,
      question_text: this.questionText,
      options: this.parsedOptions,
      correct_index: this.correctIndex,
      explanation: this.explanation,
      active: this.active,
    };
  }

  @action
  async saveQuestion() {
    this.saveError = null;
    this.saving = true;

    try {
      if (this.isNew) {
        await ajax("/admin/quiz/questions.json", {
          type: "POST",
          data: { question: this.questionPayload() },
        });
      } else {
        await ajax(`/admin/quiz/questions/${this.args.model.question.id}.json`, {
          type: "PUT",
          data: { question: this.questionPayload() },
        });
      }

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
    <DModal @title={{this.modalTitle}} @closeModal={{@closeModal}}>
      <:body>
        <div class="quiz-admin-form">
          <div class="quiz-admin-form__field">
            <span>{{i18n "discourse_quiz.admin.form.category"}}</span>
            {{#if this.useNewCategory}}
              <input
                type="text"
                value={{this.newCategoryName}}
                placeholder={{i18n "discourse_quiz.admin.form.new_category_placeholder"}}
                {{on "input" this.updateNewCategory}}
              />
              {{#if this.categoryOptions.length}}
                <button type="button" class="btn btn-link quiz-admin-link-btn" {{on "click" this.useExistingCategories}}>
                  {{i18n "discourse_quiz.admin.form.use_existing_categories"}}
                </button>
              {{/if}}
            {{else if this.categoryOptions.length}}
              <select {{on "change" this.updateCategory}}>
                {{#each this.categoryOptions as |category|}}
                  <option value={{category}} selected={{eq this.categoryName category}}>
                    {{category}}
                  </option>
                {{/each}}
              </select>
              <button type="button" class="btn btn-link quiz-admin-link-btn" {{on "click" this.enableNewCategory}}>
                {{i18n "discourse_quiz.admin.form.use_new_category"}}
              </button>
            {{else}}
              <input
                type="text"
                value={{this.newCategoryName}}
                placeholder={{i18n "discourse_quiz.admin.form.new_category_placeholder"}}
                {{on "input" this.updateNewCategory}}
              />
            {{/if}}
          </div>

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
          @disabled={{or this.saving (not this.effectiveCategoryName)}}
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
