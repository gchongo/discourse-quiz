# discourse-quiz

Discourse quiz plugin with a dedicated question bank.

## Current features (v0.2.0)

- Desktop and mobile quiz panel entry with show/hide controls
- Question bank table: `discourse_quiz_questions`
- Panel loads one random active question from the bank
- Admin page with category filter and bulk JSON import
- Optional site setting `quiz_categories` to limit panel questions by category name

## Installation

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - rm -rf discourse-quiz
          - git clone https://github.com/howhy-day/discourse-quiz.git
```

```bash
./launcher rebuild app
```

Enable `quiz_plugin_enabled` in admin settings.

## Admin bulk import format

```json
[
  {
    "category_name": "历史",
    "question_text": "中国历史上第一个统一的封建王朝是哪个？",
    "options": ["夏朝", "商朝", "秦朝", "汉朝"],
    "correct_index": 2,
    "explanation": "秦朝是中国历史上第一个统一的中央集权封建王朝。"
  }
]
```

Admin path: `/admin/plugins/discourse-quiz`

## Testing

```bash
bin/rspec plugins/discourse-quiz
bin/qunit plugins/discourse-quiz/test/javascripts
```

## Troubleshooting admin `/admin/quiz/questions.json` 500

Same as the public endpoint: rebuild after pulling latest code. The admin list API no longer uses `AdminQuizQuestionSerializer` (direct JSON, like `/quiz/next.json`).

Quick test inside the container:

```bash
su discourse -c 'bundle exec rails runner "puts DiscourseQuiz::QuizQuestion.order(:id).map(&:question_text).inspect"'
```

## Troubleshooting `/quiz/next.json` 500

Inside the container:

```bash
./launcher enter app
cd /var/www/discourse
su discourse -c 'bundle exec rails runner "
  puts \"table: #{ActiveRecord::Base.connection.table_exists?(:discourse_quiz_questions)}\"
  puts \"count: #{DiscourseQuiz::QuizQuestion.count}\"
"'
```

If `table: false`, run `bundle exec rake db:migrate` and rebuild.

If `count: 0`, seed the sample question:

```bash
su discourse -c 'bundle exec rails runner "DiscourseQuiz::SeedQuestions.seed!"'
```

Check `quiz_categories` site setting: use **category names** (e.g. `示例,历史`), not category IDs.

## Troubleshooting migrate failures

If rebuild fails on `db:migrate` for this plugin:

```bash
./launcher enter app
cd /var/www/discourse
su discourse -c 'bundle exec rake db:migrate'
```

If a failed migration version is stuck (e.g. `20260611000000` from an earlier attempt):

```sql
DELETE FROM schema_migrations WHERE version IN ('20260611000000', '20260605000000');
```

**Important:** Plugin migration timestamps must not be in the future. Discourse rejects migrations dated after the current UTC time during `db:migrate`.

Then run `rake db:migrate` again after pulling the fixed plugin code.

## Next steps

- Submit answers and scoring
- Guest limits and gamification integration
