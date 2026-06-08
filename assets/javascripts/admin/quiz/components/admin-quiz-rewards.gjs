import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import DButton from "discourse/ui-kit/d-button";
import { on } from "@ember/modifier";
import { eq, not } from "discourse/truth-helpers";

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
  @service modal;

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

  stockLabel(reward) {
    if (reward.stock === null || reward.stock === undefined) {
      return i18n("discourse_quiz.rewards.unlimited_stock");
    }

    return reward.remaining_stock ?? reward.stock;
  }

  claimStatusLabel(status) {
    return i18n(`discourse_quiz.admin.rewards_status_${status}`);
  }

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
          <h3>
            {{#if this.editingReward.id}}
              {{i18n "discourse_quiz.admin.rewards_edit"}}
            {{else}}
              {{i18n "discourse_quiz.admin.rewards_create"}}
            {{/if}}
          </h3>

          <label>
            {{i18n "discourse_quiz.admin.rewards_form.name"}}
            <input type="text" value={{this.formReward.name}} {{on "input" (fn this.updateField "name")}} />
          </label>
          <label>
            {{i18n "discourse_quiz.admin.rewards_form.description"}}
            <textarea rows="3" {{on "input" (fn this.updateField "description")}}>{{this.formReward.description}}</textarea>
          </label>
          <label>
            {{i18n "discourse_quiz.admin.rewards_form.category"}}
            <input type="text" value={{this.formReward.category}} {{on "input" (fn this.updateField "category")}} />
          </label>
          <label>
            {{i18n "discourse_quiz.admin.rewards_form.image_url"}}
            <input type="text" value={{this.formReward.image_url}} {{on "input" (fn this.updateField "image_url")}} />
          </label>
          <label>
            {{i18n "discourse_quiz.admin.rewards_form.points_threshold"}}
            <input type="number" min="1" value={{this.formReward.points_threshold}} {{on "input" (fn this.updateField "points_threshold")}} />
          </label>
          <label>
            {{i18n "discourse_quiz.admin.rewards_form.stock"}}
            <input type="number" min="0" value={{this.formReward.stock}} {{on "input" (fn this.updateField "stock")}} />
          </label>
          <label>
            {{i18n "discourse_quiz.admin.rewards_form.position"}}
            <input type="number" min="0" value={{this.formReward.position}} {{on "input" (fn this.updateField "position")}} />
          </label>
          <label class="checkbox-label">
            <input type="checkbox" checked={{this.formReward.active}} {{on "change" (fn this.updateField "active")}} />
            {{i18n "discourse_quiz.admin.rewards_form.active"}}
          </label>

          <div class="admin-discourse-quiz-rewards__form-actions">
            <DButton
              @label="discourse_quiz.admin.save"
              @action={{this.saveReward}}
              @disabled={{or this.saving (not this.formReward.name)}}
              class="btn-primary"
            />
            <DButton @label="discourse_quiz.admin.no" @action={{this.closeForm}} class="btn-default" />
          </div>
        </div>
      {{/if}}

      {{#if this.loading}}
        <p>{{i18n "discourse_quiz.loading"}}</p>
      {{else if this.rewards.length}}
        <table class="admin-discourse-quiz-rewards__table">
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
                <td>{{if reward.active (i18n "discourse_quiz.admin.yes") (i18n "discourse_quiz.admin.no")}}</td>
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
        <table class="admin-discourse-quiz-rewards__table">
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
