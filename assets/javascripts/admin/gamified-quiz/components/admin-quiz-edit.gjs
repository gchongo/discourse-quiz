import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import dButton from "discourse/components/d-button";
import { Input } from "@ember/component";
import Textarea from "@ember/component/textarea";

export default class AdminQuizEdit extends Component {
  @tracked categoryName = this.args.question.category_name;
  @tracked questionText = this.args.question.question_text;
  @tracked optionsString = this.args.question.options.join("\n");
  @tracked correctIndex = this.args.question.correct_index;
  @tracked explanation = this.args.question.explanation;
  @tracked sourceTopicId = this.args.question.source_topic_id;
  @tracked active = this.args.question.active;

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
          <label>{{i18n "js.admin.gamified_quiz.form.category"}}</label>
          <Input @value={{this.categoryName}} class="form-control" />
        </div>

        <div class="control-group">
          <label>{{i18n "js.admin.gamified_quiz.form.question_text"}}</label>
          <Textarea @value={{this.questionText}} class="form-control" />
        </div>

        <div class="control-group">
          <label>{{i18n "js.admin.gamified_quiz.form.options"}}</label>
          <Textarea @value={{this.optionsString}} class="form-control" />
        </div>

        <div class="control-group">
          <label>{{i18n "js.admin.gamified_quiz.form.correct_index"}}</label>
          <Input @type="number" @value={{this.correctIndex}} class="form-control" />
        </div>

        <div class="control-group">
          <label>{{i18n "js.admin.gamified_quiz.form.explanation"}}</label>
          <Textarea @value={{this.explanation}} class="form-control" />
        </div>

        <div class="control-group">
          <label>{{i18n "js.admin.gamified_quiz.form.source_topic_id"}}</label>
          <Input @type="number" @value={{this.sourceTopicId}} class="form-control" />
        </div>

        <div class="control-group">
          <label>
            <Input @type="checkbox" @checked={{this.active}} />
            {{i18n "js.admin.gamified_quiz.form.active"}}
          </label>
        </div>

        <div class="form-actions">
          <dButton
            @label="js.admin.gamified_quiz.form.save"
            @action={{this.save}}
            class="btn-primary"
          />
          <dButton
            @label="js.admin.gamified_quiz.form.cancel"
            @action={{@onCancel}}
            class="btn-default"
          />
        </div>
      </div>
    </div>
  </template>
}
