import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Discourse Quiz - Panel visibility", function (needs) {
  needs.user();
  needs.settings({
    quiz_plugin_enabled: true,
  });

  needs.pretender((server) => {
    server.get("/quiz/next.json", () => {
      return [
        200,
        { "Content-Type": "application/json" },
        {
          id: 1,
          category_name: "示例",
          question_text: "1 + 1 = ?",
          options: ["1", "2", "3"],
        },
      ];
    });
  });

  test("clicking header icon shows a question", async function (assert) {
    await visit("/");
    await click(".quiz-header-icon .btn");
    assert.dom(".quiz-panel-container").hasClass("is-visible");
    assert.dom(".quiz-question-text").hasText("1 + 1 = ?");
  });
});
