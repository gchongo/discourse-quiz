import Service, { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

const DOCK_PREF_KEY = "discourse-quiz-docked";
const POSITION_PREF_KEY = "discourse-quiz-panel-position";
const MODE_PREF_KEY = "discourse-quiz-practice-mode";
const PRACTICE_MODES = ["normal", "wrong_only", "unseen"];
const NARROW_BREAKPOINT = 1100;
const PANEL_WIDTH = 300;
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
  @tracked submitting = false;
  @tracked currentQuestion = null;
  @tracked answerResult = null;
  @tracked submittedAnswerIndex = null;
  @tracked quizStatus = null;
  @tracked paywallActive = false;
  @tracked errorMessage = null;
  @tracked practiceMode = "normal";

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
    return this.selectAllMode || this.selectedCategories.length > 0;
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

  isCategorySelected(category) {
    return !this.selectAllMode && this.selectedCategories.includes(category);
  }

  @action
  openPanel() {
    this.panelVisible = true;
    this.isMinimized = false;
    this.syncLayoutClasses();
    this.showHome();
  }

  @action
  togglePanel() {
    this.panelVisible = !this.panelVisible;
    if (this.panelVisible) {
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
      this.resetSelection();
    }
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
  }

  @action
  resetSelection() {
    this.selectAllMode = true;
    this.selectedCategories = [];
  }

  @action
  async showHome() {
    this.panelPhase = "home";
    this.currentQuestion = null;
    this.answerResult = null;
    this.submittedAnswerIndex = null;
    this.errorMessage = null;
    this.paywallActive = false;

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
    this.loading = true;

    try {
      const data = await ajax("/quiz/categories.json");
      this.availableCategories = data.categories || [];
      this.quizStatus = data.status || null;
      this.pruneSelectedCategories();

      if (this.quizStatus?.mode === "paywall") {
        this.paywallActive = true;
      } else if (this.availableCategories.length === 0) {
        this.errorMessage = i18n("discourse_quiz.no_questions");
      }
    } catch (e) {
      this.availableCategories = [];
      this.errorMessage = i18n("discourse_quiz.load_error");
    } finally {
      this.loading = false;
    }
  }

  @action
  startQuiz() {
    if (!this.canStart) {
      return;
    }

    this.panelPhase = "playing";
    this.loadQuestion();
  }

  @action
  async loadQuestion() {
    this.loading = true;
    this.errorMessage = null;
    this.answerResult = null;
    this.submittedAnswerIndex = null;
    this.paywallActive = false;
    this.panelPhase = "playing";

    try {
      const data = await ajax(this.buildNextUrl());
      this.currentQuestion = data;
      this.quizStatus = data.status || this.quizStatus;
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
  async submitAnswer(answerIndex) {
    if (!this.currentQuestion || answerIndex === null || answerIndex === undefined) {
      return;
    }

    this.submitting = true;
    this.errorMessage = null;

    try {
      this.submittedAnswerIndex = answerIndex;
      const result = await ajax("/quiz/submit.json", {
        type: "POST",
        data: {
          question_id: this.currentQuestion.id,
          answer_index: answerIndex,
        },
      });
      this.answerResult = result;
      this.quizStatus = result.status || this.quizStatus;
    } catch (e) {
      this.answerResult = null;
      this.submittedAnswerIndex = null;

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
}
