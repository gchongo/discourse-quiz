import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Gamified Quiz - Basic Flow", function (needs) {
  needs.user();
  needs.settings({
    quiz_plugin_enabled: true,
  });

  needs.pretender((server) => {
    server.get("/quiz/status.json", () => {
      return [200, { "Content-Type": "application/json" }, {
        is_guest: false,
        mode: "normal",
        points_today: 0
      }];
    });

    server.get("/quiz/next.json", () => {
      return [200, { "Content-Type": "application/json" }, {
        id: 1,
        question_text: "Test Question",
        options: ["Option 1", "Option 2"],
        category_name: "Test"
      }];
    });
  });

  test("clicking quiz button opens the panel", async function (assert) {
    await visit("/");
    assert.dom(".quiz-header-icon").exists("header icon exists");

    await click(".quiz-header-icon .btn");
    assert.dom(".quiz-panel-container").hasClass("is-visible", "panel becomes visible");
    assert.dom(".quiz-question-text").hasText("Test Question", "shows loaded question");
  });
});
