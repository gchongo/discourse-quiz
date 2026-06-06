import Service, { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

const DOCK_PREF_KEY = "discourse-quiz-docked";
const POSITION_PREF_KEY = "discourse-quiz-panel-position";
const MODE_PREF_KEY = "discourse-quiz-practice-mode";
const PRACTICE_MODES = ["normal", "wrong_only", "unseen"];
const QUESTION_TYPES = ["single_choice", "true_false", "multiple_choice"];
const QUESTION_TYPES_PREF_KEY = "discourse-quiz-question-types";
const CATEGORIES_PREF_KEY = "discourse-quiz-categories";
const CATEGORIES_CACHE_KEY = "discourse-quiz-categories-cache";
const NARROW_BREAKPOINT = 1100;
const PANEL_WIDTH = 340;
const HTML_CLASS_VISIBLE = "has-quiz-panel";
const HTML_CLASS_DOCKED = "has-quiz-panel-docked";

export default class QuizService extends Service {
  @service siteSettings;
  @service capabilities;
  @service currentUser;

  @tracked panelVisible = false;
  @tracked isDocked = true;
  @tracked isMinimized = false;
  @tracked narrowViewport = false;
  @tracked panelLeft = null;
  @tracked panelTop = null;

  _resizeHandler = null;
  _layoutListenerCount = 0;

  @tracked panelPhase = "home";
  @tracked selectAllMode = true;
  @tracked selectedCategories = [];
  @tracked availableCategories = [];

  @tracked loading = false;
  @tracked homeLoading = false;
  @tracked submitting = false;
  @tracked currentQuestion = null;
  @tracked answerResult = null;
  @tracked submittedAnswerIndex = null;
  @tracked submittedAnswerIndices = null;
  @tracked quizStatus = null;
  @tracked paywallActive = false;
  @tracked errorMessage = null;
  @tracked practiceMode = "normal";
  @tracked typeFilterSingleChoice = true;
  @tracked typeFilterTrueFalse = true;
  @tracked typeFilterMultipleChoice = true;
  @tracked sessionSeenQuestionIds = [];

  _categoriesCache = null;

  get isEnabled() {
    return this.siteSettings.quiz_plugin_enabled;
  }

  get isMobile() {
    return this.capabilities.isMobileDevice;
  }

  get isDockedEffective() {
    if (this.isMobile || this.narrowViewport) {
      return false;
    }

    return this.isDocked;
  }

  get canDock() {
    return !this.isMobile && !this.narrowViewport;
  }

  get isDraggable() {
    return !this.isMobile && (!this.isDockedEffective || this.isMinimized);
  }

  get hasCustomPosition() {
    return this.panelLeft !== null && this.panelTop !== null;
  }

  get shouldPushLayout() {
    return (
      this.panelVisible && this.isDockedEffective && !this.isMinimized && !this.isMobile
    );
  }

  get isLearningOnly() {
    return this.quizStatus?.mode === "learning_only";
  }

  get isPlaying() {
    return this.panelPhase === "playing";
  }

  get canStart() {
    return (
      (this.selectAllMode || this.selectedCategories.length > 0) &&
      this.hasQuestionTypeFilter
    );
  }

  get hasQuestionTypeFilter() {
    return (
      this.typeFilterSingleChoice ||
      this.typeFilterTrueFalse ||
      this.typeFilterMultipleChoice
    );
  }

  get filtersAllQuestionTypes() {
    return (
      this.typeFilterSingleChoice &&
      this.typeFilterTrueFalse &&
      this.typeFilterMultipleChoice
    );
  }

  get canUsePracticeModes() {
    return Boolean(this.currentUser);
  }

  get selectedSummary() {
    if (this.selectAllMode) {
      return i18n("discourse_quiz.home_selected_all");
    }

    const count = this.selectedCategories.length;

    if (count === 0) {
      return i18n("discourse_quiz.home_select_hint");
    }

    if (count <= 3) {
      return i18n("discourse_quiz.home_selected_named", {
        categories: this.selectedCategories.join("、"),
      });
    }

    return i18n("discourse_quiz.home_selected_count", { count });
  }

  get selectedTypesSummary() {
    return this.questionTypesSummary("discourse_quiz.home_selected_types_all", "discourse_quiz.home_selected_types_named");
  }

  get currentRangeSummary() {
    if (this.selectAllMode) {
      return i18n("discourse_quiz.current_range_all");
    }

    const count = this.selectedCategories.length;

    if (count <= 3) {
      return i18n("discourse_quiz.current_range_multi", {
        categories: this.selectedCategories.join("、"),
      });
    }

    return i18n("discourse_quiz.current_range_count", { count });
  }

  get currentTypesSummary() {
    return this.questionTypesSummary("discourse_quiz.current_types_all", "discourse_quiz.current_types_named");
  }

  questionTypesSummary(allKey, namedKey) {
    if (this.filtersAllQuestionTypes) {
      return i18n(allKey);
    }

    const labels = this.activeQuestionTypeLabels();

    return i18n(namedKey, {
      types: labels.join("、"),
    });
  }

  activeQuestionTypeLabels() {
    const labels = [];

    if (this.typeFilterSingleChoice) {
      labels.push(i18n("discourse_quiz.admin.form.question_types.single_choice"));
    }

    if (this.typeFilterTrueFalse) {
      labels.push(i18n("discourse_quiz.admin.form.question_types.true_false"));
    }

    if (this.typeFilterMultipleChoice) {
      labels.push(i18n("discourse_quiz.admin.form.question_types.multiple_choice"));
    }

    return labels;
  }

  activeQuestionTypeFilters() {
    const types = [];

    if (this.typeFilterSingleChoice) {
      types.push("single_choice");
    }

    if (this.typeFilterTrueFalse) {
      types.push("true_false");
    }

    if (this.typeFilterMultipleChoice) {
      types.push("multiple_choice");
    }

    return types;
  }

  isCategorySelected(category) {
    return !this.selectAllMode && this.selectedCategories.includes(category);
  }

  @action
  openPanel() {
    this.loadQuestionTypePreference();
    this.loadCategoryPreference();
    this.panelVisible = true;
    this.isMinimized = false;
    this.syncLayoutClasses();
    this.showHome();
  }

  @action
  togglePanel() {
    this.panelVisible = !this.panelVisible;
    if (this.panelVisible) {
      this.loadQuestionTypePreference();
      this.loadCategoryPreference();
      this.isMinimized = false;
      this.showHome();
    }
    this.syncLayoutClasses();
  }

  @action
  closePanel() {
    this.panelVisible = false;
    this.syncLayoutClasses();
  }

  @action
  toggleDock() {
    if (!this.canDock) {
      return;
    }

    this.isDocked = !this.isDocked;
    this.isMinimized = false;
    this.saveDockPreference();
    this.syncLayoutClasses();
  }

  @action
  toggleMinimize() {
    this.isMinimized = !this.isMinimized;
    this.syncLayoutClasses();
  }

  registerLayoutListeners() {
    this._layoutListenerCount += 1;

    if (this._resizeHandler) {
      this.syncLayoutClasses();
      return;
    }

    this.loadDockPreference();
    this.loadPositionPreference();
    this.loadPracticeModePreference();
    this._resizeHandler = () => this.handleViewportResize();
    window.addEventListener("resize", this._resizeHandler, { passive: true });
    this.handleViewportResize();
    this.syncLayoutClasses();
  }

  unregisterLayoutListeners() {
    this._layoutListenerCount = Math.max(0, this._layoutListenerCount - 1);

    if (this._layoutListenerCount > 0) {
      return;
    }

    if (this._resizeHandler) {
      window.removeEventListener("resize", this._resizeHandler);
      this._resizeHandler = null;
    }

    this.clearLayoutClasses();
  }

  handleViewportResize() {
    const wasNarrow = this.narrowViewport;
    this.narrowViewport =
      !this.isMobile && window.innerWidth < NARROW_BREAKPOINT;

    if (wasNarrow !== this.narrowViewport) {
      this.syncLayoutClasses();
    }

    this.ensurePanelInViewport();
  }

  setPanelPosition(left, top, { persist = true, width = PANEL_WIDTH, height = 120 } = {}) {
    const clamped = this.clampPanelPosition(left, top, width, height);
    this.panelLeft = clamped.left;
    this.panelTop = clamped.top;

    if (persist) {
      this.savePositionPreference();
    }
  }

  ensurePanelInViewport() {
    if (!this.hasCustomPosition) {
      return;
    }

    let width = PANEL_WIDTH;
    let height = 120;

    if (typeof document !== "undefined") {
      const panel = document.querySelector(".quiz-panel-container.is-visible");

      if (panel) {
        const rect = panel.getBoundingClientRect();
        width = rect.width;
        height = rect.height;
      }
    }

    this.setPanelPosition(this.panelLeft, this.panelTop, {
      persist: true,
      width,
      height,
    });
  }

  clampPanelPosition(left, top, width = PANEL_WIDTH, height = 120) {
    if (typeof window === "undefined") {
      return { left, top };
    }

    const margin = 8;
    const headerOffset =
      parseInt(
        getComputedStyle(document.documentElement).getPropertyValue("--header-offset"),
        10
      ) || 0;

    return {
      left: Math.max(margin, Math.min(left, window.innerWidth - width - margin)),
      top: Math.max(
        headerOffset + margin,
        Math.min(top, window.innerHeight - height - margin)
      ),
    };
  }

  syncLayoutClasses() {
    if (typeof document === "undefined") {
      return;
    }

    const html = document.documentElement;
    const panelOpen = this.panelVisible && this.isEnabled;

    html.classList.toggle(HTML_CLASS_VISIBLE, panelOpen);
    html.classList.toggle(HTML_CLASS_DOCKED, this.shouldPushLayout);
  }

  clearLayoutClasses() {
    if (typeof document === "undefined") {
      return;
    }

    const html = document.documentElement;
    html.classList.remove(HTML_CLASS_VISIBLE, HTML_CLASS_DOCKED);
  }

  loadPositionPreference() {
    try {
      const stored = localStorage.getItem(POSITION_PREF_KEY);

      if (!stored) {
        return;
      }

      const { left, top } = JSON.parse(stored);

      if (Number.isFinite(left) && Number.isFinite(top)) {
        this.panelLeft = left;
        this.panelTop = top;
      }
    } catch {
      // localStorage may be unavailable or JSON invalid
    }
  }

  savePositionPreference() {
    if (!this.hasCustomPosition) {
      return;
    }

    try {
      localStorage.setItem(
        POSITION_PREF_KEY,
        JSON.stringify({ left: this.panelLeft, top: this.panelTop })
      );
    } catch {
      // localStorage may be unavailable
    }
  }

  loadDockPreference() {
    try {
      const stored = localStorage.getItem(DOCK_PREF_KEY);

      if (stored !== null) {
        this.isDocked = stored === "true";
      }
    } catch {
      // localStorage may be unavailable
    }
  }

  saveDockPreference() {
    if (!this.canDock) {
      return;
    }

    try {
      localStorage.setItem(DOCK_PREF_KEY, String(this.isDocked));
    } catch {
      // localStorage may be unavailable
    }
  }

  @action
  toggleAllCategories() {
    if (this.selectAllMode) {
      this.selectAllMode = false;
      this.selectedCategories = [];
    } else {
      this.resetCategorySelection();
    }

    this.saveCategoryPreference();
  }

  @action
  toggleCategory(category) {
    if (this.selectAllMode) {
      this.selectAllMode = false;
      this.selectedCategories = [category];
      return;
    }

    if (this.selectedCategories.includes(category)) {
      this.selectedCategories = this.selectedCategories.filter((c) => c !== category);
    } else {
      this.selectedCategories = [...this.selectedCategories, category];
    }

    this.saveCategoryPreference();
  }

  @action
  resetCategorySelection() {
    this.selectAllMode = true;
    this.selectedCategories = [];
    this.saveCategoryPreference();
  }

  @action
  toggleTypeFilterSingleChoice() {
    this.toggleTypeFilter("typeFilterSingleChoice");
  }

  @action
  toggleTypeFilterTrueFalse() {
    this.toggleTypeFilter("typeFilterTrueFalse");
  }

  @action
  toggleTypeFilterMultipleChoice() {
    this.toggleTypeFilter("typeFilterMultipleChoice");
  }

  toggleTypeFilter(propertyName) {
    if (this[propertyName] && !this.hasOtherTypeFilters(propertyName)) {
      return;
    }

    this[propertyName] = !this[propertyName];
    this.saveQuestionTypePreference();
  }

  hasOtherTypeFilters(excludedProperty) {
    return (
      (excludedProperty !== "typeFilterSingleChoice" && this.typeFilterSingleChoice) ||
      (excludedProperty !== "typeFilterTrueFalse" && this.typeFilterTrueFalse) ||
      (excludedProperty !== "typeFilterMultipleChoice" && this.typeFilterMultipleChoice)
    );
  }

  @action
  async showHome() {
    this.panelPhase = "home";
    this.currentQuestion = null;
    this.answerResult = null;
    this.submittedAnswerIndex = null;
    this.submittedAnswerIndices = null;
    this.errorMessage = null;
    this.paywallActive = false;
    this.sessionSeenQuestionIds = [];

    await this.loadHome();
  }

  @action
  setPracticeMode(mode) {
    if (!PRACTICE_MODES.includes(mode)) {
      return;
    }

    if (mode !== "normal" && !this.canUsePracticeModes) {
      return;
    }

    this.practiceMode = mode;
    this.savePracticeModePreference();
  }

  @action
  async loadHome() {
    const cached = this.readCategoriesCache();

    if (cached?.categories?.length) {
      this.applyHomeData(cached, { fromCache: true });
      this.pruneSelectedCategories();
      this.homeLoading = false;
    } else {
      this.homeLoading = true;
    }

    try {
      const data = await ajax("/quiz/categories.json");
      this.applyHomeData(data);
    } catch (e) {
      if (!cached?.categories?.length) {
        this.availableCategories = [];
        this.errorMessage = i18n("discourse_quiz.load_error");
      }
    } finally {
      this.homeLoading = false;
    }
  }

  applyHomeData(data, { fromCache = false } = {}) {
    this.availableCategories = data.categories || [];
    this.quizStatus = data.status || this.quizStatus;

    if (!fromCache) {
      this.pruneSelectedCategories();
      this.writeCategoriesCache(data);
    }

    if (this.quizStatus?.mode === "paywall") {
      this.paywallActive = true;
      this.errorMessage = null;
    } else if (!fromCache && this.availableCategories.length === 0) {
      this.errorMessage = i18n("discourse_quiz.no_questions");
    } else if (!fromCache) {
      this.errorMessage = null;
    }
  }

  readCategoriesCache() {
    if (this._categoriesCache) {
      return this._categoriesCache;
    }

    try {
      const stored = localStorage.getItem(CATEGORIES_CACHE_KEY);

      if (!stored) {
        return null;
      }

      const parsed = JSON.parse(stored);

      if (!Array.isArray(parsed?.categories)) {
        return null;
      }

      this._categoriesCache = parsed;
      return parsed;
    } catch {
      return null;
    }
  }

  writeCategoriesCache(data) {
    const payload = {
      categories: data.categories || [],
      status: data.status || null,
      cached_at: Date.now(),
    };

    this._categoriesCache = payload;

    try {
      localStorage.setItem(CATEGORIES_CACHE_KEY, JSON.stringify(payload));
    } catch {
      // localStorage may be unavailable
    }
  }

  loadCategoryPreference() {
    try {
      const stored = localStorage.getItem(CATEGORIES_PREF_KEY);

      if (!stored) {
        return;
      }

      const parsed = JSON.parse(stored);

      if (typeof parsed.selectAllMode === "boolean") {
        this.selectAllMode = parsed.selectAllMode;
      }

      if (Array.isArray(parsed.selectedCategories)) {
        this.selectedCategories = parsed.selectedCategories.filter(
          (category) => typeof category === "string" && category.trim() !== ""
        );
      }
    } catch {
      // localStorage may be unavailable or JSON invalid
    }
  }

  saveCategoryPreference() {
    try {
      localStorage.setItem(
        CATEGORIES_PREF_KEY,
        JSON.stringify({
          selectAllMode: this.selectAllMode,
          selectedCategories: this.selectedCategories,
        })
      );
    } catch {
      // localStorage may be unavailable
    }
  }

  @action
  startQuiz() {
    if (!this.canStart) {
      return;
    }

    this.sessionSeenQuestionIds = [];
    this.panelPhase = "playing";
    this.loadQuestion();
  }

  @action
  async loadQuestion() {
    this.loading = true;
    this.errorMessage = null;
    this.answerResult = null;
    this.submittedAnswerIndex = null;
    this.submittedAnswerIndices = null;
    this.paywallActive = false;
    this.panelPhase = "playing";

    try {
      const data = await ajax(this.buildNextUrl());
      this.currentQuestion = data;
      this.quizStatus = data.status || this.quizStatus;
      this.rememberSessionQuestion(data.id);
    } catch (e) {
      this.currentQuestion = null;
      const status = e?.jqXHR?.responseJSON?.status;

      const errorCode = e?.jqXHR?.responseJSON?.error_code;

      if (e?.jqXHR?.status === 403) {
        if (status) {
          this.quizStatus = status;
        }

        if (errorCode === "practice_mode_requires_login") {
          this.errorMessage = i18n("discourse_quiz.practice_mode_requires_login");
          this.panelPhase = "home";
          return;
        }

        this.paywallActive = true;
        return;
      }

      if (e?.jqXHR?.status === 404) {
        this.errorMessage = this.emptyRangeMessage(errorCode);
      } else {
        this.errorMessage = i18n("discourse_quiz.load_error");
      }
    } finally {
      this.loading = false;
    }
  }

  @action
  async submitAnswer(answerIndex, answerIndices = null) {
    if (!this.currentQuestion) {
      return;
    }

    const isMultipleChoice = this.currentQuestion.question_type === "multiple_choice";

    if (isMultipleChoice) {
      if (!Array.isArray(answerIndices) || answerIndices.length === 0) {
        return;
      }
    } else if (answerIndex === null || answerIndex === undefined) {
      return;
    }

    this.submitting = true;
    this.errorMessage = null;

    try {
      this.submittedAnswerIndex = answerIndex;
      this.submittedAnswerIndices = answerIndices;
      const result = await ajax("/quiz/submit.json", {
        type: "POST",
        data: {
          question_id: this.currentQuestion.id,
          answer_index: answerIndex,
          answer_indices: answerIndices,
        },
      });
      this.answerResult = result;
      this.quizStatus = result.status || this.quizStatus;
    } catch (e) {
      this.answerResult = null;
      this.submittedAnswerIndex = null;
      this.submittedAnswerIndices = null;

      if (e?.jqXHR?.status === 429) {
        this.errorMessage =
          e.jqXHR.responseJSON?.errors?.[0] || i18n("discourse_quiz.submit_error");
      } else {
        this.errorMessage = i18n("discourse_quiz.submit_error");
      }
    } finally {
      this.submitting = false;
    }
  }

  buildNextUrl() {
    const params = new URLSearchParams();

    if (this.practiceMode !== "normal") {
      params.set("practice_mode", this.practiceMode);
    }

    this.effectiveCategoryFilters().forEach((name) => {
      params.append("category_names[]", name);
    });

    this.sessionSeenQuestionIds.forEach((id) => {
      params.append("exclude_question_ids[]", id);
    });

    this.effectiveQuestionTypeFilters().forEach((type) => {
      params.append("question_types[]", type);
    });

    const query = params.toString();
    return query ? `/quiz/next.json?${query}` : "/quiz/next.json";
  }

  emptyRangeMessage(errorCode) {
    switch (errorCode) {
      case "no_wrong_questions":
        return i18n("discourse_quiz.no_wrong_questions");
      case "no_unseen_questions":
        return i18n("discourse_quiz.no_unseen_questions");
      default:
        return i18n("discourse_quiz.no_questions_in_range");
    }
  }

  loadPracticeModePreference() {
    try {
      const stored = localStorage.getItem(MODE_PREF_KEY);

      if (PRACTICE_MODES.includes(stored)) {
        if (stored === "normal" || this.canUsePracticeModes) {
          this.practiceMode = stored;
        }
      }
    } catch {
      // localStorage may be unavailable
    }
  }

  savePracticeModePreference() {
    try {
      localStorage.setItem(MODE_PREF_KEY, this.practiceMode);
    } catch {
      // localStorage may be unavailable
    }
  }

  effectiveCategoryFilters() {
    if (this.selectAllMode) {
      return [];
    }

    return this.selectedCategories;
  }

  effectiveQuestionTypeFilters() {
    if (this.filtersAllQuestionTypes) {
      return [];
    }

    return this.activeQuestionTypeFilters();
  }

  loadQuestionTypePreference() {
    try {
      const stored = localStorage.getItem(QUESTION_TYPES_PREF_KEY);

      if (!stored) {
        return;
      }

      const parsed = JSON.parse(stored);

      if (Array.isArray(parsed)) {
        this.applyQuestionTypeFilters({
          single_choice: parsed.includes("single_choice"),
          true_false: parsed.includes("true_false"),
          multiple_choice: parsed.includes("multiple_choice"),
        });
        return;
      }

      if (parsed && typeof parsed === "object") {
        this.applyQuestionTypeFilters(parsed);
      }
    } catch {
      // localStorage may be unavailable or JSON invalid
    }
  }

  applyQuestionTypeFilters(filters) {
    const single = Boolean(filters.single_choice);
    const trueFalse = Boolean(filters.true_false);
    const multiple = Boolean(filters.multiple_choice);

    if (!single && !trueFalse && !multiple) {
      return;
    }

    this.typeFilterSingleChoice = single;
    this.typeFilterTrueFalse = trueFalse;
    this.typeFilterMultipleChoice = multiple;
  }

  saveQuestionTypePreference() {
    try {
      localStorage.setItem(
        QUESTION_TYPES_PREF_KEY,
        JSON.stringify({
          single_choice: this.typeFilterSingleChoice,
          true_false: this.typeFilterTrueFalse,
          multiple_choice: this.typeFilterMultipleChoice,
        })
      );
    } catch {
      // localStorage may be unavailable
    }
  }

  pruneSelectedCategories() {
    if (this.selectAllMode) {
      return;
    }

    this.selectedCategories = this.selectedCategories.filter((category) =>
      this.availableCategories.includes(category)
    );

    if (this.selectedCategories.length === 0) {
      this.selectAllMode = true;
    }
  }

  rememberSessionQuestion(questionId) {
    const id = Number(questionId);

    if (!Number.isFinite(id) || id <= 0) {
      return;
    }

    if (!this.sessionSeenQuestionIds.includes(id)) {
      this.sessionSeenQuestionIds = [...this.sessionSeenQuestionIds, id];
    }
  }
}
