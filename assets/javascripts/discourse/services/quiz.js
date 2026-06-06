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
  @tracked selectedCategory = "";
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
  selectCategory(category) {
    this.selectedCategory = category;
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

    const url = this.selectedCategory
      ? `/quiz/next.json?category_name=${encodeURIComponent(this.selectedCategory)}`
      : "/quiz/next.json";

    try {
      const data = await ajax(url);
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
}
