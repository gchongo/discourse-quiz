import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class QuizRoute extends Route {
  @service quiz;
  @service router;

  beforeModel(transition) {
    if (this.quiz.isEnabled) {
      this.quiz.openPanel();
    }

    const fromRouteName = transition?.from?.name;

    // Clicking the sidebar link should behave like the header icon:
    // open panel without navigating away from current page.
    if (fromRouteName && fromRouteName !== "application") {
      transition.abort();
      return;
    }

    this.router.replaceWith("discovery.latest");
  }
}
