import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { on } from "@ember/modifier";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { htmlSafe } from "@ember/template";
import { and, eq, not } from "discourse/truth-helpers";
import QuizHome from "./quiz-home";
import QuizQuestionDisplay from "./quiz-question-display";
import QuizResultDisplay from "./quiz-result-display";
import QuizPaywall from "./quiz-paywall";
import QuizRulesModal from "./quiz-rules-modal";

export default class QuizPanel extends Component {
  @service quiz;
  @service siteSettings;
  @service modal;

  @tracked isDragging = false;

  _panelElement = null;
  _dragStartX = 0;
  _dragStartY = 0;
  _dragStartLeft = 0;
  _dragStartTop = 0;

  get panelStyles() {
    if (this.quiz.isMobile) {
      return "";
    }

    let styles = "--quiz-panel-width: 340px;";

    if (this.quiz.isDraggable && this.quiz.hasCustomPosition) {
      styles += `--quiz-panel-left: ${this.quiz.panelLeft}px; --quiz-panel-top: ${this.quiz.panelTop}px;`;
    }

    return htmlSafe(styles);
  }

  @action
  setupLayout() {
    this.quiz.registerLayoutListeners();
  }

  @action
  teardownLayout() {
    this.stopDragging();
    this.quiz.unregisterLayoutListeners();
  }

  get containerClass() {
    const classes = ["quiz-panel-container"];

    if (this.quiz.isMobile) {
      classes.push("is-mobile");
    } else {
      classes.push(this.quiz.isDockedEffective ? "is-docked" : "is-floating");
    }

    if (this.quiz.isMinimized) {
      classes.push("is-minimized");
    }

    if (this.quiz.panelVisible) {
      classes.push("is-visible");
    }

    if (this.quiz.isDraggable && this.quiz.hasCustomPosition) {
      classes.push("is-positioned");
    }

    if (this.isDragging) {
      classes.push("is-dragging");
    }

    if (this.quiz.isPlaying && !this.quiz.isMinimized) {
      classes.push("is-quiz-active");
    }

    return classes.join(" ");
  }

  @action
  onHeaderPointerDown(event) {
    if (!this.quiz.isDraggable || event.button !== 0) {
      return;
    }

    if (
      event.target.closest(
        ".quiz-panel-controls, .quiz-panel-back-btn, .quiz-panel-info-btn, .btn"
      )
    ) {
      return;
    }

    const panel = event.currentTarget.closest(".quiz-panel-container");
    this._panelElement = panel;

    const rect = panel.getBoundingClientRect();

    if (!this.quiz.hasCustomPosition) {
      this.quiz.setPanelPosition(rect.left, rect.top);
    }

    this.isDragging = true;
    this._dragStartX = event.clientX;
    this._dragStartY = event.clientY;
    this._dragStartLeft = this.quiz.panelLeft;
    this._dragStartTop = this.quiz.panelTop;

    document.addEventListener("pointermove", this.onDragMove);
    document.addEventListener("pointerup", this.onDragEnd);
    document.addEventListener("pointercancel", this.onDragEnd);

    event.preventDefault();
  }

  @action
  onDragMove(event) {
    if (!this.isDragging || !this._panelElement) {
      return;
    }

    const rect = this._panelElement.getBoundingClientRect();
    const left = this._dragStartLeft + (event.clientX - this._dragStartX);
    const top = this._dragStartTop + (event.clientY - this._dragStartY);
    const clamped = this.quiz.clampPanelPosition(left, top, rect.width, rect.height);

    this.quiz.panelLeft = clamped.left;
    this.quiz.panelTop = clamped.top;
  }

  @action
  onDragEnd() {
    if (!this.isDragging) {
      return;
    }

    this.isDragging = false;
    this.stopDragging();
  }

  stopDragging() {
    document.removeEventListener("pointermove", this.onDragMove);
    document.removeEventListener("pointerup", this.onDragEnd);
    document.removeEventListener("pointercancel", this.onDragEnd);
    this._panelElement = null;
  }

  @action
  showRules() {
    this.modal.show(QuizRulesModal);
  }

  <template>
    {{#if this.quiz.isEnabled}}
      <div
        class={{this.containerClass}}
        style={{this.panelStyles}}
        {{didInsert this.setupLayout}}
        {{willDestroy this.teardownLayout}}
      >
        <div
          class="quiz-panel-header {{if this.quiz.isDraggable 'is-draggable'}}"
          title={{if this.quiz.isDraggable (i18n "gamified_quiz.drag_panel")}}
          {{on "pointerdown" this.onHeaderPointerDown}}
        >
          <div class="quiz-panel-title-row">
            {{#if (and this.quiz.isPlaying (not this.quiz.isMinimized))}}
              <DButton
                @icon="arrow-left"
                @action={{this.quiz.showHome}}
                @title="discourse_quiz.back_to_home"
                class="btn-default quiz-panel-control-btn quiz-panel-back-btn"
              />
            {{/if}}
            <span class="quiz-panel-title">{{i18n "gamified_quiz.panel_title"}}</span>
            <DButton
              @icon="circle-info"
              @action={{this.showRules}}
              @title="discourse_quiz.rules_modal.button_title"
              class="btn-transparent quiz-panel-info-btn"
            />
          </div>
          <div class="quiz-panel-header-actions">
            <DButton
              @icon={{if this.quiz.isMinimized "angles-up" "angles-down"}}
              @action={{this.quiz.toggleMinimize}}
              @title={{if
                this.quiz.isMinimized
                "gamified_quiz.expand_panel"
                "gamified_quiz.minimize_panel"
              }}
              class="btn-default quiz-panel-control-btn quiz-panel-minimize-btn"
            />
            <div class="quiz-panel-controls">
              {{#if this.quiz.canDock}}
                <DButton
                  @icon={{if this.quiz.isDocked "up-right-from-square" "table-columns"}}
                  @action={{this.quiz.toggleDock}}
                  @title={{if this.quiz.isDocked "gamified_quiz.undock_panel" "gamified_quiz.dock_panel"}}
                  class="btn-default quiz-panel-control-btn"
                />
              {{/if}}
              <DButton
                @icon="xmark"
                @action={{this.quiz.closePanel}}
                @title="gamified_quiz.close_panel"
                class="btn-default quiz-panel-control-btn quiz-panel-close-btn"
              />
            </div>
          </div>
        </div>
        <div class="quiz-panel-content">
          {{#if this.quiz.panelVisible}}
            {{#if this.quiz.paywallActive}}
              <QuizPaywall @status={{this.quiz.quizStatus}} />
            {{else if (and this.quiz.loading (not (eq this.quiz.panelPhase "home")))}}
              <p class="quiz-panel-placeholder">{{i18n "discourse_quiz.loading"}}</p>
            {{else if (eq this.quiz.panelPhase "home")}}
              {{#if this.quiz.errorMessage}}
                <p class="quiz-panel-error">{{this.quiz.errorMessage}}</p>
              {{else}}
                <QuizHome />
              {{/if}}
            {{else if this.quiz.errorMessage}}
              <p class="quiz-panel-error">{{this.quiz.errorMessage}}</p>
              <DButton
                @label="discourse_quiz.back_to_home"
                @action={{this.quiz.showHome}}
                class="btn-default"
              />
            {{else if this.quiz.currentQuestion}}
              {{#if this.quiz.answerResult}}
                <QuizResultDisplay
                  @question={{this.quiz.currentQuestion}}
                  @result={{this.quiz.answerResult}}
                />
              {{else}}
                <QuizQuestionDisplay @question={{this.quiz.currentQuestion}} />
              {{/if}}
            {{/if}}
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
