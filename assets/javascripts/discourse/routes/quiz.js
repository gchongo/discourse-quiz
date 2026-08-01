import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class QuizRoute extends Route {
  @service quiz;
  @service router;

  beforeModel(transition) {
    if (this.quiz.isEnabled) {
      this.quiz.openPanel();
    }

    // Keep the user on the page they were browsing; only fall back to latest
    // when /quiz is opened directly (no prior route).
    if (transition.from) {
      transition.abort();
      return;
    }

    this.router.replaceWith("discovery.latest");
  }
}
