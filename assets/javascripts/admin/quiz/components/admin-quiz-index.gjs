import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import dButton from "discourse/components/d-button";
import { fn } from "@ember/helper";
import AdminQuizRow from "discourse/plugins/discourse-quiz/admin/quiz/components/admin-quiz-row";
import AdminQuizEdit from "discourse/plugins/discourse-quiz/admin/quiz/components/admin-quiz-edit";

export default class AdminQuizIndex extends Component {
  @tracked questions = [];
  @tracked stats = null;
  @tracked auditData = null;
  @tracked editingQuestion = null;
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.loadData();
  }

  async loadData() {
    this.loading = true;
    try {
      const [questions, stats] = await Promise.all([
        ajax("/admin/quiz/questions.json"),
        ajax("/admin/quiz/stats.json"),
      ]);
      this.questions = questions.questions;
      this.stats = stats;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  editQuestion(question) {
    this.editingQuestion = question || {
      category_name: "",
      question_text: "",
      options: [],
      correct_index: 0,
      active: true
    };
  }

  @action
  cancelEdit() {
    this.editingQuestion = null;
  }

  @action
  async saveQuestion(questionData) {
    const isNew = !questionData.id;
    const url = isNew
      ? "/admin/quiz/questions.json"
      : `/admin/quiz/questions/${questionData.id}.json`;

    try {
      await ajax(url, {
        type: isNew ? "POST" : "PUT",
        data: { question: questionData },
      });
      this.editingQuestion = null;
      this.loadData();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async loadAudit() {
    try {
      this.auditData = await ajax("/admin/quiz/audit.json");
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async deleteQuestion(id) {
    if (confirm(i18n("admin.gamified_quiz.confirm_delete"))) {
      try {
        await ajax(`/admin/quiz/questions/${id}.json`, { type: "DELETE" });
        this.loadData();
      } catch (e) {
        popupAjaxError(e);
      }
    }
  }

  <template>
    <div class="admin-gamified-quiz">
      <h1>{{i18n "admin.gamified_quiz.title"}}</h1>

      {{#if this.stats}}
        <div class="quiz-stats-cards">
          <div class="stats-card">
            <span class="label">{{i18n "admin.gamified_quiz.stats.total_questions"}}</span>
            <span class="value">{{this.stats.total_questions}}</span>
          </div>
          <div class="stats-card">
            <span class="label">{{i18n "admin.gamified_quiz.stats.active_questions"}}</span>
            <span class="value">{{this.stats.active_questions}}</span>
          </div>
          <div class="stats-card">
            <span class="label">{{i18n "admin.gamified_quiz.stats.total_attempts"}}</span>
            <span class="value">{{this.stats.total_attempts}}</span>
          </div>
        </div>
      {{/if}}

      <div class="admin-actions">
        <dButton
          @icon="plus"
          @label="admin.gamified_quiz.form.create"
          @action={{fn this.editQuestion null}}
          class="btn-primary"
        />
        <dButton
          @icon="shield-alt"
          @label="admin.gamified_quiz.audit.refresh"
          @action={{this.loadAudit}}
          class="btn-default"
        />
      </div>

      {{#if this.auditData}}
        <p class="audit-summary">
          {{i18n "admin.gamified_quiz.audit.last_checked"}}:
          {{this.auditData.audited_at}}
        </p>
      {{/if}}

      {{#if this.editingQuestion}}
        <AdminQuizEdit
          @question={{this.editingQuestion}}
          @onSave={{this.saveQuestion}}
          @onCancel={{this.cancelEdit}}
        />
      {{/if}}

      <table class="quiz-questions-table table">
        <thead>
          <tr>
            <th>{{i18n "admin.gamified_quiz.table.question"}}</th>
            <th>{{i18n "admin.gamified_quiz.table.category"}}</th>
            <th>{{i18n "admin.gamified_quiz.table.active"}}</th>
            <th>{{i18n "admin.gamified_quiz.table.audit"}}</th>
            <th>{{i18n "admin.gamified_quiz.table.actions"}}</th>
          </tr>
        </thead>
        <tbody>
          {{#each this.questions as |q|}}
            <AdminQuizRow
              @question={{q}}
              @onEdit={{fn this.editQuestion q}}
              @onDelete={{fn this.deleteQuestion q.id}}
            />
          {{/each}}
        </tbody>
      </table>
    </div>
  </template>
}
