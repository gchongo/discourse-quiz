import Service, { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class QuizService extends Service {
  @service siteSettings;
  @service capabilities;

  @tracked panelVisible = false;
  @tracked isDocked = true;
  @tracked isMinimized = false;

  @tracked state = "loading";
  @tracked currentQuestion = null;
  @tracked lastResult = null;
  @tracked status = null;
  @tracked errorMessage = null;

  get isEnabled() {
    return this.siteSettings.quiz_plugin_enabled;
  }

  get isMobile() {
    return this.capabilities.isMobileDevice;
  }

  @action
  async togglePanel() {
    this.panelVisible = !this.panelVisible;
    if (this.panelVisible) {
      this.isMinimized = false;
      await this.loadInitialData();
    }
  }

  @action
  async loadInitialData() {
    try {
      this.state = "loading";
      this.errorMessage = null;

      const status = await ajax("/quiz/status.json");
      this.status = status;

      if (status.mode === "paywall") {
        this.currentQuestion = null;
        this.state = "ready";
        return;
      }

      this.currentQuestion = await ajax("/quiz/next.json");
      this.state = "ready";
    } catch (e) {
      this.handleRequestError(e);
    }
  }

  @action
  async submitAnswer(answerIndex) {
    if (this.state !== "ready") {
      return;
    }

    try {
      this.state = "submitting";
      this.errorMessage = null;

      const result = await ajax("/quiz/submit.json", {
        type: "POST",
        data: {
          question_id: this.currentQuestion.id,
          answer_index: answerIndex,
        },
      });

      this.lastResult = result;
      this.state = "result";
      this.status = await ajax("/quiz/status.json");
    } catch (e) {
      this.handleRequestError(e);
    }
  }

  @action
  async nextQuestion() {
    try {
      this.state = "loading";
      this.lastResult = null;
      this.errorMessage = null;

      if (this.status?.mode === "paywall") {
        this.currentQuestion = null;
        this.state = "ready";
        return;
      }

      this.currentQuestion = await ajax("/quiz/next.json");
      this.state = "ready";
    } catch (e) {
      this.handleRequestError(e);
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

  handleRequestError(error) {
    this.state = "error";

    if (error?.jqXHR?.status === 429) {
      this.errorMessage = i18n("gamified_quiz.too_many_requests");
      return;
    }

    if (error?.jqXHR?.status === 403) {
      const payload = error.jqXHR.responseJSON;
      if (payload?.status) {
        this.status = payload.status;
      }
      this.errorMessage = i18n("gamified_quiz.guest_limit_reached");
      return;
    }

    this.errorMessage = i18n("gamified_quiz.error");
  }
}
