# frozen_string_literal: true

module ::DiscourseQuiz
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseQuiz
  end
end
