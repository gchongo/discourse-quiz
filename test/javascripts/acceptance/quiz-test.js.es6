import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { parsePostData } from "discourse/tests/helpers/create-pretender";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Discourse Quiz - Panel visibility", function (needs) {
  needs.user();
  needs.settings({
    quiz_plugin_enabled: true,
  });

  needs.pretender((server) => {
    server.get("/quiz/categories.json", () => {
      return [
        200,
        { "Content-Type": "application/json" },
        {
          categories: ["示例"],
          status: { is_guest: false, mode: "normal" },
        },
      ];
    });

    server.get("/quiz/next.json", () => {
      return [
        200,
        { "Content-Type": "application/json" },
        {
          id: 1,
          category_name: "示例",
          question_text: "1 + 1 = ?",
          options: ["1", "2", "3"],
          status: { is_guest: false, mode: "normal" },
        },
      ];
    });

    server.post("/quiz/submit.json", (request) => {
      const data = parsePostData(request.requestBody);
      const correct = Number(data.answer_index) === 0;

      return [
        200,
        { "Content-Type": "application/json" },
        {
          correct,
          explanation: "1 + 1 = 2",
          correct_index: 1,
          correct_option: "2",
          points_awarded: correct ? 10 : 0,
          status: { is_guest: false, mode: "normal" },
        },
      ];
    });
  });

  test("clicking header icon shows the home screen", async function (assert) {
    await visit("/");
    await click(".quiz-header-icon .btn");
    assert.dom(".quiz-panel-container").hasClass("is-visible");
    assert.dom(".quiz-home").exists();
    assert.dom(".quiz-category-row").exists({ count: 2 });
    assert.dom(".quiz-home-reset-btn").exists();
    assert.dom(".quiz-home-start-btn").exists();
  });

  test("starting a quiz shows a question", async function (assert) {
    await visit("/");
    await click(".quiz-header-icon .btn");
    await click(".quiz-home-start-btn");
    assert.dom(".quiz-question-text").hasText("1 + 1 = ?");
  });

  test("submitting an answer shows the result", async function (assert) {
    await visit("/");
    await click(".quiz-header-icon .btn");
    await click(".quiz-home-start-btn");
    await click(".quiz-option-btn");
    await click(".quiz-submit-btn");
    assert.dom(".quiz-result-banner.is-correct").exists();
    assert.dom(".quiz-explanation-text").hasText("1 + 1 = 2");
  });
});
