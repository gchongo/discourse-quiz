import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq, not } from "discourse/truth-helpers";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class QuizLeaderboardPage extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked activeTab = "rankings";
  @tracked metric = "volume";
  @tracked page = 1;
  @tracked loadingRankings = true;
  @tracked rankingData = null;
  @tracked rankingError = null;

  @tracked profileUsername = "";
  @tracked loadingProfile = false;
  @tracked profileData = null;
  @tracked profileError = null;

  get isEnabled() {
    return this.siteSettings.quiz_leaderboard_enabled;
  }

  constructor() {
    super(...arguments);
    this.profileUsername = this.currentUser?.username || "";

    if (this.isEnabled) {
      this.loadRankings();
    } else {
      this.loadingRankings = false;
    }
  }

  get users() {
    return this.rankingData?.users || [];
  }

  get personal() {
    return this.rankingData?.personal;
  }

  get canLoadMore() {
    if (!this.rankingData) {
      return false;
    }

    return this.page * this.rankingData.per_page < this.rankingData.total;
  }

  get profileCategories() {
    return this.profileData?.categories || [];
  }

  get winners() {
    if (!this.users.length) {
      return [];
    }

    return this.users.slice(0, Math.min(3, this.users.length));
  }

  get listUsers() {
    if (this.users.length <= 3) {
      return [];
    }

    return this.users.slice(3);
  }

  get showPodium() {
    return this.winners.length > 0;
  }

  get metricColumnLabel() {
    if (this.metric === "accuracy") {
      return i18n("discourse_quiz.leaderboard.metric_accuracy");
    }

    return i18n("discourse_quiz.leaderboard.metric_volume");
  }

  winnerPositionClass = (entry) => {
    return `-position${entry.position}`;
  };

  valueLabel = (entry) => {
    if (this.metric === "accuracy") {
      if (entry.accuracy_rate === null || entry.accuracy_rate === undefined) {
        return "—";
      }

      return i18n("discourse_quiz.leaderboard.accuracy_value", {
        rate: entry.accuracy_rate,
      });
    }

    return entry.questions_attempted;
  };

  accuracyLabel = (rate) => {
    if (rate === null || rate === undefined) {
      return "—";
    }

    return i18n("discourse_quiz.leaderboard.accuracy_value", { rate });
  };

  displayName = (entry) => {
    if (this.siteSettings.prioritize_username_in_ux) {
      return entry.username;
    }

    return entry.name || entry.username;
  };

  @action
  setTab(tab) {
    if (!this.isEnabled) {
      return;
    }

    this.activeTab = tab;

    if (tab === "profile" && !this.profileData && this.profileUsername) {
      this.loadProfile();
    }
  }

  @action
  setMetric(metric) {
    if (this.metric === metric) {
      return;
    }

    this.metric = metric;
    this.page = 1;
    this.loadRankings();
  }

  @action
  async loadRankings() {
    this.loadingRankings = true;
    this.rankingError = null;

    try {
      const data = await ajax(
        `/quiz/leaderboard.json?metric=${this.metric}&page=${this.page}`
      );
      this.rankingData = data;
    } catch (e) {
      this.rankingError = i18n("discourse_quiz.leaderboard.load_error");
      popupAjaxError(e);
    } finally {
      this.loadingRankings = false;
    }
  }

  @action
  async loadMore() {
    if (!this.canLoadMore || this.loadingRankings) {
      return;
    }

    this.page += 1;
    this.loadingRankings = true;

    try {
      const data = await ajax(
        `/quiz/leaderboard.json?metric=${this.metric}&page=${this.page}`
      );
      this.rankingData = {
        ...data,
        users: [...(this.rankingData?.users || []), ...(data.users || [])],
      };
    } catch (e) {
      this.page -= 1;
      popupAjaxError(e);
    } finally {
      this.loadingRankings = false;
    }
  }

  @action
  openProfile(username) {
    if (!username) {
      return;
    }

    this.profileUsername = username;
    this.activeTab = "profile";
    this.loadProfile();
  }

  @action
  updateProfileUsername(event) {
    this.profileUsername = event.target.value;
  }

  @action
  submitProfileSearch(event) {
    event.preventDefault();
    this.loadProfile();
  }

  @action
  async loadProfile() {
    const username = this.profileUsername?.trim();

    if (!username) {
      this.profileError = i18n("discourse_quiz.leaderboard.profile_username_required");
      this.profileData = null;
      return;
    }

    this.loadingProfile = true;
    this.profileError = null;

    try {
      const data = await ajax(
        `/quiz/leaderboard/user_categories.json?username=${encodeURIComponent(username)}`
      );
      this.profileData = data;
    } catch (e) {
      this.profileData = null;
      this.profileError = i18n("discourse_quiz.leaderboard.profile_not_found");
      popupAjaxError(e);
    } finally {
      this.loadingProfile = false;
    }
  }

  <template>
    <section class="quiz-leaderboard-page">
      <div class="quiz-leaderboard-page__header">
        <h1 class="quiz-leaderboard-page__title">{{i18n "discourse_quiz.leaderboard.title"}}</h1>
      </div>
      <p class="quiz-leaderboard-page__intro">{{i18n "discourse_quiz.leaderboard.intro"}}</p>

      {{#unless this.isEnabled}}
        <p class="quiz-leaderboard-page__notice is-error">
          {{i18n "discourse_quiz.leaderboard.disabled"}}
        </p>
      {{/unless}}

      {{#if this.isEnabled}}
      <nav class="quiz-leaderboard-page__tabs" role="tablist">
        <button
          type="button"
          class="btn btn-default {{if (eq this.activeTab 'rankings') 'active'}}"
          {{on "click" (fn this.setTab "rankings")}}
        >
          {{i18n "discourse_quiz.leaderboard.tab_rankings"}}
        </button>
        <button
          type="button"
          class="btn btn-default {{if (eq this.activeTab 'profile') 'active'}}"
          {{on "click" (fn this.setTab "profile")}}
        >
          {{i18n "discourse_quiz.leaderboard.tab_profile"}}
        </button>
      </nav>

      {{#if (eq this.activeTab "rankings")}}
        <div class="quiz-leaderboard-page__metric-switch" role="tablist">
          <button
            type="button"
            class="quiz-leaderboard-page__metric-btn {{if (eq this.metric 'volume') 'is-active'}}"
            {{on "click" (fn this.setMetric "volume")}}
          >
            {{i18n "discourse_quiz.leaderboard.metric_volume"}}
          </button>
          <button
            type="button"
            class="quiz-leaderboard-page__metric-btn {{if (eq this.metric 'accuracy') 'is-active'}}"
            {{on "click" (fn this.setMetric "accuracy")}}
          >
            {{i18n "discourse_quiz.leaderboard.metric_accuracy"}}
          </button>
        </div>

        <p class="quiz-leaderboard-page__hint">
          {{#if (eq this.metric "accuracy")}}
            {{i18n
              "discourse_quiz.leaderboard.accuracy_hint"
              count=this.siteSettings.quiz_leaderboard_min_attempts
            }}
          {{else}}
            {{i18n "discourse_quiz.leaderboard.volume_hint"}}
          {{/if}}
        </p>

        {{#if this.rankingError}}
          <p class="quiz-leaderboard-page__notice is-error">{{this.rankingError}}</p>
        {{/if}}

        {{#if this.loadingRankings}}
          {{#unless this.users.length}}
            <p>{{i18n "discourse_quiz.loading"}}</p>
          {{/unless}}
        {{/if}}

        {{#if this.showPodium}}
          <div class="quiz-leaderboard-page__podium-wrapper">
            <div class="quiz-leaderboard-page__podium">
              {{#each this.winners as |entry|}}
                <div class="quiz-leaderboard-page__winner {{this.winnerPositionClass entry}}">
                  <div class="quiz-leaderboard-page__winner-crown">{{dIcon "crown"}}</div>
                  <button
                    type="button"
                    class="quiz-leaderboard-page__winner-avatar"
                    {{on "click" (fn this.openProfile entry.username)}}
                  >
                    {{dAvatar entry imageSize="huge"}}
                    <span class="quiz-leaderboard-page__winner-rank">{{entry.position}}</span>
                  </button>
                  <div class="quiz-leaderboard-page__winner-name">{{this.displayName entry}}</div>
                  <div class="quiz-leaderboard-page__winner-value">{{this.valueLabel entry}}</div>
                </div>
              {{/each}}
            </div>
          </div>
        {{/if}}

        {{#if this.users.length}}
          <div class="quiz-leaderboard-page__ranking">
            <div class="quiz-leaderboard-page__ranking-head">
              <span>{{i18n "discourse_quiz.leaderboard.rank_column"}}</span>
              <span>
                {{dIcon "award"}}
                {{this.metricColumnLabel}}
              </span>
            </div>

            {{#if this.personal}}
              {{#if this.personal.ineligible}}
                <p class="quiz-leaderboard-page__personal-note">
                  {{i18n
                    "discourse_quiz.leaderboard.personal_ineligible"
                    count=this.personal.min_attempts
                    attempted=this.personal.questions_attempted
                  }}
                </p>
              {{else}}
                <article class="quiz-leaderboard-page__self-row">
                  <span class="quiz-leaderboard-page__self-rank">{{this.personal.position}}</span>
                  <span class="quiz-leaderboard-page__self-label">
                    {{i18n "discourse_quiz.leaderboard.personal_you"}}
                  </span>
                  <span class="quiz-leaderboard-page__self-value">{{this.valueLabel this.personal}}</span>
                </article>
              {{/if}}
            {{/if}}

            {{#if this.listUsers.length}}
              <div class="quiz-leaderboard-page__list">
                {{#each this.listUsers as |entry|}}
                  <article class="quiz-leaderboard-page__row">
                    <span class="quiz-leaderboard-page__rank">{{entry.position}}</span>
                    <button
                      type="button"
                      class="quiz-leaderboard-page__user"
                      {{on "click" (fn this.openProfile entry.username)}}
                    >
                      {{dAvatar entry imageSize="large"}}
                      <span class="quiz-leaderboard-page__name">{{this.displayName entry}}</span>
                    </button>
                    <span class="quiz-leaderboard-page__value">{{this.valueLabel entry}}</span>
                  </article>
                {{/each}}
              </div>
            {{/if}}

            {{#if this.canLoadMore}}
              <div class="quiz-leaderboard-page__more">
                <button
                  type="button"
                  class="btn btn-default"
                  disabled={{this.loadingRankings}}
                  {{on "click" this.loadMore}}
                >
                  {{i18n "discourse_quiz.leaderboard.load_more"}}
                </button>
              </div>
            {{/if}}
          </div>
        {{else if (not this.loadingRankings)}}
          <p class="quiz-leaderboard-page__empty">{{i18n "discourse_quiz.leaderboard.empty"}}</p>
        {{/if}}
      {{/if}}

      {{#if (eq this.activeTab "profile")}}
        <p class="quiz-leaderboard-page__hint">{{i18n "discourse_quiz.leaderboard.profile_hint"}}</p>

        <form class="quiz-leaderboard-page__profile-search" {{on "submit" this.submitProfileSearch}}>
          <label>
            <span>{{i18n "discourse_quiz.leaderboard.profile_username"}}</span>
            <input
              type="text"
              value={{this.profileUsername}}
              {{on "input" this.updateProfileUsername}}
            />
          </label>
          <button type="submit" class="btn btn-primary" disabled={{this.loadingProfile}}>
            {{i18n "discourse_quiz.leaderboard.profile_search"}}
          </button>
        </form>

        {{#if this.profileError}}
          <p class="quiz-leaderboard-page__notice is-error">{{this.profileError}}</p>
        {{/if}}

        {{#if this.loadingProfile}}
          <p>{{i18n "discourse_quiz.loading"}}</p>
        {{/if}}

        {{#if this.profileData}}
          <div class="quiz-leaderboard-page__profile-summary">
            {{dAvatar this.profileData.user imageSize="large"}}
            <div>
              <strong>{{this.profileData.user.username}}</strong>
              <span class="quiz-leaderboard-page__profile-summary-text">
                {{i18n
                  "discourse_quiz.leaderboard.profile_summary"
                  attempted=this.profileData.user.questions_attempted
                  correct=this.profileData.user.questions_correct
                }}
                {{this.accuracyLabel this.profileData.user.accuracy_rate}}
              </span>
            </div>
          </div>

          {{#if this.profileCategories.length}}
            <div class="quiz-leaderboard-page__profile-table-wrapper">
            <table class="quiz-leaderboard-page__profile-table">
              <thead>
                <tr>
                  <th>{{i18n "discourse_quiz.leaderboard.category_column"}}</th>
                  <th>{{i18n "discourse_quiz.leaderboard.questions_column"}}</th>
                  <th>{{i18n "discourse_quiz.leaderboard.correct_column"}}</th>
                  <th>{{i18n "discourse_quiz.leaderboard.accuracy_column"}}</th>
                </tr>
              </thead>
              <tbody>
                {{#each this.profileCategories as |row|}}
                  <tr>
                    <td>{{row.category_name}}</td>
                    <td>{{row.questions_attempted}}</td>
                    <td>{{row.questions_correct}}</td>
                    <td>{{this.accuracyLabel row.accuracy_rate}}</td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
            </div>
          {{else}}
            <p>{{i18n "discourse_quiz.leaderboard.profile_empty"}}</p>
          {{/if}}
        {{/if}}
      {{/if}}
      {{/if}}
    </section>
  </template>
}
