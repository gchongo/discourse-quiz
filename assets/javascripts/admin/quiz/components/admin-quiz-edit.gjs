import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import dButton from "discourse/components/d-button";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";

export default class AdminQuizEdit extends Component {
  @tracked categoryName = this.args.question.category_name;
  @tracked questionText = this.args.question.question_text;
  @tracked optionsString = (this.args.question.options || []).join("\n");
  @tracked correctIndex = this.args.question.correct_index;
  @tracked explanation = this.args.question.explanation;
  @tracked sourceTopicId = this.args.question.source_topic_id;
  @tracked active = !!this.args.question.active;

  @action
  updateField(field, event) {
    this[field] = event.target.value;
  }

  @action
  updateActive(event) {
    this.active = event.target.checked;
  }

  @action
  save() {
    const data = {
      id: this.args.question.id,
      category_name: this.categoryName,
      question_text: this.questionText,
      options: this.optionsString.split("\n").filter(o => o.trim().length > 0),
      correct_index: parseInt(this.correctIndex, 10),
      explanation: this.explanation,
      source_topic_id: this.sourceTopicId,
      active: this.active
    };
    this.args.onSave(data);
  }

  <template>
    <div class="admin-quiz-edit-modal">
      <div class="edit-form">
        <div class="control-group">
          <label>{{i18n "admin.gamified_quiz.form.category"}}</label>
          <input
            type="text"
            value={{this.categoryName}}
            class="form-control"
            {{on "input" (fn this.updateField "categoryName")}}
          />
        </div>

        <div class="control-group">
          <label>{{i18n "admin.gamified_quiz.form.question_text"}}</label>
          <textarea
            value={{this.questionText}}
            class="form-control"
            {{on "input" (fn this.updateField "questionText")}}
          ></textarea>
        </div>

        <div class="control-group">
          <label>{{i18n "admin.gamified_quiz.form.options"}}</label>
          <textarea
            value={{this.optionsString}}
            class="form-control"
            {{on "input" (fn this.updateField "optionsString")}}
          ></textarea>
        </div>

        <div class="control-group">
          <label>{{i18n "admin.gamified_quiz.form.correct_index"}}</label>
          <input
            type="number"
            value={{this.correctIndex}}
            class="form-control"
            {{on "input" (fn this.updateField "correctIndex")}}
          />
        </div>

        <div class="control-group">
          <label>{{i18n "admin.gamified_quiz.form.explanation"}}</label>
          <textarea
            value={{this.explanation}}
            class="form-control"
            {{on "input" (fn this.updateField "explanation")}}
          ></textarea>
        </div>

        <div class="control-group">
          <label>{{i18n "admin.gamified_quiz.form.source_topic_id"}}</label>
          <input
            type="number"
            value={{this.sourceTopicId}}
            class="form-control"
            {{on "input" (fn this.updateField "sourceTopicId")}}
          />
        </div>

        <div class="control-group">
          <label>
            <input
              type="checkbox"
              checked={{this.active}}
              {{on "change" this.updateActive}}
            />
            {{i18n "admin.gamified_quiz.form.active"}}
          </label>
        </div>

        <div class="form-actions">
          <dButton
            @label="admin.gamified_quiz.form.save"
            @action={{this.save}}
            class="btn-primary"
          />
          <dButton
            @label="admin.gamified_quiz.form.cancel"
            @action={{@onCancel}}
            class="btn-default"
          />
        </div>
      </div>
    </div>
  </template>
}
