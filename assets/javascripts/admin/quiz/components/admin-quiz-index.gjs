import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import DButton from "discourse/ui-kit/d-button";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { eq } from "discourse/truth-helpers";

const IMPORT_EXAMPLE = `[
  {
    "category_name": "历史",
    "question_text": "中国历史上第一个统一的封建王朝是哪个？",
    "options": ["夏朝", "商朝", "秦朝", "汉朝"],
    "correct_index": 2,
    "explanation": "秦朝是中国历史上第一个统一的中央集权封建王朝。"
  }
]`;

export default class AdminQuizIndex extends Component {
  @tracked questions = [];
  @tracked categories = [];
  @tracked selectedCategory = "";
  @tracked importJson = IMPORT_EXAMPLE;
  @tracked importResult = null;
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.loadQuestions();
  }

  @action
  async loadQuestions() {
    this.loading = true;
    try {
      const url = this.selectedCategory
        ? `/admin/quiz/questions.json?category_name=${encodeURIComponent(this.selectedCategory)}`
        : "/admin/quiz/questions.json";

      const data = await ajax(url);
      this.questions = data.questions || [];
      this.categories = data.categories || [];
    } catch (e) {
      popupAjaxError(e);
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
  }

  @action
  async bulkImport() {
    this.importResult = null;
    try {
      const result = await ajax("/admin/quiz/questions/bulk_import.json", {
        type: "POST",
        data: { questions_json: this.importJson },
      });
      this.importResult = result;
      this.loadQuestions();
    } catch (e) {
      popupAjaxError(e);
    }
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
        <textarea
          class="quiz-import-textarea"
          rows="12"
          value={{this.importJson}}
          {{on "input" this.updateImportJson}}
        ></textarea>
        <DButton
          @label="discourse_quiz.admin.import_button"
          @action={{this.bulkImport}}
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
      </section>

      <section class="quiz-admin-list">
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
                <td>
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
