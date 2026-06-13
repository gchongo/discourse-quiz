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
import { eq, not, or } from "discourse/truth-helpers";
import QuizQuestionEditModal from "./quiz-question-edit-modal";

const IMPORT_EXAMPLE = `[
  {
    "category_name": "历史",
    "question_text": "中国历史上第一个统一的封建王朝是哪个？",
    "question_type": "single_choice",
    "options": ["夏朝", "商朝", "秦朝", "汉朝"],
    "correct_index": 2,
    "explanation": "秦朝是中国历史上第一个统一的中央集权封建王朝。"
  },
  {
    "category_name": "历史",
    "question_text": "秦朝只存在了 15 年。",
    "question_type": "true_false",
    "correct_index": 0,
    "explanation": "对。"
  },
  {
    "category_name": "历史",
    "question_text": "下列哪些属于战国七雄？",
    "question_type": "multiple_choice",
    "options": ["齐", "晋", "秦", "楚"],
    "correct_indices": [0, 2, 3],
    "explanation": "战国七雄不含晋。"
  }
]`;

const CSV_EXAMPLE = `id,category_name,question_text,question_type,options,correct_index,correct_indices,explanation,active
,历史,中国历史上第一个统一的封建王朝是哪个？,single_choice,夏朝|商朝|秦朝|汉朝,2,,秦朝是中国历史上第一个统一的中央集权封建王朝。,true
,历史,秦朝只存在了 15 年。,true_false,,0,,对。,true
,历史,下列哪些属于战国七雄？,multiple_choice,齐|晋|秦|楚,,0|2|3,战国七雄不含晋。,true`;

const PER_PAGE = 25;

export default class AdminQuizIndex extends Component {
  @service modal;

  @tracked questions = [];
  @tracked categories = [];
  @tracked selectedCategory = "";
  @tracked selectedQuestionType = "";
  @tracked searchQuery = "";
  @tracked page = 1;
  @tracked total = 0;
  @tracked importJson = IMPORT_EXAMPLE;
  @tracked importFormat = "json";
  @tracked dryRun = false;
  @tracked upsert = false;
  @tracked importResult = null;
  @tracked importErrors = [];
  @tracked importWarnings = [];
  @tracked duplicateSummary = null;
  @tracked saveDuplicateWarning = null;
  @tracked loadError = null;
  @tracked loading = true;
  @tracked importing = false;
  @tracked exporting = false;
  @tracked renameFrom = "";
  @tracked renameTo = "";
  @tracked renaming = false;
  @tracked renameResult = null;
  @tracked disablingDuplicates = false;
  @tracked duplicateDisableResult = null;
  @tracked submissions = [];
  @tracked submissionsLoading = false;
  @tracked submissionStatusFilter = "pending";
  @tracked reviewBusyId = null;

  constructor() {
    super(...arguments);
    this.loadQuestions();
    this.loadSubmissions();
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.total / PER_PAGE));
  }

  get canGoPrev() {
    return this.page > 1;
  }

  get canGoNext() {
    return this.page < this.totalPages;
  }

  get saveDuplicateWarningIds() {
    return (this.saveDuplicateWarning?.duplicate_ids || []).join(", ");
  }

  duplicateIdsLabel(ids) {
    return (ids || []).join(", ");
  }

  imageLabelPreview(rawText) {
    return (rawText || "").replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (_match, altText) => {
      const label = (altText || "").trim();
      return label || i18n("discourse_quiz.admin.image_placeholder");
    });
  }

  @action
  async bulkDisableDuplicates() {
    if (!confirm(i18n("discourse_quiz.admin.duplicate_disable_confirm"))) {
      return;
    }

    this.disablingDuplicates = true;
    this.duplicateDisableResult = null;

    try {
      const result = await ajax("/admin/quiz/questions/bulk_disable_duplicates.json", {
        type: "POST",
      });
      this.duplicateDisableResult = result;
      this.loadQuestions();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.disablingDuplicates = false;
    }
  }

  buildSubmissionsUrl() {
    const params = new URLSearchParams();
    if (this.submissionStatusFilter) {
      params.set("status", this.submissionStatusFilter);
    }

    return `/admin/quiz/question_submissions.json?${params.toString()}`;
  }

  @action
  async loadSubmissions() {
    this.submissionsLoading = true;

    try {
      const data = await ajax(this.buildSubmissionsUrl());
      this.submissions = (data.submissions || []).map((submission) => ({
        ...submission,
        review_note_draft: submission.review_note || "",
      }));
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.submissionsLoading = false;
    }
  }

  @action
  onSubmissionStatusFilterChange(event) {
    this.submissionStatusFilter = event.target.value;
    this.loadSubmissions();
  }

  @action
  onSubmissionReviewNoteInput(submission, event) {
    const value = event.target.value;
    this.submissions = this.submissions.map((item) =>
      item.id === submission.id
        ? {
            ...item,
            review_note_draft: value,
          }
        : item
    );
  }

  @action
  async reviewSubmission(submission, reviewAction) {
    this.reviewBusyId = submission.id;

    try {
      await ajax(`/admin/quiz/question_submissions/${submission.id}.json`, {
        type: "PUT",
        data: {
          review_action: reviewAction,
          review_note: submission.review_note_draft,
        },
      });
      this.loadSubmissions();
      this.loadQuestions();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.reviewBusyId = null;
    }
  }

  buildListUrl() {
    const params = new URLSearchParams();
    params.set("page", String(this.page));
    params.set("per_page", String(PER_PAGE));

    if (this.selectedCategory) {
      params.set("category_name", this.selectedCategory);
    }

    if (this.selectedQuestionType) {
      params.set("question_type", this.selectedQuestionType);
    }

    if (this.searchQuery.trim()) {
      params.set("q", this.searchQuery.trim());
    }

    return `/admin/quiz/questions.json?${params.toString()}`;
  }

  buildExportUrl(format) {
    const params = new URLSearchParams();
    params.set("export_format", format);

    if (this.selectedCategory) {
      params.set("category_name", this.selectedCategory);
    }

    if (this.selectedQuestionType) {
      params.set("question_type", this.selectedQuestionType);
    }

    if (this.searchQuery.trim()) {
      params.set("q", this.searchQuery.trim());
    }

    return `/admin/quiz/questions/export.json?${params.toString()}`;
  }

  @action
  async loadQuestions() {
    this.loading = true;
    this.loadError = null;

    try {
      const data = await ajax(this.buildListUrl());
      this.questions = data.questions || [];
      this.categories = data.categories || [];
      this.duplicateSummary = data.duplicate_summary || null;
      this.total = data.total || 0;
      this.page = data.page || this.page;
      this.loadError = data.error || null;
      if (this.loadError) {
        this.duplicateSummary = null;
      }
    } catch (e) {
      this.loadError = e.jqXHR?.responseJSON?.error || null;
      this.duplicateSummary = null;
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
    this.page = 1;
    this.loadQuestions();
  }

  @action
  onQuestionTypeChange(event) {
    this.selectedQuestionType = event.target.value;
    this.page = 1;
    this.loadQuestions();
  }

  @action
  onSearchInput(event) {
    this.searchQuery = event.target.value;
  }

  @action
  applySearch() {
    this.page = 1;
    this.loadQuestions();
  }

  @action
  clearSearch() {
    this.searchQuery = "";
    this.page = 1;
    this.loadQuestions();
  }

  @action
  goPrevPage() {
    if (!this.canGoPrev) {
      return;
    }

    this.page -= 1;
    this.loadQuestions();
  }

  @action
  goNextPage() {
    if (!this.canGoNext) {
      return;
    }

    this.page += 1;
    this.loadQuestions();
  }

  @action
  updateImportJson(event) {
    this.importJson = event.target.value;
    this.importFormat = "json";
  }

  @action
  toggleDryRun(event) {
    this.dryRun = event.target.checked;
  }

  @action
  toggleUpsert(event) {
    this.upsert = event.target.checked;
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
    this.importWarnings = [];
    this.importing = true;

    try {
      const result = await ajax("/admin/quiz/questions/bulk_import.json", {
        type: "POST",
        data: {
          questions_json: this.importJson,
          import_format: this.importFormat,
          dry_run: this.dryRun,
          upsert: this.upsert,
        },
      });

      this.importResult = result;
      this.importErrors = result.errors || [];
      this.importWarnings = result.warnings || [];

      if (!this.dryRun) {
        this.loadQuestions();
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.importing = false;
    }
  }

  downloadFile(filename, content, mimeType) {
    const blob = new Blob([content], { type: mimeType });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = filename;
    link.click();
    URL.revokeObjectURL(url);
  }

  @action
  async exportQuestions(format) {
    this.exporting = true;

    try {
      const result = await ajax(this.buildExportUrl(format));

      if (format === "csv") {
        this.downloadFile("discourse-quiz-questions.csv", result.data, "text/csv;charset=utf-8");
      } else {
        const content = JSON.stringify(result.data, null, 2);
        this.downloadFile("discourse-quiz-questions.json", content, "application/json;charset=utf-8");
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.exporting = false;
    }
  }

  openQuestionModal(question) {
    this.saveDuplicateWarning = null;

    this.modal.show(QuizQuestionEditModal, {
      model: {
        question,
        categories: this.categories,
        onSaved: (duplicateWarning) => {
          this.saveDuplicateWarning = duplicateWarning || null;
          this.loadQuestions();
        },
      },
    });
  }

  @action
  createQuestion() {
    this.openQuestionModal({});
  }

  @action
  editQuestion(question) {
    this.openQuestionModal(question);
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

  @action
  onRenameFromChange(event) {
    this.renameFrom = event.target.value;
  }

  @action
  onRenameToChange(event) {
    this.renameTo = event.target.value;
  }

  @action
  async renameCategory() {
    this.renameResult = null;
    this.renaming = true;

    try {
      const result = await ajax("/admin/quiz/categories/rename.json", {
        type: "PUT",
        data: {
          from_name: this.renameFrom,
          to_name: this.renameTo,
        },
      });

      this.renameResult = result;
      this.renameFrom = "";
      this.renameTo = "";
      this.loadQuestions();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.renaming = false;
    }
  }

  <template>
    <div class="admin-discourse-quiz">
      <section class="quiz-admin-list">
        {{#if this.loadError}}
          <p class="quiz-admin-error">{{this.loadError}}</p>
        {{/if}}

        {{#if this.saveDuplicateWarning}}
          <p class="quiz-admin-warning">
            {{i18n
              "discourse_quiz.admin.duplicate_save_warning"
              ids=this.saveDuplicateWarningIds
            }}
          </p>
        {{/if}}

        {{#if this.duplicateSummary.duplicate_group_count}}
          <p class="quiz-admin-warning">
            {{i18n
              "discourse_quiz.admin.duplicate_summary"
              group_count=this.duplicateSummary.duplicate_group_count
              question_count=this.duplicateSummary.duplicate_question_count
            }}
          </p>
        {{/if}}

        {{#if this.duplicateDisableResult}}
          <p class="quiz-import-result">
            {{i18n
              "discourse_quiz.admin.duplicate_disable_result"
              disabled=this.duplicateDisableResult.disabled
              kept=this.duplicateDisableResult.kept_count
            }}
          </p>
        {{/if}}

        <div class="quiz-admin-list__toolbar">
          <DButton
            @label="discourse_quiz.admin.create_button"
            @action={{this.createQuestion}}
            class="btn-primary"
          />
          <DButton
            @label={{if this.exporting "discourse_quiz.admin.exporting" "discourse_quiz.admin.export_json"}}
            @action={{fn this.exportQuestions "json"}}
            @disabled={{this.exporting}}
            class="btn-default"
          />
          <DButton
            @label={{if this.exporting "discourse_quiz.admin.exporting" "discourse_quiz.admin.export_csv"}}
            @action={{fn this.exportQuestions "csv"}}
            @disabled={{this.exporting}}
            class="btn-default"
          />
        </div>

        <div class="quiz-admin-filters">
          <div class="quiz-admin-field">
            <label class="quiz-admin-field__label" for="quiz-category-filter">
              {{i18n "discourse_quiz.admin.category_filter"}}
            </label>
            <select id="quiz-category-filter" class="quiz-admin-field__control" {{on "change" this.onCategoryChange}}>
              <option value="" selected={{eq this.selectedCategory ""}}>
                {{i18n "discourse_quiz.admin.all_categories"}}
              </option>
              {{#each this.categories as |category|}}
                <option value={{category}} selected={{eq this.selectedCategory category}}>
                  {{category}}
                </option>
              {{/each}}
            </select>
          </div>

          <div class="quiz-admin-field">
            <label class="quiz-admin-field__label" for="quiz-question-type-filter">
              {{i18n "discourse_quiz.admin.question_type_filter"}}
            </label>
            <select
              id="quiz-question-type-filter"
              class="quiz-admin-field__control"
              {{on "change" this.onQuestionTypeChange}}
            >
              <option value="" selected={{eq this.selectedQuestionType ""}}>
                {{i18n "discourse_quiz.admin.all_question_types"}}
              </option>
              <option value="single_choice" selected={{eq this.selectedQuestionType "single_choice"}}>
                {{i18n "discourse_quiz.admin.form.question_types.single_choice"}}
              </option>
              <option value="true_false" selected={{eq this.selectedQuestionType "true_false"}}>
                {{i18n "discourse_quiz.admin.form.question_types.true_false"}}
              </option>
              <option value="multiple_choice" selected={{eq this.selectedQuestionType "multiple_choice"}}>
                {{i18n "discourse_quiz.admin.form.question_types.multiple_choice"}}
              </option>
            </select>
          </div>

          <div class="quiz-admin-field quiz-admin-field--grow">
            <label class="quiz-admin-field__label" for="quiz-search-query">
              {{i18n "discourse_quiz.admin.search"}}
            </label>
            <input
              id="quiz-search-query"
              class="quiz-admin-field__control"
              type="text"
              value={{this.searchQuery}}
              {{on "input" this.onSearchInput}}
            />
          </div>

          <div class="quiz-admin-field__actions">
            <DButton @label="discourse_quiz.admin.search_button" @action={{this.applySearch}} class="btn-default" />
            {{#if this.searchQuery}}
              <DButton @label="discourse_quiz.admin.clear_search" @action={{this.clearSearch}} class="btn-default" />
            {{/if}}
            {{#if this.duplicateSummary.duplicate_group_count}}
              <DButton
                @label={{if
                  this.disablingDuplicates
                  "discourse_quiz.admin.duplicate_disable_running"
                  "discourse_quiz.admin.duplicate_disable_button_short"
                }}
                @title="discourse_quiz.admin.duplicate_disable_button"
                @action={{this.bulkDisableDuplicates}}
                @disabled={{this.disablingDuplicates}}
                class="btn-default btn-small"
              />
            {{/if}}
          </div>
        </div>

        <div class="quiz-admin-pagination">
          <span>
            {{i18n
              "discourse_quiz.admin.pagination"
              page=this.page
              total_pages=this.totalPages
              total=this.total
            }}
          </span>
          <DButton
            @label="discourse_quiz.admin.prev_page"
            @action={{this.goPrevPage}}
            @disabled={{not this.canGoPrev}}
            class="btn-default btn-small"
          />
          <DButton
            @label="discourse_quiz.admin.next_page"
            @action={{this.goNextPage}}
            @disabled={{not this.canGoNext}}
            class="btn-default btn-small"
          />
        </div>

        <div class="quiz-questions-cards">
          {{#each this.questions as |question|}}
            <article class="quiz-question-card {{if question.duplicate_ids 'is-duplicate'}}">
              <div class="quiz-question-card__meta">
                <span class="quiz-question-card__category">{{question.category_name}}</span>
                <span class="quiz-question-card__status">
                  {{#if question.active}}
                    <span
                      class="quiz-admin-active-indicator is-active"
                      title={{i18n "discourse_quiz.admin.yes"}}
                      aria-label={{i18n "discourse_quiz.admin.yes"}}
                    ></span>
                  {{else}}
                    <span
                      class="quiz-admin-active-indicator is-inactive"
                      title={{i18n "discourse_quiz.admin.no"}}
                      aria-label={{i18n "discourse_quiz.admin.no"}}
                    ></span>
                  {{/if}}
                </span>
              </div>

              <div class="quiz-question-card__text">{{this.imageLabelPreview question.question_text}}</div>

              {{#if question.duplicate_ids}}
                <span class="quiz-admin-duplicate-badge">
                  {{i18n "discourse_quiz.admin.duplicate_row_hint"}}
                  #{{this.duplicateIdsLabel question.duplicate_ids}}
                </span>
              {{/if}}

              <div class="quiz-question-card__actions quiz-admin-actions">
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
              </div>
            </article>
          {{/each}}
        </div>

        <table class="quiz-questions-table table">
          <thead>
            <tr>
              <th class="quiz-admin-col-id">{{i18n "discourse_quiz.admin.table.id"}}</th>
              <th>{{i18n "discourse_quiz.admin.table.category"}}</th>
              <th class="quiz-admin-col-type">{{i18n "discourse_quiz.admin.table.question_type"}}</th>
              <th>{{i18n "discourse_quiz.admin.table.question"}}</th>
              <th class="quiz-admin-col-active">{{i18n "discourse_quiz.admin.table.active"}}</th>
              <th>{{i18n "discourse_quiz.admin.table.actions"}}</th>
            </tr>
          </thead>
          <tbody>
            {{#each this.questions as |question|}}
              <tr class={{if question.duplicate_ids "is-duplicate"}}>
                <td class="quiz-admin-col-id">
                  {{question.id}}
                  {{#if question.duplicate_ids}}
                    <span
                      class="quiz-admin-duplicate-badge"
                      title={{this.duplicateIdsLabel question.duplicate_ids}}
                    >
                      {{i18n "discourse_quiz.admin.duplicate_row_hint"}}
                    </span>
                  {{/if}}
                </td>
                <td>{{question.category_name}}</td>
                <td class="quiz-admin-col-type">
                  {{#if (eq question.question_type "multiple_choice")}}
                    {{i18n "discourse_quiz.admin.form.question_types.multiple_choice"}}
                  {{else if (eq question.question_type "true_false")}}
                    {{i18n "discourse_quiz.admin.form.question_types.true_false"}}
                  {{else}}
                    {{i18n "discourse_quiz.admin.form.question_types.single_choice"}}
                  {{/if}}
                </td>
                <td>{{this.imageLabelPreview question.question_text}}</td>
                <td class="quiz-admin-col-active">
                  {{#if question.active}}
                    <span
                      class="quiz-admin-active-indicator is-active"
                      title={{i18n "discourse_quiz.admin.yes"}}
                      aria-label={{i18n "discourse_quiz.admin.yes"}}
                    ></span>
                  {{else}}
                    <span
                      class="quiz-admin-active-indicator is-inactive"
                      title={{i18n "discourse_quiz.admin.no"}}
                      aria-label={{i18n "discourse_quiz.admin.no"}}
                    ></span>
                  {{/if}}
                </td>
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

      <section class="quiz-admin-list">
        <h2>{{i18n "discourse_quiz.admin.question_submissions_title"}}</h2>
        <div class="quiz-admin-filters">
          <div class="quiz-admin-field">
            <label class="quiz-admin-field__label" for="quiz-submission-status-filter">
              {{i18n "discourse_quiz.admin.question_submissions_status"}}
            </label>
            <select
              id="quiz-submission-status-filter"
              class="quiz-admin-field__control"
              {{on "change" this.onSubmissionStatusFilterChange}}
            >
              <option value="" selected={{eq this.submissionStatusFilter ""}}>
                {{i18n "discourse_quiz.admin.question_submissions_all"}}
              </option>
              <option value="pending" selected={{eq this.submissionStatusFilter "pending"}}>
                {{i18n "discourse_quiz.admin.question_submissions_pending"}}
              </option>
              <option value="approved" selected={{eq this.submissionStatusFilter "approved"}}>
                {{i18n "discourse_quiz.admin.question_submissions_approved"}}
              </option>
              <option value="rejected" selected={{eq this.submissionStatusFilter "rejected"}}>
                {{i18n "discourse_quiz.admin.question_submissions_rejected"}}
              </option>
            </select>
          </div>
          <div class="quiz-admin-field__actions">
            <DButton
              @label="discourse_quiz.admin.reload"
              @action={{this.loadSubmissions}}
              class="btn-default"
            />
          </div>
        </div>

        {{#if this.submissionsLoading}}
          <p class="quiz-admin-hint">{{i18n "discourse_quiz.loading"}}</p>
        {{else if this.submissions.length}}
          <div class="quiz-questions-cards">
            {{#each this.submissions as |submission|}}
              <article class="quiz-question-card">
                <div class="quiz-question-card__meta">
                  <span class="quiz-question-card__category">{{submission.category_name}}</span>
                  <span class="quiz-question-card__status">
                    {{submission.status}}
                  </span>
                </div>
                <div class="quiz-question-card__text">{{this.imageLabelPreview submission.question_text}}</div>
                <div class="quiz-admin-hint">
                  {{i18n "discourse_quiz.admin.question_submissions_submitter" username=submission.submitter_username}}
                </div>
                {{#if (eq submission.status "pending")}}
                  <div class="quiz-admin-field">
                    <label class="quiz-admin-field__label">
                      {{i18n "discourse_quiz.admin.question_submissions_note"}}
                    </label>
                    <input
                      class="quiz-admin-field__control"
                      type="text"
                      value={{submission.review_note_draft}}
                      {{on "input" (fn this.onSubmissionReviewNoteInput submission)}}
                    />
                  </div>
                {{/if}}
                {{#if (eq submission.status "pending")}}
                  <div class="quiz-question-card__actions quiz-admin-actions">
                    <DButton
                      @label="discourse_quiz.admin.question_submissions_approve"
                      @action={{fn this.reviewSubmission submission "approve"}}
                      @disabled={{eq this.reviewBusyId submission.id}}
                      class="btn-primary btn-small"
                    />
                    <DButton
                      @label="discourse_quiz.admin.question_submissions_reject"
                      @action={{fn this.reviewSubmission submission "reject"}}
                      @disabled={{eq this.reviewBusyId submission.id}}
                      class="btn-danger btn-small"
                    />
                  </div>
                {{/if}}
              </article>
            {{/each}}
          </div>
        {{else}}
          <p class="quiz-admin-hint">{{i18n "discourse_quiz.admin.question_submissions_empty"}}</p>
        {{/if}}
      </section>

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

        <div class="quiz-admin-import__options">
          <label class="quiz-admin-form__checkbox">
            <input type="checkbox" checked={{this.dryRun}} {{on "change" this.toggleDryRun}} />
            <span>{{i18n "discourse_quiz.admin.dry_run"}}</span>
          </label>
          <label class="quiz-admin-form__checkbox">
            <input type="checkbox" checked={{this.upsert}} {{on "change" this.toggleUpsert}} />
            <span>{{i18n "discourse_quiz.admin.upsert"}}</span>
          </label>
        </div>

        <DButton
          @label={{if this.importing "discourse_quiz.admin.importing" "discourse_quiz.admin.import_button"}}
          @action={{this.bulkImport}}
          @disabled={{this.importing}}
          class="btn-primary"
        />

        {{#if this.importResult}}
          <p class="quiz-import-result">
            {{#if this.importResult.dry_run}}
              {{i18n
                "discourse_quiz.admin.dry_run_result"
                valid=this.importResult.valid
                skipped=this.importResult.skipped
                total=this.importResult.total
              }}
            {{else}}
              {{i18n
                "discourse_quiz.admin.import_result_full"
                imported=this.importResult.imported
                updated=this.importResult.updated
                skipped=this.importResult.skipped
                total=this.importResult.total
              }}
            {{/if}}
          </p>
        {{/if}}

        {{#if this.importWarnings.length}}
          <table class="quiz-import-warnings table">
            <thead>
              <tr>
                <th>{{i18n "discourse_quiz.admin.import_warning_row"}}</th>
                <th>{{i18n "discourse_quiz.admin.import_warning_messages"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each this.importWarnings as |warning|}}
                <tr>
                  <td>{{warning.row}}</td>
                  <td>{{warning.message}}</td>
                </tr>
              {{/each}}
            </tbody>
          </table>
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

      <section class="quiz-admin-categories">
        <h2>{{i18n "discourse_quiz.admin.category_manage_title"}}</h2>
        <p class="quiz-admin-hint">{{i18n "discourse_quiz.admin.category_manage_hint"}}</p>
        <div class="quiz-admin-category-rename">
          <div class="quiz-admin-field">
            <label class="quiz-admin-field__label" for="quiz-rename-from">
              {{i18n "discourse_quiz.admin.rename_from"}}
            </label>
            <select id="quiz-rename-from" class="quiz-admin-field__control" {{on "change" this.onRenameFromChange}}>
              <option value="" selected={{eq this.renameFrom ""}}>
                {{i18n "discourse_quiz.admin.rename_select"}}
              </option>
              {{#each this.categories as |category|}}
                <option value={{category}} selected={{eq this.renameFrom category}}>
                  {{category}}
                </option>
              {{/each}}
            </select>
          </div>
          <div class="quiz-admin-field">
            <label class="quiz-admin-field__label" for="quiz-rename-to">
              {{i18n "discourse_quiz.admin.rename_to"}}
            </label>
            <input
              id="quiz-rename-to"
              class="quiz-admin-field__control"
              type="text"
              value={{this.renameTo}}
              {{on "input" this.onRenameToChange}}
            />
          </div>
          <DButton
            @label={{if this.renaming "discourse_quiz.admin.renaming" "discourse_quiz.admin.rename_button"}}
            @action={{this.renameCategory}}
            @disabled={{or this.renaming (not this.renameFrom) (not this.renameTo)}}
            class="btn-default quiz-admin-field__action"
          />
        </div>
        {{#if this.renameResult}}
          <p class="quiz-import-result">
            {{i18n "discourse_quiz.admin.rename_result" count=this.renameResult.updated}}
          </p>
        {{/if}}
      </section>
    </div>
  </template>
}
