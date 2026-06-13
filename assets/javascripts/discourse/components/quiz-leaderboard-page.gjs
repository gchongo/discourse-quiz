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
import DButton from "discourse/ui-kit/d-button";
import PeriodChooser from "discourse/select-kit/components/period-chooser";
import { i18n } from "discourse-i18n";
import QuizLeaderboardInfo from "./modal/quiz-leaderboard-info";

export default class QuizLeaderboardPage extends Component {
  @service currentUser;
  @service site;
  @service modal;
  @service siteSettings;

  @tracked activeTab = "rankings";
  @tracked metric = "volume";
  @tracked period = "all";
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
  showLeaderboardInfo() {
    this.modal.show(QuizLeaderboardInfo);
  }

  @action
  setTab(tab) {
    if (!this.isEnabled) {
      return;
    }

    this.activeTab = tab;

    if (
      tab === "profile" &&
      this.profileUsername &&
      (!this.profileData ||
        this.profileData.user?.username !== this.profileUsername)
    ) {
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
  setPeriod(period) {
    if (this.period === period) {
      return;
    }

    this.period = period;
    this.page = 1;
    this.loadRankings();

    if (this.activeTab === "profile" && this.profileUsername?.trim()) {
      this.loadProfile();
    }
  }

  @action
  async loadRankings() {
    this.loadingRankings = true;
    this.rankingError = null;

    try {
      const data = await ajax(
        `/quiz/leaderboard.json?metric=${this.metric}&period=${this.period}&page=${this.page}`
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
        `/quiz/leaderboard.json?metric=${this.metric}&period=${this.period}&page=${this.page}`
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
    this.profileData = null;
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
        `/quiz/leaderboard/user_categories.json?username=${encodeURIComponent(username)}&period=${this.period}`
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
      <div class="quiz-leaderboard-page__header page__header">
        <h1 class="quiz-leaderboard-page__title page__title">
          {{i18n "discourse_quiz.leaderboard.title"}}
        </h1>
        <DButton
          @action={{this.showLeaderboardInfo}}
          class="-ghost"
          @icon="circle-info"
          @label={{unless this.site.mobileView "discourse_quiz.leaderboard.info"}}
          @title={{if this.site.mobileView "discourse_quiz.leaderboard.info"}}
        />
      </div>

      {{#unless this.isEnabled}}
        <p class="quiz-leaderboard-page__notice is-error">
          {{i18n "discourse_quiz.leaderboard.disabled"}}
        </p>
      {{/unless}}

      {{#if this.isEnabled}}
      <div class="quiz-leaderboard-page__toolbar">
        {{#if (eq this.activeTab "profile")}}
          <button
            type="button"
            class="quiz-leaderboard-page__back-btn"
            title={{i18n "discourse_quiz.leaderboard.back"}}
            {{on "click" (fn this.setTab "rankings")}}
          >
            {{dIcon "arrow-left"}}
          </button>
        {{else}}
          <span class="quiz-leaderboard-page__toolbar-spacer" aria-hidden="true"></span>
        {{/if}}

        {{#if (eq this.activeTab "rankings")}}
          <PeriodChooser
            @period={{this.period}}
            @action={{this.setPeriod}}
            @fullDay={{false}}
            class="quiz-leaderboard-page__period-chooser"
          />

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
        {{else}}
          <span class="quiz-leaderboard-page__toolbar-profile-title">
            {{i18n "discourse_quiz.leaderboard.tab_profile"}}
          </span>
        {{/if}}

        {{#unless (eq this.activeTab "profile")}}
          <button
            type="button"
            class="quiz-leaderboard-page__profile-btn"
            title={{i18n "discourse_quiz.leaderboard.tab_profile"}}
            {{on "click" (fn this.setTab "profile")}}
          >
            {{dIcon "chart-pie"}}
            {{#unless this.site.mobileView}}
              <span class="quiz-leaderboard-page__profile-btn-label">
                {{i18n "discourse_quiz.leaderboard.tab_profile"}}
              </span>
            {{/unless}}
          </button>
        {{/unless}}
      </div>

      {{#if (eq this.activeTab "rankings")}}
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
        <div class="quiz-leaderboard-page__profile-panel">
          <form class="quiz-leaderboard-page__search-bar" {{on "submit" this.submitProfileSearch}}>
            <div class="quiz-leaderboard-page__search-input-group">
              <input
                type="text"
                class="quiz-leaderboard-page__search-input"
                value={{this.profileUsername}}
                placeholder={{i18n "discourse_quiz.leaderboard.profile_username_placeholder"}}
                {{on "input" this.updateProfileUsername}}
              />
            </div>
            <button
              type="submit"
              class="btn btn-primary quiz-leaderboard-page__search-submit"
              disabled={{this.loadingProfile}}
            >
              {{i18n "discourse_quiz.leaderboard.profile_search"}}
            </button>
          </form>

          {{#if this.profileError}}
            <p class="quiz-leaderboard-page__notice is-error">{{this.profileError}}</p>
          {{/if}}

          {{#if this.loadingProfile}}
            <p class="quiz-leaderboard-page__profile-loading">{{i18n "discourse_quiz.loading"}}</p>
          {{/if}}

          {{#if this.profileData}}
            <article class="quiz-leaderboard-page__profile-summary">
              {{dAvatar this.profileData.user imageSize="large"}}
              <div class="quiz-leaderboard-page__profile-summary-body">
                <span class="quiz-leaderboard-page__profile-username">
                  {{this.profileData.user.username}}
                </span>
                <span class="quiz-leaderboard-page__profile-summary-text">
                  {{i18n
                    "discourse_quiz.leaderboard.profile_summary"
                    attempted=this.profileData.user.questions_attempted
                    correct=this.profileData.user.questions_correct
                  }}
                  {{this.accuracyLabel this.profileData.user.accuracy_rate}}
                </span>
              </div>
            </article>

            {{#if this.profileCategories.length}}
              <div class="quiz-leaderboard-page__category-board">
                <div class="quiz-leaderboard-page__category-head">
                  <span>{{i18n "discourse_quiz.leaderboard.category_column"}}</span>
                  <span>{{i18n "discourse_quiz.leaderboard.questions_column"}}</span>
                  <span>{{i18n "discourse_quiz.leaderboard.correct_column"}}</span>
                  <span>{{i18n "discourse_quiz.leaderboard.accuracy_column"}}</span>
                </div>
                <div class="quiz-leaderboard-page__category-list">
                  {{#each this.profileCategories as |row|}}
                    <article class="quiz-leaderboard-page__category-row">
                      <span class="quiz-leaderboard-page__category-name">{{row.category_name}}</span>
                      <span class="quiz-leaderboard-page__category-stat">{{row.questions_attempted}}</span>
                      <span class="quiz-leaderboard-page__category-stat">{{row.questions_correct}}</span>
                      <span class="quiz-leaderboard-page__category-stat is-accent">
                        {{this.accuracyLabel row.accuracy_rate}}
                      </span>
                    </article>
                  {{/each}}
                </div>
              </div>
            {{else}}
              <p class="quiz-leaderboard-page__empty">{{i18n "discourse_quiz.leaderboard.profile_empty"}}</p>
            {{/if}}
          {{/if}}
        </div>
      {{/if}}
      {{/if}}
    </section>
  </template>
}
