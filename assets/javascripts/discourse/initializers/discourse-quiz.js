import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import QuizButton from "../components/quiz-button";

const SIDEBAR_QUIZ_LINK_SELECTOR =
  ".sidebar-section-link[data-link-name='discourse-quiz']";
let sidebarQuizClickHandlerRegistered = false;

function registerSidebarQuizClickHandler(container) {
  if (sidebarQuizClickHandlerRegistered || typeof document === "undefined") {
    return;
  }

  const quiz = container.lookup("service:quiz");

  if (!quiz) {
    return;
  }

  document.addEventListener("click", (event) => {
    if (event.defaultPrevented) {
      return;
    }

    if (event.button !== undefined && event.button !== 0) {
      return;
    }

    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) {
      return;
    }

    const target = event.target;
    const link = target?.closest?.(SIDEBAR_QUIZ_LINK_SELECTOR);

    if (!link) {
      return;
    }

    event.preventDefault();
    quiz.openPanel();
  });

  sidebarQuizClickHandlerRegistered = true;
}

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
      registerSidebarQuizClickHandler(container);

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
