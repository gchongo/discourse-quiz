# discourse-quiz

Discourse quiz plugin with a dedicated question bank.

## Current features (v0.12.7)

- Quiz home screen with toggle list (multi-category selection, X-style) before starting
- Desktop and mobile quiz panel entry with show/hide controls
- Desktop docked panel pushes main content aside; narrow viewports auto-switch to floating
- Desktop minimize/expand for browsing topics while keeping the panel available
- Panel mounted in a persistent outlet so quiz state survives topic navigation
- Desktop floating/minimized panel can be dragged by the title bar; position is remembered
- Question bank table: `discourse_quiz_questions`
- Panel loads one random active question from the bank
- Submit answers with correct/incorrect feedback and explanation
- Guest demo with configurable attempt limit and login paywall
- Logged-in answer history in `discourse_quiz_user_attempts`
- Gamification points for correct answers (when `discourse-gamification` is enabled)
- Daily point cap with learning-only mode after the cap
- Admin page with add/edit, search, pagination, category rename, export, dry-run import, and upsert import
- Optional site setting `quiz_categories` to limit panel questions by category name
- Practice modes (logged-in): random, wrong-answer review, unseen questions
- Session de-duplication: while practicing, avoids repeating questions until the selected range is exhausted
- Recent-correct down-weighting: in random mode, questions answered correctly in the last 30 minutes are less likely to reappear
- Question types: single choice (default), true/false, and multiple choice (all correct options required)
- Quiz home screen question-type filter: choose single choice, true/false, and/or multiple choice before starting
- User summary stats (own profile only at `/u/:username/summary`): lifetime correct count and never-correct question count

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

Admin path: `/admin/plugins/discourse-quiz`

Upload a `.json` or `.csv` file, or paste content into the textarea.

### JSON

```json
[
  {
    "category_name": "历史",
    "question_text": "中国历史上第一个统一的封建王朝是哪个？",
    "question_type": "single_choice",
    "options": ["夏朝", "商朝", "秦朝", "汉朝"],
    "correct_index": 2,
    "explanation": "秦朝是中国历史上第一个统一的中央集权封建王朝。"
  },
  {
    "category_name": "历史",
    "question_text": "秦朝只存在了 15 年。",
    "question_type": "true_false",
    "correct_index": 0,
    "explanation": "对。"
  },
  {
    "category_name": "历史",
    "question_text": "下列哪些属于战国七雄？",
    "question_type": "multiple_choice",
    "options": ["齐", "晋", "秦", "楚"],
    "correct_indices": [0, 2, 3],
    "explanation": "战国七雄不含晋。"
  }
]
```

### CSV

Use `|` to separate multiple options in the `options` column:

```csv
id,category_name,question_text,question_type,options,correct_index,correct_indices,explanation,active
,历史,中国历史上第一个统一的封建王朝是哪个？,single_choice,夏朝|商朝|秦朝|汉朝,2,,秦朝是中国历史上第一个统一的中央集权封建王朝。,true
,历史,秦朝只存在了 15 年。,true_false,,0,,对。,true
,历史,下列哪些属于战国七雄？,multiple_choice,齐|晋|秦|楚,0,0|2|3,战国七雄不含晋。,true
```

`question_type` is `single_choice` (default), `true_false`, or `multiple_choice`. `correct_index` is zero-based. For multiple choice, set `correct_indices` (JSON array or `0|2|3` in CSV). Leave `id` blank for new rows. Include `id` when using **upsert** import.

### Admin workflows

- **Add question**: click **Add question** in the list toolbar
- **Edit question**: pencil icon in the table (keeps the same question ID)
- **Export**: export JSON/CSV for the current filter/search
- **Dry run**: validate import without writing to the database
- **Upsert**: update existing rows when `id` is present
- **Rename category**: rename a category across all questions in the bank
- **Search / pagination**: find questions by text or category in large banks

## Testing

```bash
bin/rspec plugins/discourse-quiz
bin/qunit plugins/discourse-quiz/test/javascripts
```

## Emergency: site broken after plugin update

If the forum homepage will not load after deploying `discourse-quiz`, disable the plugin first, then redeploy the fixed version:

```bash
./launcher enter app
cd /var/www/discourse
su discourse -c 'bundle exec rails runner "SiteSetting.quiz_plugin_enabled = false"'
exit
./launcher restart app
```

After pulling **v0.12.2** or later, re-enable `quiz_plugin_enabled` and rebuild.

Clear browser localStorage keys `discourse-quiz-question-types` and hard-refresh if the quiz home screen still misbehaves.

## Troubleshooting admin `/admin/quiz/questions.json` 503

If `/quiz/next.json` works but admin returns `题库尚未就绪`, the table exists but the admin query failed — often because the `position` column is missing on an older schema.

Inside the container:

```bash
su discourse -c 'bundle exec rails runner "
  c = ActiveRecord::Base.connection
  puts \"table: #{c.table_exists?(:discourse_quiz_questions)}\"
  puts \"position column: #{c.column_exists?(:discourse_quiz_questions, :position)}\"
  puts \"count: #{DiscourseQuiz::QuizQuestion.count}\"
"'
```

Fix: pull latest code (includes migration `20260605100000`) and `./launcher rebuild app`.

Or add the column manually:

```sql
ALTER TABLE discourse_quiz_questions ADD COLUMN IF NOT EXISTS position integer NOT NULL DEFAULT 0;
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

**Important:** Plugin migration timestamps must not be in the future. Discourse rejects migrations dated after the current UTC time during `db:migrate`. For example, `20260606100000` (10:00 UTC) fails if rebuild runs at 02:31 UTC on the same day — use an earlier timestamp such as `20260605110000`.

If a failed future-dated version was partially recorded:

```sql
DELETE FROM schema_migrations WHERE version IN ('20260606100000', '20260605110000');
```

Then pull the fixed plugin and rebuild.

Then run `rake db:migrate` again after pulling the fixed plugin code.

## API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/quiz/categories.json` | Active categories for the home screen + status |
| GET | `/quiz/next.json` | Random active question; optional `category_names[]`, `question_types[]` (`single_choice`, `true_false`, `multiple_choice`), `practice_mode` (`normal`, `wrong_only`, `unseen`), `exclude_question_ids[]` (session de-duplication) |
| GET | `/quiz/status.json` | Current guest/login quiz status |
| GET | `/quiz/summary_stats.json` | Logged-in user's lifetime correct and wrong-question counts |
| POST | `/quiz/submit.json` | Submit `question_id` + `answer_index` (single/true-false) or `answer_indices[]` (multiple choice) |
| GET | `/admin/quiz/questions.json` | Admin question list (`page`, `per_page`, `q`, `category_name`, `question_type`) |
| GET | `/admin/quiz/questions/export.json` | Export JSON or CSV (`export_format`) |
| POST | `/admin/quiz/questions.json` | Create one question |
| PUT | `/admin/quiz/questions/:id.json` | Update one question |
| PUT | `/admin/quiz/categories/rename.json` | Rename a category across the bank |
| POST | `/admin/quiz/questions/bulk_import.json` | Bulk import JSON or CSV (`import_format`, `dry_run`, `upsert`) |

## Gamification

Install and enable the official `discourse-gamification` plugin, then set:

- `quiz_points_per_question` — points per correct answer
- `quiz_daily_max_points` — daily earning cap

## Next steps

- Phase C: admin analytics and user attempt history
- Later: v0.6 source topic audit (`source_topic_id`, scheduled validation)
