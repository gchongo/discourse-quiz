import Component from "@glimmer/component";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import Form from "discourse/components/form";
import dButton from "discourse/components/d-button";

export default class AdminQuizEdit extends Component {
  get formData() {
    const question = this.args.question;
    return {
      category_name: question.category_name || "",
      question_text: question.question_text || "",
      options: (question.options || []).join("\n"),
      correct_index: question.correct_index ?? 0,
      explanation: question.explanation || "",
      source_topic_id: question.source_topic_id || "",
      active: !!question.active,
    };
  }

  @action
  handleSubmit(data) {
    this.args.onSave({
      id: this.args.question.id,
      category_name: data.category_name,
      question_text: data.question_text,
      options: data.options.split("\n").filter((option) => option.trim().length > 0),
      correct_index: parseInt(data.correct_index, 10),
      explanation: data.explanation,
      source_topic_id: data.source_topic_id || null,
      active: data.active,
    });
  }

  <template>
    <div class="admin-quiz-edit-modal">
      <Form @data={{this.formData}} @onSubmit={{this.handleSubmit}} as |form|>
        <form.Field
          @name="category_name"
          @title={{i18n "admin.gamified_quiz.form.category"}}
          @validation="required"
          @type="input"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @name="question_text"
          @title={{i18n "admin.gamified_quiz.form.question_text"}}
          @validation="required"
          @type="textarea"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @name="options"
          @title={{i18n "admin.gamified_quiz.form.options"}}
          @validation="required"
          @type="textarea"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @name="correct_index"
          @title={{i18n "admin.gamified_quiz.form.correct_index"}}
          @validation="required"
          @type="input-number"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @name="explanation"
          @title={{i18n "admin.gamified_quiz.form.explanation"}}
          @type="textarea"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @name="source_topic_id"
          @title={{i18n "admin.gamified_quiz.form.source_topic_id"}}
          @type="input-number"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @name="active"
          @title={{i18n "admin.gamified_quiz.form.active"}}
          @type="checkbox"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Actions>
          <form.Submit @label="admin.gamified_quiz.form.save" />
          <dButton
            @label="admin.gamified_quiz.form.cancel"
            @action={{@onCancel}}
            class="btn-default"
          />
        </form.Actions>
      </Form>
    </div>
  </template>
}
