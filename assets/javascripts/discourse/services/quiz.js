import Service, { service } from "@ember/service";
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

  @tracked loading = false;
  @tracked currentQuestion = null;
  @tracked errorMessage = null;

  get isEnabled() {
    return this.siteSettings.quiz_plugin_enabled;
  }

  get isMobile() {
    return this.capabilities.isMobileDevice;
  }

  @action
  openPanel() {
    this.panelVisible = true;
    this.isMinimized = false;
    this.loadQuestion();
  }

  @action
  togglePanel() {
    this.panelVisible = !this.panelVisible;
    if (this.panelVisible) {
      this.isMinimized = false;
      this.loadQuestion();
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
  async loadQuestion() {
    this.loading = true;
    this.errorMessage = null;

    try {
      this.currentQuestion = await ajax("/quiz/next.json");
    } catch (e) {
      this.currentQuestion = null;
      if (e?.jqXHR?.status === 404) {
        this.errorMessage = i18n("discourse_quiz.no_questions");
      } else {
        this.errorMessage = i18n("discourse_quiz.load_error");
      }
    } finally {
      this.loading = false;
    }
  }
}
