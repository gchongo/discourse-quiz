import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class QuizRoute extends Route {
  @service quiz;
  @service router;

  beforeModel() {
    if (this.quiz.isEnabled) {
      this.quiz.openPanel();
    }

    this.router.transitionTo("discovery.latest");
  }
}
