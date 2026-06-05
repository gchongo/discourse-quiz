import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Discourse Quiz - Panel visibility", function (needs) {
  needs.user();
  needs.settings({
    quiz_plugin_enabled: true,
  });

  test("clicking header icon toggles the quiz panel", async function (assert) {
    await visit("/");
    assert.dom(".quiz-header-icon").exists();

    await click(".quiz-header-icon .btn");
    assert.dom(".quiz-panel-container").hasClass("is-visible");
    assert.dom(".quiz-panel-placeholder").exists();

    await click(".quiz-header-icon .btn");
    assert.dom(".quiz-panel-container").doesNotHaveClass("is-visible");
  });
});
