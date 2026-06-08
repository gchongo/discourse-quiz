import bodyClass from "discourse/helpers/body-class";
import QuizRewardsPage from "../components/quiz-rewards-page";

export default <template>
  {{bodyClass "quiz-rewards"}}

  <section class="container">
    <div class="contents clearfix body-page">
      <QuizRewardsPage @model={{@controller.model}} />
    </div>
  </section>
</template>
