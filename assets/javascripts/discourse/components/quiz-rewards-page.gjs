import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { LinkTo } from "@ember/routing";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import moment from "moment";
import { i18n } from "discourse-i18n";

export default class QuizRewardsPage extends Component {
  @service currentUser;
  @service siteSettings;
  @service router;

  @tracked claimingId = null;
  @tracked claimMessage = null;

  get model() {
    return this.args.model || {};
  }

  get rewards() {
    return this.model.rewards || [];
  }

  get claims() {
    return this.model.claims || [];
  }

  get introText() {
    return (
      this.siteSettings.quiz_rewards_intro?.trim() ||
      this.model.intro?.trim() ||
      i18n("discourse_quiz.rewards.intro_default")
    );
  }

  get isLoggedIn() {
    return Boolean(this.currentUser || this.model.logged_in);
  }

  get pointsSourceLabel() {
    if (this.model.points_source === "quiz") {
      return i18n("discourse_quiz.rewards.points_source_quiz");
    }

    return i18n("discourse_quiz.rewards.points_source_gamification");
  }

  stockLabel = (reward) => {
    if (!reward.in_stock) {
      return i18n("discourse_quiz.rewards.out_of_stock");
    }

    if (reward.remaining_stock === null || reward.remaining_stock === undefined) {
      return i18n("discourse_quiz.rewards.unlimited_stock");
    }

    return i18n("discourse_quiz.rewards.remaining_stock", { count: reward.remaining_stock });
  };

  canClaim = (reward) => {
    const eligible =
      reward.claimable ??
      (this.isLoggedIn &&
        !reward.claim_status &&
        reward.in_stock !== false &&
        (this.model.cumulative_points || 0) >= reward.points_threshold);

    return (
      this.isLoggedIn &&
      eligible &&
      !reward.claim_status &&
      reward.in_stock !== false &&
      this.claimingId !== reward.id
    );
  };

  actionLabel = (reward) => {
    if (!this.isLoggedIn) {
      return i18n("discourse_quiz.rewards.login_to_claim");
    }

    if (reward.claim_status === "pending") {
      return i18n("discourse_quiz.rewards.claimed_pending");
    }

    if (reward.claim_status === "fulfilled") {
      return i18n("discourse_quiz.rewards.claimed_fulfilled");
    }

    if (!reward.in_stock) {
      return i18n("discourse_quiz.rewards.out_of_stock");
    }

    if (!this.canClaim(reward)) {
      const needed = Math.max(reward.points_threshold - (this.model.cumulative_points || 0), 0);
      return i18n("discourse_quiz.rewards.need_more_points", { count: needed });
    }

    return i18n("discourse_quiz.rewards.claim");
  };

  isClaimDisabled = (reward) => !this.canClaim(reward);

  claimStatusLabel = (status) => {
    if (status === "fulfilled") {
      return i18n("discourse_quiz.rewards.claimed_fulfilled");
    }

    return i18n("discourse_quiz.rewards.claimed_pending");
  };

  claimDateTime = (value) => {
    if (!value) {
      return "";
    }

    return moment(value).format("YYYY-MM-DD HH:mm:ss");
  };

  @action
  async claimReward(reward) {
    if (!this.canClaim(reward)) {
      return;
    }

    this.claimingId = reward.id;
    this.claimMessage = null;

    try {
      await ajax(`/quiz/rewards/${reward.id}/claim.json`, { type: "POST" });
      this.claimMessage = i18n("discourse_quiz.rewards.claim_success");
      this.router.refresh();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.claimingId = null;
    }
  }

  <template>
    <section class="quiz-rewards-page">
      <div class="quiz-rewards-page__header">
        <h1 class="quiz-rewards-page__title page__title">{{i18n "discourse_quiz.rewards.title"}}</h1>
        <LinkTo @route="quiz" class="btn btn-default btn-small">
          {{i18n "gamified_quiz.button_title"}}
        </LinkTo>
      </div>

      <p class="quiz-rewards-page__intro">{{this.introText}}</p>

      <div class="quiz-rewards-page__score-card">
        <div class="quiz-rewards-page__score-label">{{i18n "discourse_quiz.rewards.cumulative_label"}}</div>
        <div class="quiz-rewards-page__score-value">{{this.model.cumulative_points}}</div>
        <div class="quiz-rewards-page__score-hint">{{this.pointsSourceLabel}}</div>
      </div>

      {{#if this.claimMessage}}
        <p class="quiz-rewards-page__notice">{{this.claimMessage}}</p>
      {{/if}}

      {{#if this.rewards.length}}
        <div class="quiz-rewards-page__grid">
          {{#each this.rewards as |reward|}}
            <article class="quiz-rewards-page__card">
              {{#if reward.image_url}}
                <img class="quiz-rewards-page__image" src={{reward.image_url}} alt={{reward.name}} loading="lazy" />
              {{/if}}
              <div class="quiz-rewards-page__card-body">
                {{#if reward.category}}
                  <div class="quiz-rewards-page__category">{{reward.category}}</div>
                {{/if}}
                <h2>{{reward.name}}</h2>
                {{#if reward.description}}
                  <p>{{reward.description}}</p>
                {{/if}}
                <div class="quiz-rewards-page__meta">
                  <span>{{i18n "discourse_quiz.rewards.threshold" count=reward.points_threshold}}</span>
                  <span>{{this.stockLabel reward}}</span>
                </div>
                <button
                  type="button"
                  class="btn btn-primary quiz-rewards-page__claim-btn"
                  disabled={{this.isClaimDisabled reward}}
                  {{on "click" (fn this.claimReward reward)}}
                >
                  {{this.actionLabel reward}}
                </button>
              </div>
            </article>
          {{/each}}
        </div>
      {{else}}
        <p>{{i18n "discourse_quiz.rewards.no_rewards"}}</p>
      {{/if}}

      {{#if this.model.logged_in}}
        <div class="quiz-rewards-page__claims">
          <h3>{{i18n "discourse_quiz.rewards.my_claims"}}</h3>
          {{#if this.claims.length}}
            <ul class="quiz-rewards-page__claims-list">
              {{#each this.claims as |claim|}}
                <li class="quiz-rewards-page__claim-item">
                  <div class="quiz-rewards-page__claim-main">
                    <span class="quiz-rewards-page__claim-name">{{claim.reward_name}}</span>
                    {{#if claim.reward_description}}
                      <span class="quiz-rewards-page__claim-description">{{claim.reward_description}}</span>
                    {{/if}}
                  </div>
                  <span class="quiz-rewards-page__claim-meta">
                    <span class="quiz-rewards-page__claim-status">{{this.claimStatusLabel claim.status}}</span>
                    {{#if claim.created_at}}
                      <time class="quiz-rewards-page__claim-date" datetime={{claim.created_at}}>
                        {{this.claimDateTime claim.created_at}}
                      </time>
                    {{/if}}
                  </span>
                </li>
              {{/each}}
            </ul>
          {{else}}
            <p>{{i18n "discourse_quiz.rewards.no_claims"}}</p>
          {{/if}}
        </div>
      {{/if}}
    </section>
  </template>
}
