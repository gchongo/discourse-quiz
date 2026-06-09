import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import DButton from "discourse/ui-kit/d-button";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "discourse/truth-helpers";

const EMPTY_REWARD = {
  name: "",
  description: "",
  category: "",
  image_url: "",
  points_threshold: 100,
  stock: "",
  position: 0,
  active: true,
};

export default class AdminQuizRewards extends Component {
  @tracked rewards = [];
  @tracked claims = [];
  @tracked loadError = null;
  @tracked loading = true;
  @tracked saving = false;
  @tracked editingReward = null;
  @tracked showForm = false;

  constructor() {
    super(...arguments);
    this.loadRewards();
  }

  get formReward() {
    return this.editingReward || EMPTY_REWARD;
  }

  get saveDisabled() {
    return this.saving || !this.formReward.name?.trim();
  }

  @action
  async loadRewards() {
    this.loading = true;
    this.loadError = null;

    try {
      const data = await ajax("/admin/quiz/rewards.json");
      this.rewards = data.rewards || [];
      this.claims = data.claims || [];
    } catch (e) {
      this.loadError = e?.jqXHR?.responseJSON?.error || i18n("discourse_quiz.load_error");
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  openCreateForm() {
    this.editingReward = { ...EMPTY_REWARD };
    this.showForm = true;
  }

  @action
  openEditForm(reward) {
    this.editingReward = {
      ...reward,
      stock: reward.stock === null || reward.stock === undefined ? "" : reward.stock,
    };
    this.showForm = true;
  }

  @action
  closeForm() {
    this.showForm = false;
    this.editingReward = null;
  }

  @action
  updateField(field, event) {
    const value =
      event.target.type === "checkbox" ? event.target.checked : event.target.value;

    this.editingReward = {
      ...this.editingReward,
      [field]: value,
    };
  }

  @action
  async saveReward() {
    if (!this.editingReward?.name?.trim()) {
      return;
    }

    this.saving = true;

    try {
      const payload = {
        reward: {
          ...this.editingReward,
          points_threshold: parseInt(this.editingReward.points_threshold, 10) || 0,
          position: parseInt(this.editingReward.position, 10) || 0,
          stock:
            this.editingReward.stock === "" || this.editingReward.stock === null
              ? null
              : parseInt(this.editingReward.stock, 10),
        },
      };

      if (this.editingReward.id) {
        await ajax(`/admin/quiz/rewards/${this.editingReward.id}.json`, {
          type: "PUT",
          data: payload,
        });
      } else {
        await ajax("/admin/quiz/rewards.json", {
          type: "POST",
          data: payload,
        });
      }

      this.closeForm();
      this.loadRewards();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  @action
  async deleteReward(reward) {
    if (!confirm(i18n("discourse_quiz.admin.rewards_confirm_delete"))) {
      return;
    }

    try {
      await ajax(`/admin/quiz/rewards/${reward.id}.json`, { type: "DELETE" });
      this.loadRewards();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async updateClaimStatus(claim, status) {
    try {
      await ajax(`/admin/quiz/reward_claims/${claim.id}.json`, {
        type: "PUT",
        data: { status },
      });
      this.loadRewards();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  stockLabel = (reward) => {
    if (reward.stock === null || reward.stock === undefined) {
      return i18n("discourse_quiz.rewards.unlimited_stock");
    }

    return reward.remaining_stock ?? reward.stock;
  };

  claimStatusLabel = (status) => {
    return i18n(`discourse_quiz.admin.rewards_status_${status}`);
  };

  <template>
    <div class="admin-discourse-quiz-rewards">
      <div class="admin-discourse-quiz-rewards__toolbar">
        <DButton
          @label="discourse_quiz.admin.rewards_create"
          @action={{this.openCreateForm}}
          class="btn-primary"
        />
      </div>

      {{#if this.loadError}}
        <p class="alert alert-error">{{this.loadError}}</p>
      {{/if}}

      {{#if this.showForm}}
        <div class="admin-discourse-quiz-rewards__form">
          <div class="admin-discourse-quiz-rewards__form-header">
            <h3>
              {{#if this.editingReward.id}}
                {{i18n "discourse_quiz.admin.rewards_edit"}}
              {{else}}
                {{i18n "discourse_quiz.admin.rewards_create"}}
              {{/if}}
            </h3>
            <DButton
              @icon="xmark"
              @action={{this.closeForm}}
              @title="cancel"
              class="btn-flat btn-small admin-discourse-quiz-rewards__form-close"
            />
          </div>

          <div class="quiz-admin-form">
            <label class="quiz-admin-form__field">
              <span>{{i18n "discourse_quiz.admin.rewards_form.name"}}</span>
              <input type="text" value={{this.formReward.name}} {{on "input" (fn this.updateField "name")}} />
            </label>
            <label class="quiz-admin-form__field">
              <span>{{i18n "discourse_quiz.admin.rewards_form.description"}}</span>
              <textarea rows="3" {{on "input" (fn this.updateField "description")}}>{{this.formReward.description}}</textarea>
            </label>
            <label class="quiz-admin-form__field">
              <span>{{i18n "discourse_quiz.admin.rewards_form.category"}}</span>
              <input type="text" value={{this.formReward.category}} {{on "input" (fn this.updateField "category")}} />
            </label>
            <label class="quiz-admin-form__field">
              <span>{{i18n "discourse_quiz.admin.rewards_form.image_url"}}</span>
              <input type="text" value={{this.formReward.image_url}} {{on "input" (fn this.updateField "image_url")}} />
            </label>
            <div class="admin-discourse-quiz-rewards__form-row">
              <label class="quiz-admin-form__field">
                <span>{{i18n "discourse_quiz.admin.rewards_form.points_threshold"}}</span>
                <input type="number" min="1" value={{this.formReward.points_threshold}} {{on "input" (fn this.updateField "points_threshold")}} />
              </label>
              <label class="quiz-admin-form__field">
                <span>{{i18n "discourse_quiz.admin.rewards_form.stock"}}</span>
                <input type="number" min="0" value={{this.formReward.stock}} {{on "input" (fn this.updateField "stock")}} />
              </label>
            </div>
            <div class="admin-discourse-quiz-rewards__form-row">
              <label class="quiz-admin-form__field">
                <span>{{i18n "discourse_quiz.admin.rewards_form.position"}}</span>
                <input type="number" min="0" value={{this.formReward.position}} {{on "input" (fn this.updateField "position")}} />
              </label>
              <label class="quiz-admin-form__checkbox">
                <input type="checkbox" checked={{this.formReward.active}} {{on "change" (fn this.updateField "active")}} />
                <span>{{i18n "discourse_quiz.admin.rewards_form.active"}}</span>
              </label>
            </div>
          </div>

          <div class="admin-discourse-quiz-rewards__form-actions">
            <DButton @label="cancel" @action={{this.closeForm}} class="btn-default" />
            <DButton
              @label={{if this.saving "discourse_quiz.admin.saving" "discourse_quiz.admin.save"}}
              @action={{this.saveReward}}
              @disabled={{this.saveDisabled}}
              class="btn-primary"
            />
          </div>
        </div>
      {{/if}}

      {{#if this.loading}}
        <p>{{i18n "discourse_quiz.loading"}}</p>
      {{else if this.rewards.length}}
        <div class="admin-discourse-quiz-rewards__cards">
          {{#each this.rewards as |reward|}}
            <article class="admin-discourse-quiz-rewards__card">
              <div class="admin-discourse-quiz-rewards__card-header">
                <div class="admin-discourse-quiz-rewards__card-title">
                  <strong>{{reward.name}}</strong>
                  {{#if reward.category}}
                    <span class="admin-discourse-quiz-rewards__card-category">{{reward.category}}</span>
                  {{/if}}
                </div>
                <span class="admin-discourse-quiz-rewards__card-status">
                  {{#if reward.active}}
                    <span
                      class="quiz-admin-active-indicator is-active"
                      title={{i18n "discourse_quiz.admin.yes"}}
                      aria-label={{i18n "discourse_quiz.admin.yes"}}
                    ></span>
                  {{else}}
                    <span
                      class="quiz-admin-active-indicator is-inactive"
                      title={{i18n "discourse_quiz.admin.no"}}
                      aria-label={{i18n "discourse_quiz.admin.no"}}
                    ></span>
                  {{/if}}
                </span>
              </div>
              <dl class="admin-discourse-quiz-rewards__card-stats">
                <div>
                  <dt>{{i18n "discourse_quiz.admin.rewards_table.threshold"}}</dt>
                  <dd>{{reward.points_threshold}}</dd>
                </div>
                <div>
                  <dt>{{i18n "discourse_quiz.admin.rewards_table.stock"}}</dt>
                  <dd>{{this.stockLabel reward}}</dd>
                </div>
                <div>
                  <dt>{{i18n "discourse_quiz.admin.rewards_table.claims"}}</dt>
                  <dd>{{reward.claims_count}}</dd>
                </div>
              </dl>
              <div class="admin-discourse-quiz-rewards__card-actions">
                <DButton @action={{fn this.openEditForm reward}} @label="discourse_quiz.admin.edit" class="btn-default btn-small" />
                <DButton @action={{fn this.deleteReward reward}} @label="discourse_quiz.admin.rewards_delete" class="btn-danger btn-small" />
              </div>
            </article>
          {{/each}}
        </div>

        <table class="admin-discourse-quiz-rewards__table admin-discourse-quiz-rewards__table--desktop">
          <thead>
            <tr>
              <th>{{i18n "discourse_quiz.admin.rewards_table.name"}}</th>
              <th>{{i18n "discourse_quiz.admin.rewards_table.category"}}</th>
              <th>{{i18n "discourse_quiz.admin.rewards_table.threshold"}}</th>
              <th>{{i18n "discourse_quiz.admin.rewards_table.stock"}}</th>
              <th>{{i18n "discourse_quiz.admin.rewards_table.claims"}}</th>
              <th>{{i18n "discourse_quiz.admin.rewards_table.active"}}</th>
              <th>{{i18n "discourse_quiz.admin.rewards_table.actions"}}</th>
            </tr>
          </thead>
          <tbody>
            {{#each this.rewards as |reward|}}
              <tr>
                <td>{{reward.name}}</td>
                <td>{{reward.category}}</td>
                <td>{{reward.points_threshold}}</td>
                <td>{{this.stockLabel reward}}</td>
                <td>{{reward.claims_count}}</td>
                <td class="admin-discourse-quiz-rewards__col-active">
                  {{#if reward.active}}
                    <span
                      class="quiz-admin-active-indicator is-active"
                      title={{i18n "discourse_quiz.admin.yes"}}
                      aria-label={{i18n "discourse_quiz.admin.yes"}}
                    ></span>
                  {{else}}
                    <span
                      class="quiz-admin-active-indicator is-inactive"
                      title={{i18n "discourse_quiz.admin.no"}}
                      aria-label={{i18n "discourse_quiz.admin.no"}}
                    ></span>
                  {{/if}}
                </td>
                <td>
                  <DButton @action={{fn this.openEditForm reward}} @label="discourse_quiz.admin.edit" class="btn-default btn-small" />
                  <DButton @action={{fn this.deleteReward reward}} @label="discourse_quiz.admin.rewards_delete" class="btn-danger btn-small" />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <p>{{i18n "discourse_quiz.admin.rewards_empty"}}</p>
      {{/if}}

      <h3>{{i18n "discourse_quiz.admin.rewards_claims_title"}}</h3>
      {{#if this.claims.length}}
        <div class="admin-discourse-quiz-rewards__cards admin-discourse-quiz-rewards__cards--claims">
          {{#each this.claims as |claim|}}
            <article class="admin-discourse-quiz-rewards__card">
              <div class="admin-discourse-quiz-rewards__card-header">
                <strong>{{claim.username}}</strong>
                <span>{{claim.reward_name}}</span>
              </div>
              <dl class="admin-discourse-quiz-rewards__card-stats">
                <div>
                  <dt>{{i18n "discourse_quiz.admin.rewards_claims_table.status"}}</dt>
                  <dd>{{this.claimStatusLabel claim.status}}</dd>
                </div>
                <div>
                  <dt>{{i18n "discourse_quiz.admin.rewards_claims_table.date"}}</dt>
                  <dd>{{claim.created_at}}</dd>
                </div>
              </dl>
              {{#if (eq claim.status "pending")}}
                <div class="admin-discourse-quiz-rewards__card-actions">
                  <DButton
                    @label="discourse_quiz.admin.rewards_mark_fulfilled"
                    @action={{fn this.updateClaimStatus claim "fulfilled"}}
                    class="btn-default btn-small"
                  />
                  <DButton
                    @label="discourse_quiz.admin.rewards_mark_cancelled"
                    @action={{fn this.updateClaimStatus claim "cancelled"}}
                    class="btn-danger btn-small"
                  />
                </div>
              {{/if}}
            </article>
          {{/each}}
        </div>

        <table class="admin-discourse-quiz-rewards__table admin-discourse-quiz-rewards__table--desktop">
          <thead>
            <tr>
              <th>{{i18n "discourse_quiz.admin.rewards_claims_table.user"}}</th>
              <th>{{i18n "discourse_quiz.admin.rewards_claims_table.reward"}}</th>
              <th>{{i18n "discourse_quiz.admin.rewards_claims_table.status"}}</th>
              <th>{{i18n "discourse_quiz.admin.rewards_claims_table.date"}}</th>
              <th>{{i18n "discourse_quiz.admin.rewards_claims_table.actions"}}</th>
            </tr>
          </thead>
          <tbody>
            {{#each this.claims as |claim|}}
              <tr>
                <td>{{claim.username}}</td>
                <td>{{claim.reward_name}}</td>
                <td>{{this.claimStatusLabel claim.status}}</td>
                <td>{{claim.created_at}}</td>
                <td>
                  {{#if (eq claim.status "pending")}}
                    <DButton
                      @label="discourse_quiz.admin.rewards_mark_fulfilled"
                      @action={{fn this.updateClaimStatus claim "fulfilled"}}
                      class="btn-default btn-small"
                    />
                    <DButton
                      @label="discourse_quiz.admin.rewards_mark_cancelled"
                      @action={{fn this.updateClaimStatus claim "cancelled"}}
                      class="btn-danger btn-small"
                    />
                  {{/if}}
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <p>{{i18n "discourse_quiz.admin.rewards_claims_empty"}}</p>
      {{/if}}
    </div>
  </template>
}
