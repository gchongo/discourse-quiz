import Service, { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class QuizService extends Service {
  @service siteSettings;
  @service capabilities;

  @tracked panelVisible = false;
  @tracked isDocked = true;
  @tracked isMinimized = false;

  @tracked state = "loading"; // loading, ready, submitting, result, error
  @tracked currentQuestion = null;
  @tracked lastResult = null;
  @tracked status = null;

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
      const [status, question] = await Promise.all([
        ajax("/quiz/status.json"),
        ajax("/quiz/next.json"),
      ]);
      this.status = status;
      this.currentQuestion = question;
      this.state = "ready";
    } catch (e) {
      this.state = "error";
    }
  }

  @action
  async submitAnswer(answerIndex) {
    if (this.state !== "ready") return;

    try {
      this.state = "submitting";
      const result = await ajax("/quiz/submit.json", {
        type: "POST",
        data: {
          question_id: this.currentQuestion.id,
          answer_index: answerIndex,
        },
      });
      this.lastResult = result;
      this.state = "result";
      // Refresh status after submission to update points/mode
      this.status = await ajax("/quiz/status.json");
    } catch (e) {
      this.state = "error";
    }
  }

  @action
  async nextQuestion() {
    try {
      this.state = "loading";
      this.lastResult = null;
      this.currentQuestion = await ajax("/quiz/next.json");
      this.state = "ready";
    } catch (e) {
      this.state = "error";
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
}
