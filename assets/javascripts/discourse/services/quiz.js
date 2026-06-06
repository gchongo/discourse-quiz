import Service, { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class QuizService extends Service {
  @service siteSettings;
  @service capabilities;
  @service currentUser;

  @tracked panelVisible = false;
  @tracked isDocked = true;
  @tracked isMinimized = false;

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

  get isEnabled() {
    return this.siteSettings.quiz_plugin_enabled;
  }

  get isMobile() {
    return this.capabilities.isMobileDevice;
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
    this.showHome();
  }

  @action
  togglePanel() {
    this.panelVisible = !this.panelVisible;
    if (this.panelVisible) {
      this.isMinimized = false;
      this.showHome();
    }
  }

  @action
  closePanel() {
    this.panelVisible = false;
  }

  @action
  toggleDock() {
    this.isDocked = !this.isDocked;
  }

  @action
  toggleMinimize() {
    this.isMinimized = !this.isMinimized;
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

      if (e?.jqXHR?.status === 403 && status) {
        this.quizStatus = status;
        this.paywallActive = true;
        return;
      }

      if (e?.jqXHR?.status === 404) {
        this.errorMessage = i18n("discourse_quiz.no_questions_in_range");
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
    const filters = this.effectiveCategoryFilters();

    if (filters.length === 0) {
      return "/quiz/next.json";
    }

    const query = filters
      .map((name) => `category_names[]=${encodeURIComponent(name)}`)
      .join("&");

    return `/quiz/next.json?${query}`;
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
