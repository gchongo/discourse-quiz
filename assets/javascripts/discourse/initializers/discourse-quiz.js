import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import QuizButton from "../components/quiz-button";

export default {
  name: "discourse-quiz",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (!siteSettings.quiz_plugin_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.headerIcons.add("discourse-quiz", QuizButton, {
        before: "search",
      });

      api.addCommunitySectionLink((BaseSectionLink) => {
        return class QuizSectionLink extends BaseSectionLink {
          get name() {
            return "discourse-quiz";
          }

          get route() {
            return "quiz";
          }

          get title() {
            return i18n("gamified_quiz.button_title");
          }

          get text() {
            return i18n("gamified_quiz.sidebar_title");
          }

          get defaultPrefixValue() {
            return "circle-question";
          }
        };
      });
    });
  },
};
