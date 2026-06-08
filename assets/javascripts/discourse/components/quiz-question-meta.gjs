import Component from "@glimmer/component";

export default class QuizQuestionMeta extends Component {
  <template>
    <div class="quiz-question-meta">
      <span class="quiz-question-meta__type">{{@typeLabel}}</span>
      <span class="quiz-question-meta__category">{{@categoryName}}</span>
    </div>
  </template>
}
