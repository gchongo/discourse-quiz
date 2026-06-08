import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class QuizRewardsRoute extends Route {
  @service siteSettings;
  @service router;

  beforeModel() {
    if (!this.siteSettings.quiz_plugin_enabled || !this.siteSettings.quiz_rewards_enabled) {
      this.router.replaceWith("discovery.latest");
    }
  }

  async model() {
    const data = await ajax("/quiz/rewards.json");
    let claims = [];

    if (data.logged_in) {
      try {
        const claimsData = await ajax("/quiz/rewards/claims.json");
        claims = claimsData.claims || [];
        data.cumulative_points = claimsData.cumulative_points ?? data.cumulative_points;
      } catch {
        claims = [];
      }
    }

    return { ...data, claims };
  }
}
