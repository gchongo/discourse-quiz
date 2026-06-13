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
import DCookText from "discourse/ui-kit/d-cook-text";

export default class QuizQuestionEditModal extends Component {
  @tracked categoryName;
  @tracked newCategoryName = "";
  @tracked useNewCategory = false;
  @tracked questionText;
  @tracked questionType = "single_choice";
  @tracked optionsText;
  @tracked correctIndex;
  @tracked correctIndices = [];
  @tracked explanation;
  @tracked active;
  @tracked saveError = null;
  @tracked saving = false;

  constructor() {
    super(...arguments);
    const question = this.args.model.question || {};

    this.categoryName = question.category_name || "";
    this.questionText = question.question_text || "";
    this.questionType = question.question_type || "single_choice";
    this.optionsText = (question.options || []).join("\n");
    this.correctIndex = question.correct_index ?? 0;
    this.correctIndices = Array.isArray(question.correct_indices)
      ? question.correct_indices.map((value) => Number(value)).filter((value) => Number.isFinite(value))
      : [];
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

  get isTrueFalse() {
    return this.questionType === "true_false";
  }

  get isMultipleChoice() {
    return this.questionType === "multiple_choice";
  }

  get showOptionsEditor() {
    return !this.isTrueFalse;
  }

  get trueFalseOptions() {
    return [i18n("discourse_quiz.true_false.true"), i18n("discourse_quiz.true_false.false")];
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

  get normalizedCorrectIndices() {
    return Array.isArray(this.correctIndices) ? this.correctIndices : [];
  }

  get multipleChoiceAnswerOptions() {
    const selected = new Set(this.normalizedCorrectIndices);

    return this.parsedOptions.map((option, index) => ({
      option,
      index,
      selected: selected.has(index),
    }));
  }

  get singleChoiceAnswerOptions() {
    return this.parsedOptions.map((option, index) => ({
      option,
      index,
      selected: this.correctIndex === index,
    }));
  }

  get trueFalseAnswerOptions() {
    return this.trueFalseOptions.map((option, index) => ({
      option,
      index,
      selected: this.correctIndex === index,
    }));
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
  updateQuestionType(event) {
    this.questionType = event.target.value;

    if (this.isTrueFalse) {
      this.correctIndex = 0;
      this.correctIndices = [];
    } else if (this.isMultipleChoice) {
      this.correctIndices = this.normalizedCorrectIndices.filter(
        (index) => index >= 0 && index < this.parsedOptions.length
      );
    } else {
      this.correctIndices = [];
      if (this.correctIndex >= this.parsedOptions.length) {
        this.correctIndex = Math.max(0, this.parsedOptions.length - 1);
      }
    }
  }

  @action
  updateOptionsText(event) {
    this.optionsText = event.target.value;

    if (this.correctIndex >= this.parsedOptions.length) {
      this.correctIndex = Math.max(0, this.parsedOptions.length - 1);
    }

    this.correctIndices = this.normalizedCorrectIndices.filter(
      (index) => index >= 0 && index < this.parsedOptions.length
    );
  }

  @action
  selectCorrectIndex(index) {
    this.correctIndex = index;
  }

  @action
  toggleCorrectIndex(index) {
    const current = this.normalizedCorrectIndices;

    if (current.includes(index)) {
      this.correctIndices = current.filter((value) => value !== index);
    } else {
      this.correctIndices = [...current, index].sort((a, b) => a - b);
    }
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
      question_type: this.questionType,
      options: this.isTrueFalse ? this.trueFalseOptions : this.parsedOptions,
      correct_index: this.correctIndex,
      correct_indices: this.isMultipleChoice ? this.normalizedCorrectIndices : [],
      explanation: this.explanation,
      active: this.active,
    };
  }

  @action
  async saveQuestion() {
    this.saveError = null;
    this.saving = true;

    try {
      let result;

      if (this.isNew) {
        result = await ajax("/admin/quiz/questions.json", {
          type: "POST",
          data: { question: this.questionPayload() },
        });
      } else {
        result = await ajax(`/admin/quiz/questions/${this.args.model.question.id}.json`, {
          type: "PUT",
          data: { question: this.questionPayload() },
        });
      }

      await this.args.model.onSaved?.(result.duplicate_warning);
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
              <div class="quiz-admin-form__category-row">
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
              </div>
            {{else if this.categoryOptions.length}}
              <div class="quiz-admin-form__category-row">
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
              </div>
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
            <span>{{i18n "discourse_quiz.admin.form.question_type"}}</span>
            <select {{on "change" this.updateQuestionType}}>
              <option value="single_choice" selected={{eq this.questionType "single_choice"}}>
                {{i18n "discourse_quiz.admin.form.question_types.single_choice"}}
              </option>
              <option value="true_false" selected={{eq this.questionType "true_false"}}>
                {{i18n "discourse_quiz.admin.form.question_types.true_false"}}
              </option>
              <option value="multiple_choice" selected={{eq this.questionType "multiple_choice"}}>
                {{i18n "discourse_quiz.admin.form.question_types.multiple_choice"}}
              </option>
            </select>
          </label>

          <label class="quiz-admin-form__field">
            <span>{{i18n "discourse_quiz.admin.form.question"}}</span>
            <textarea rows="3" value={{this.questionText}} {{on "input" this.updateQuestionText}}></textarea>
          </label>

          {{#if this.showOptionsEditor}}
            <label class="quiz-admin-form__field">
              <span>{{i18n "discourse_quiz.admin.form.options"}}</span>
              <textarea rows="5" value={{this.optionsText}} {{on "input" this.updateOptionsText}}></textarea>
            </label>
          {{/if}}

          {{#if this.isTrueFalse}}
            <div class="quiz-admin-form__field">
              <span>{{i18n "discourse_quiz.admin.form.correct_answer"}}</span>
              <p class="quiz-admin-form__hint">
                {{i18n "discourse_quiz.admin.form.correct_answer_hint"}}
              </p>
              <div class="quiz-admin-form__answers">
                {{#each this.trueFalseAnswerOptions as |entry|}}
                  <button
                    type="button"
                    class="btn btn-default quiz-admin-answer-btn {{if entry.selected 'is-selected'}}"
                    {{on "click" (fn this.selectCorrectIndex entry.index)}}
                  >
                    <DCookText class="quiz-cooked-inline" @rawText={{entry.option}} />
                  </button>
                {{/each}}
              </div>
            </div>
          {{else if this.isMultipleChoice}}
            <div class="quiz-admin-form__field">
              <span>{{i18n "discourse_quiz.admin.form.correct_answers"}}</span>
              {{#if this.parsedOptions.length}}
                <p class="quiz-admin-form__hint">
                  {{i18n "discourse_quiz.admin.form.correct_answers_hint"}}
                </p>
                <div class="quiz-admin-form__answers">
                  {{#each this.multipleChoiceAnswerOptions as |entry|}}
                    <button
                      type="button"
                      class="btn btn-default quiz-admin-answer-btn {{if entry.selected 'is-selected'}}"
                      {{on "click" (fn this.toggleCorrectIndex entry.index)}}
                    >
                      <DCookText class="quiz-cooked-inline" @rawText={{entry.option}} />
                    </button>
                  {{/each}}
                </div>
              {{else}}
                <p class="quiz-admin-form__hint">
                  {{i18n "discourse_quiz.admin.form.correct_answers_need_options"}}
                </p>
              {{/if}}
            </div>
          {{else if this.parsedOptions.length}}
            <div class="quiz-admin-form__field">
              <span>{{i18n "discourse_quiz.admin.form.correct_answer"}}</span>
              <p class="quiz-admin-form__hint">
                {{i18n "discourse_quiz.admin.form.correct_answer_hint"}}
              </p>
              <div class="quiz-admin-form__answers">
                {{#each this.singleChoiceAnswerOptions as |entry|}}
                  <button
                    type="button"
                    class="btn btn-default quiz-admin-answer-btn {{if entry.selected 'is-selected'}}"
                    {{on "click" (fn this.selectCorrectIndex entry.index)}}
                  >
                    <DCookText class="quiz-cooked-inline" @rawText={{entry.option}} />
                  </button>
                {{/each}}
              </div>
            </div>
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
