import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class QuizRoute extends Route {
  @service quiz;
  @service router;

  async beforeModel() {
    if (this.quiz.isEnabled) {
      await this.quiz.openPanel();
    }

    this.router.transitionTo("discovery.latest");
  }
}
