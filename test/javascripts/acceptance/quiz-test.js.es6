import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { parsePostData } from "discourse/tests/helpers/create-pretender";
import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Discourse Quiz - Panel visibility", function (needs) {
  needs.user();
  needs.settings({
    quiz_plugin_enabled: true,
    quiz_rewards_enabled: true,
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

    server.get("/quiz/rewards.json", () => {
      return [
        200,
        { "Content-Type": "application/json" },
        {
          logged_in: true,
          cumulative_points: 20,
          rewards: [
            {
              id: 1,
              name: "奖励示例",
              category: "虚拟",
              description: "用于样式测试",
              points_threshold: 10,
              in_stock: true,
              remaining_stock: 5,
              claimable: true,
            },
          ],
        },
      ];
    });

    server.get("/quiz/rewards/claims.json", () => {
      return [
        200,
        { "Content-Type": "application/json" },
        {
          cumulative_points: 20,
          claims: [],
        },
      ];
    });
  });

  test("clicking header icon shows the home screen", async function (assert) {
    await visit("/");
    await click(".quiz-header-icon .btn");
    assert.dom(".quiz-panel-container").hasClass("is-visible");
    assert.ok(
      document.documentElement.classList.contains("has-quiz-panel"),
      "panel open adds layout class to html"
    );
    assert.dom(".quiz-home").exists();
    assert.dom(".quiz-category-row").exists({ count: 2 });
    assert.dom(".quiz-home-reset-btn").exists();
    assert.dom(".quiz-home-start-btn").exists();
  });

  test("starting a quiz shows a question", async function (assert) {
    await visit("/");
    await click(".quiz-header-icon .btn");
    await click(".quiz-home-start-btn");
    assert.dom(".quiz-panel-container").hasClass("is-quiz-active");
    assert.dom(".quiz-question-text").hasText("1 + 1 = ?");
  });

  test("clicking header icon while minimized expands the panel without resetting", async function (assert) {
    await visit("/");
    await click(".quiz-header-icon .btn");
    await click(".quiz-home-start-btn");
    await click(".quiz-panel-minimize-btn");

    assert.dom(".quiz-panel-container").hasClass("is-minimized");
    assert.dom(".quiz-question-text").exists();

    await click(".quiz-header-icon .btn");

    assert.dom(".quiz-panel-container").hasClass("is-visible");
    assert.dom(".quiz-panel-container").doesNotHaveClass("is-minimized");
    assert.dom(".quiz-question-text").hasText("1 + 1 = ?");
    assert.dom(".quiz-home").doesNotExist();
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

  test("clicking sidebar quiz link opens panel without route jump", async function (assert) {
    await visit("/latest");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-trigger"
    );

    assert.strictEqual(currentURL(), "/latest", "starts on latest route");

    await click(".sidebar-section-link[data-link-name='discourse-quiz']");

    assert.strictEqual(currentURL(), "/latest", "keeps current route");
    assert.dom(".quiz-panel-container").hasClass("is-visible");
  });

  test("clicking sidebar quiz link from categories keeps current route", async function (assert) {
    await visit("/categories");
    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-trigger"
    );

    assert.strictEqual(currentURL(), "/categories", "starts on categories route");

    await click(".sidebar-section-link[data-link-name='discourse-quiz']");

    assert.strictEqual(currentURL(), "/categories", "keeps categories route");
    assert.dom(".quiz-panel-container").hasClass("is-visible");
  });

  test("rewards info button uses shared ghost style classes", async function (assert) {
    await visit("/quiz/rewards");

    assert
      .dom(".quiz-rewards-page__info-btn")
      .hasClass("quiz-info-ghost-btn", "uses shared info ghost class");
    assert
      .dom(".quiz-rewards-page__info-btn")
      .hasClass("btn-icon-text", "uses icon-text ghost button shape");
    assert
      .dom(".quiz-rewards-page__info-btn")
      .hasAttribute("aria-label", "How does points redemption work?");
    assert
      .dom(".quiz-rewards-page__info-btn .d-button-label")
      .exists("shows label text on desktop");
  });
});
