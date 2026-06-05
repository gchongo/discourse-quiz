import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import dButton from "discourse/components/d-button";

export default class AdminQuizRow extends Component {
  get auditStatusClass() {
    return this.args.question.validation_errors.length > 0 ? "status-error" : "status-ok";
  }

  <template>
    <tr class="admin-quiz-row">
      <td class="question-text">{{@question.question_text}}</td>
      <td>{{@question.category_name}}</td>
      <td>
        {{#if @question.active}}
          {{dIcon "check" class="active-icon"}}
        {{else}}
          {{dIcon "times" class="inactive-icon"}}
        {{/if}}
      </td>
      <td>
        <span class="audit-badge {{this.auditStatusClass}}">
          {{#if (gt @question.validation_errors.length 0)}}
            {{dIcon "exclamation-triangle"}}
            {{@question.validation_errors.length}}
          {{else}}
            {{i18n "js.admin.gamified_quiz.audit.ok"}}
          {{/if}}
        </span>
      </td>
      <td class="actions">
        <dButton @icon="pencil-alt" @action={{@onEdit}} class="btn-flat" />
        <dButton @icon="trash-alt" @action={{@onDelete}} class="btn-flat btn-danger" />
      </td>
    </tr>
  </template>
}
