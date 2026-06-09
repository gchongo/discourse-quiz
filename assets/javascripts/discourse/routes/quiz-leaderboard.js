import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class QuizLeaderboardRoute extends Route {
  @service siteSettings;
  @service router;

  beforeModel() {
    if (!this.siteSettings.quiz_plugin_enabled) {
      this.router.replaceWith("discovery.latest");
    }
  }

  model() {
    return {
      enabled: true,
    };
  }
}
