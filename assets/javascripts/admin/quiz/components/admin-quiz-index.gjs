import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import DButton from "discourse/ui-kit/d-button";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { eq } from "discourse/truth-helpers";
import QuizQuestionEditModal from "./quiz-question-edit-modal";

const IMPORT_EXAMPLE = `[
  {
    "category_name": "历史",
    "question_text": "中国历史上第一个统一的封建王朝是哪个？",
    "options": ["夏朝", "商朝", "秦朝", "汉朝"],
    "correct_index": 2,
    "explanation": "秦朝是中国历史上第一个统一的中央集权封建王朝。"
  }
]`;

const CSV_EXAMPLE = `category_name,question_text,options,correct_index,explanation,active
历史,中国历史上第一个统一的封建王朝是哪个？,夏朝|商朝|秦朝|汉朝,2,秦朝是中国历史上第一个统一的中央集权封建王朝。,true`;

export default class AdminQuizIndex extends Component {
  @service modal;

  @tracked questions = [];
  @tracked categories = [];
  @tracked selectedCategory = "";
  @tracked importJson = IMPORT_EXAMPLE;
  @tracked importFormat = "json";
  @tracked importResult = null;
  @tracked importErrors = [];
  @tracked loadError = null;
  @tracked loading = true;
  @tracked importing = false;

  constructor() {
    super(...arguments);
    this.loadQuestions();
  }

  @action
  async loadQuestions() {
    this.loading = true;
    this.loadError = null;

    try {
      const url = this.selectedCategory
        ? `/admin/quiz/questions.json?category_name=${encodeURIComponent(this.selectedCategory)}`
        : "/admin/quiz/questions.json";

      const data = await ajax(url);
      this.questions = data.questions || [];
      this.categories = data.categories || [];
      this.loadError = data.error || null;
    } catch (e) {
      this.loadError = e.jqXHR?.responseJSON?.error || null;
      if (!this.loadError) {
        popupAjaxError(e);
      }
    } finally {
      this.loading = false;
    }
  }

  @action
  onCategoryChange(event) {
    this.selectedCategory = event.target.value;
    this.loadQuestions();
  }

  @action
  updateImportJson(event) {
    this.importJson = event.target.value;
    this.importFormat = "json";
  }

  @action
  useJsonExample() {
    this.importJson = IMPORT_EXAMPLE;
    this.importFormat = "json";
  }

  @action
  useCsvExample() {
    this.importJson = CSV_EXAMPLE;
    this.importFormat = "csv";
  }

  @action
  onFileSelected(event) {
    const file = event.target.files?.[0];

    if (!file) {
      return;
    }

    const format = file.name.toLowerCase().endsWith(".csv") ? "csv" : "json";
    const reader = new FileReader();

    reader.onload = (loadEvent) => {
      this.importJson = loadEvent.target.result;
      this.importFormat = format;
      this.importResult = null;
      this.importErrors = [];
    };

    reader.readAsText(file, "UTF-8");
    event.target.value = "";
  }

  @action
  async bulkImport() {
    this.importResult = null;
    this.importErrors = [];
    this.importing = true;

    try {
      const result = await ajax("/admin/quiz/questions/bulk_import.json", {
        type: "POST",
        data: {
          questions_json: this.importJson,
          import_format: this.importFormat,
        },
      });

      this.importResult = result;
      this.importErrors = result.errors || [];
      this.loadQuestions();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.importing = false;
    }
  }

  @action
  editQuestion(question) {
    this.modal.show(QuizQuestionEditModal, {
      model: {
        question,
        categories: this.categories,
        onSaved: () => this.loadQuestions(),
      },
    });
  }

  @action
  async deleteQuestion(id) {
    if (!confirm(i18n("discourse_quiz.admin.confirm_delete"))) {
      return;
    }

    try {
      await ajax(`/admin/quiz/questions/${id}.json`, { type: "DELETE" });
      this.loadQuestions();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <div class="admin-discourse-quiz">
      <h1>{{i18n "discourse_quiz.admin.title"}}</h1>

      <section class="quiz-admin-import">
        <h2>{{i18n "discourse_quiz.admin.import_title"}}</h2>
        <p class="quiz-admin-hint">{{i18n "discourse_quiz.admin.import_hint"}}</p>

        <div class="quiz-admin-import__toolbar">
          <label class="btn btn-default quiz-admin-file-btn">
            {{i18n "discourse_quiz.admin.choose_file"}}
            <input type="file" accept=".json,.csv,text/json,text/csv" hidden {{on "change" this.onFileSelected}} />
          </label>
          <DButton
            @label="discourse_quiz.admin.use_json_example"
            @action={{this.useJsonExample}}
            class="btn-default"
          />
          <DButton
            @label="discourse_quiz.admin.use_csv_example"
            @action={{this.useCsvExample}}
            class="btn-default"
          />
          {{#if this.importFormat}}
            <span class="quiz-admin-import__format">
              {{i18n "discourse_quiz.admin.import_format" format=this.importFormat}}
            </span>
          {{/if}}
        </div>

        <textarea
          class="quiz-import-textarea"
          rows="12"
          value={{this.importJson}}
          {{on "input" this.updateImportJson}}
        ></textarea>

        <DButton
          @label={{if this.importing "discourse_quiz.admin.importing" "discourse_quiz.admin.import_button"}}
          @action={{this.bulkImport}}
          @disabled={{this.importing}}
          class="btn-primary"
        />

        {{#if this.importResult}}
          <p class="quiz-import-result">
            {{i18n
              "discourse_quiz.admin.import_result"
              imported=this.importResult.imported
              total=this.importResult.total
            }}
          </p>
        {{/if}}

        {{#if this.importErrors.length}}
          <table class="quiz-import-errors table">
            <thead>
              <tr>
                <th>{{i18n "discourse_quiz.admin.import_error_row"}}</th>
                <th>{{i18n "discourse_quiz.admin.import_error_messages"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each this.importErrors as |error|}}
                <tr>
                  <td>{{error.row}}</td>
                  <td>
                    {{#each error.messages as |message|}}
                      <div>{{message}}</div>
                    {{/each}}
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{/if}}
      </section>

      <section class="quiz-admin-list">
        {{#if this.loadError}}
          <p class="quiz-admin-error">{{this.loadError}}</p>
        {{/if}}

        <div class="quiz-admin-filters">
          <label>
            {{i18n "discourse_quiz.admin.category_filter"}}
            <select {{on "change" this.onCategoryChange}}>
              <option value="" selected={{eq this.selectedCategory ""}}>
                {{i18n "discourse_quiz.admin.all_categories"}}
              </option>
              {{#each this.categories as |category|}}
                <option value={{category}} selected={{eq this.selectedCategory category}}>
                  {{category}}
                </option>
              {{/each}}
            </select>
          </label>
        </div>

        <table class="quiz-questions-table table">
          <thead>
            <tr>
              <th>{{i18n "discourse_quiz.admin.table.category"}}</th>
              <th>{{i18n "discourse_quiz.admin.table.question"}}</th>
              <th>{{i18n "discourse_quiz.admin.table.active"}}</th>
              <th>{{i18n "discourse_quiz.admin.table.actions"}}</th>
            </tr>
          </thead>
          <tbody>
            {{#each this.questions as |question|}}
              <tr>
                <td>{{question.category_name}}</td>
                <td>{{question.question_text}}</td>
                <td>{{if question.active (i18n "discourse_quiz.admin.yes") (i18n "discourse_quiz.admin.no")}}</td>
                <td class="quiz-admin-actions">
                  <DButton
                    @icon="pencil"
                    @action={{fn this.editQuestion question}}
                    @title="discourse_quiz.admin.edit"
                    class="btn-default btn-small"
                  />
                  <DButton
                    @icon="trash-can"
                    @action={{fn this.deleteQuestion question.id}}
                    class="btn-danger btn-small"
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </section>
    </div>
  </template>
}
