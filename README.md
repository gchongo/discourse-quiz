# discourse-quiz

Discourse quiz plugin with a dedicated question bank.

## Current features (v0.19.0)

- Quiz home screen with question-type filter, practice mode, and optional category selection
- Home **today's points** progress bar (earned / daily max); rules info dialog no longer shows this line
- **Points redemption** is a standalone page (`/quiz/rewards`); link it from your site nav/menus (not shown in the quiz panel)
- Category selection and practice/question-type preferences persist in `localStorage`
- Category list cache: cached categories show immediately on home open while refreshing in the background
- Home layout: start button below practice mode; category list below start button (optional)
- Home category list sizes to content height; quiz panel height adapts on the home screen, then stays fixed during play/result with scrollable content (no height jump between question and result)
- Home skeleton loading: only shown when no cached categories are available
- Reset button resets category selection only (labeled「重置分类」)
- Desktop and mobile quiz panel entry with show/hide controls
- Header icon: when the panel is minimized, clicking the icon **expands** the panel (does not close or reset progress); when expanded, clicking closes the panel
- Panel title **info** button opens quiz rules (play modes, scoring, daily cap); optional custom copy via `quiz_rules_help`
- Mobile panel: minimize/expand uses `angles-down` / `angles-up`; minimize button centered in the header for thumb reach
- Mobile close fully hides the panel (`is-visible`); minimized state on Chat full-page avoids overlapping the Chat footer (`.c-footer`)
- Desktop docked panel sits in `#main-outlet-wrapper` grid (third column, like the sidebar); narrow viewports auto-switch to floating
- Desktop minimize/expand for browsing topics while keeping the panel available
- Panel mounted in a persistent outlet so quiz state survives topic navigation
- Desktop floating/minimized panel can be dragged by the title bar; position is remembered
- Question bank table: `discourse_quiz_questions`
- Panel loads one random active question from the bank
- Question types: single choice (default), true/false, and multiple choice (all correct options required)
- Question and result headers: **type** (left, tertiary) and **category** (center) on one row to avoid layout jump
- Question text, options, and explanation support cooked Markdown rendering (including LaTeX blocks like `$$...$$` when `discourse-math` is enabled)
- Answer UI uses radio buttons for single/true-false and checkboxes for multiple choice
- Result page reuses the same option control styling; feedback appears below options and above the explanation
- Correct-answer feedback shows points on the same line, right-aligned
- Submit answers with correct/incorrect feedback and explanation
- Guest demo with configurable attempt limit and login paywall
- Logged-in answer history in `discourse_quiz_user_attempts` (includes per-attempt `points_awarded` when tiered scoring is used)
- Gamification points for correct answers (when `discourse-gamification` is enabled)
- Flat or **tiered daily scoring** (optional): first N scored answers, then tier 2 up to M, then tier 3; daily cap still applies
- Daily point cap with learning-only mode after the cap
- Practice modes (logged-in): random, wrong-answer review, unseen questions
- Session de-duplication: while practicing, avoids repeating questions until the selected range is exhausted
- Recent-correct down-weighting: in random mode, questions answered correctly in the last 30 minutes are less likely to reappear
- User summary stats (own profile only at `/u/:username/summary`): lifetime correct count, never-correct question count, and accuracy rate
- **Points redemption** (optional): cumulative score thresholds, claim prizes without deducting points; admin CRUD + fulfillment queue; centered page layout; claim history with name, description, status, and `YYYY-MM-DD HH:mm:ss` timestamp
- **Quiz leaderboard** (optional): `/quiz/leaderboard` with volume and accuracy rankings plus per-user category stats table; distinct-question counts (not attempt counts); accuracy = distinct correct ÷ distinct attempted; period filters: **all / yearly / quarterly / monthly / weekly / daily**; cached stats table with hourly refresh and per-user refresh after submit
- Admin question bank: add/edit, search, pagination, category rename, export, dry-run import, and upsert import
- Bulk import **auto-skips duplicate question text** (within the batch and vs. existing bank); reports `skipped` count
- Admin duplicate-question detection with list summary, row highlighting, save/import warnings, and bulk disable (keep lowest ID per group)
- Admin mobile question list uses card layout; desktop keeps the table with ID, question type, and compact active indicators; bulk-disable-duplicates control is a small button after Search
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

## Points redemption (optional)

Independent module — does **not** change quiz submit, scoring, or daily caps. Disabled by default (`quiz_rewards_enabled`).

### How it works

- Users earn cumulative points (never deducted on claim).
- Each reward has a **points threshold**; when cumulative score ≥ threshold, the user can **claim** once.
- Claims are **pending** until an admin marks **fulfilled** or **cancelled**.
- Limited stock is optional; cancelling a claim restores stock.

### Enable

1. Set `quiz_rewards_enabled` to **true**.
2. Optionally set `quiz_rewards_intro` (shown at top of `/quiz/rewards`).
3. Choose score source:
   - `quiz_rewards_use_gamification_score` **true** (default): total `discourse-gamification` score.
   - **false**: sum of quiz `points_awarded` from scored correct answers only.
4. Admin → Plugins → **Community quiz** → **Points redemption**: add prizes (name, category, image URL, threshold, stock, sort order).

### User paths

- Public page: `/quiz/rewards` (add your own nav link, e.g. sidebar or header menu)
- Logged-in users see cumulative score, available rewards, and **My claims** (name + description on one line; status and time on the right)

### Admin fulfillment

- Admin → Plugins → **Community quiz** → **Points redemption** tab
- **Claims** table: **Mark fulfilled** / **Cancel** when status is **pending**; fulfilled/cancelled rows show **—** in Actions
- Mobile admin uses card layout; desktop uses tables; enabled status uses green/grey dots (same as question bank)

### Question picking (logged-in)

| Mode | Already-answered questions |
|------|---------------------------|
| **Random** (`normal`) | Can reappear after the current session exhausts the range; recently correct (30 min) are deprioritized; points only once per question |
| **Wrong only** | Only questions whose **latest** attempt was wrong |
| **Unseen** | Only questions never attempted before |

Session de-duplication: while a quiz round is running, already-shown questions are excluded until the selected range is exhausted, then the pool resets.

## Admin bulk import format

Admin path: `/admin/plugins/discourse-quiz` (questions tab)

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
,历史,下列哪些属于战国七雄？,multiple_choice,齐|晋|秦|楚,,0|2|3,战国七雄不含晋。,true
```

`question_type` is `single_choice` (default), `true_false`, or `multiple_choice`. `correct_index` is zero-based. For multiple choice, set `correct_indices` (JSON array or `0|2|3` in CSV). Leave `id` blank for new rows. Include `id` when using **upsert** import.

### Admin workflows (questions)

- **Add question**: click **Add question** in the list toolbar
- **Edit question**: pencil icon in the table (keeps the same question ID)
- **Export**: export JSON/CSV for the current filter/search
- **Dry run**: validate import without writing to the database
- **Upsert**: update existing rows when `id` is present (not skipped as duplicates)
- **Rename category**: rename a category across all questions in the bank
- **Search / pagination**: find questions by text, category, or question type in large banks
- **Duplicate detection**: normalized question-text duplicates are highlighted in the list; save/import responses include warnings
- **Bulk import skip**: duplicate rows in the file or matching existing question text are skipped automatically; import result shows `skipped` count
- **Bulk disable duplicates**: disable all but the lowest-ID question in each duplicate group

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

Clear browser localStorage keys `discourse-quiz-question-types`, `discourse-quiz-categories`, `discourse-quiz-categories-cache`, and hard-refresh if the quiz home screen still misbehaves.

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

Recent plugin migrations:

| Version | Purpose |
|---------|---------|
| `20260606120000` | `points_awarded` on `discourse_quiz_user_attempts` (tiered scoring) |
| `20260608130000` | `discourse_quiz_rewards` + `discourse_quiz_reward_claims` (points redemption) |

Then run `rake db:migrate` again after pulling the fixed plugin code.

## API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/quiz/categories.json` | Active categories for the home screen + status |
| GET | `/quiz/next.json` | Random active question; optional `category_names[]`, `question_types[]` (`single_choice`, `true_false`, `multiple_choice`), `practice_mode` (`normal`, `wrong_only`, `unseen`), `exclude_question_ids[]` (session de-duplication) |
| GET | `/quiz/status.json` | Current guest/login quiz status |
| GET | `/quiz/summary_stats.json` | Logged-in user's lifetime correct, never-correct question count, and accuracy rate |
| POST | `/quiz/submit.json` | Submit `question_id` + `answer_index` (single/true-false) or `answer_indices[]` (multiple choice); returns actual `points_awarded` |
| GET | `/quiz/rewards.json` | Active rewards + cumulative points (requires `quiz_rewards_enabled`) |
| GET | `/quiz/rewards/claims.json` | Logged-in user's claim history + cumulative points |
| POST | `/quiz/rewards/:id/claim.json` | Claim a reward (no point deduction) |
| GET | `/admin/quiz/questions.json` | Admin question list (`page`, `per_page`, `q`, `category_name`, `question_type`) + duplicate summary |
| GET | `/admin/quiz/questions/export.json` | Export JSON or CSV (`export_format`) |
| POST | `/admin/quiz/questions.json` | Create one question (may include `duplicate_warning`) |
| PUT | `/admin/quiz/questions/:id.json` | Update one question (may include `duplicate_warning`) |
| PUT | `/admin/quiz/categories/rename.json` | Rename a category across the bank |
| POST | `/admin/quiz/questions/bulk_import.json` | Bulk import JSON or CSV (`import_format`, `dry_run`, `upsert`); duplicates skipped; returns `skipped` |
| POST | `/admin/quiz/questions/bulk_disable_duplicates.json` | Disable duplicate questions, keeping the lowest ID in each group |
| GET | `/admin/quiz/rewards.json` | Admin rewards list + recent claims |
| POST | `/admin/quiz/rewards.json` | Create reward |
| PUT | `/admin/quiz/rewards/:id.json` | Update reward |
| DELETE | `/admin/quiz/rewards/:id.json` | Delete reward |
| PUT | `/admin/quiz/reward_claims/:id.json` | Update claim status (`pending`, `fulfilled`, `cancelled`) |

## Gamification and scoring

Install and enable the official `discourse-gamification` plugin.

### Flat scoring (default)

Set `quiz_tier1_upto_count` to **0**. Each first-time correct answer awards `quiz_points_per_question` until `quiz_daily_max_points` is reached.

### Tiered scoring (optional)

Set `quiz_tier1_upto_count` to **N** (greater than 0) to enable tiers by **daily scored-answer index** (same question only scores once):

| Setting | Meaning |
|---------|---------|
| `quiz_tier1_upto_count` | Tier 1: first **N** scored answers today |
| `quiz_tier1_points` | Points per question in tier 1 |
| `quiz_tier2_upto_count` | Tier 2 cumulative upper bound **M** (must be > N) |
| `quiz_tier2_points` | Points per question for scored answers N+1 … M |
| `quiz_tier3_points` | Points per question after M |
| `quiz_daily_max_points` | Hard daily cap; last award may be partial if only a few points remain |

Example (daily cap 50, encourage more practice): `N=10, tier1=2`, `M=20, tier2=1`, `tier3=1`.

Legacy attempts without `points_awarded` still count toward today's total using `quiz_points_per_question`.

### Other settings

- `quiz_rules_help` — custom rules text for the panel info dialog (blank = built-in rules)
- `quiz_submit_cooldown_seconds` — minimum seconds between submissions (0 = off)
- `quiz_enable_guest_demo` / `quiz_guest_attempt_limit` — guest try limit
- `quiz_rewards_enabled` — points redemption page and claims (default off)
- `quiz_rewards_use_gamification_score` — use total gamification score for reward thresholds (off = quiz points only)
- `quiz_rewards_intro` — optional intro on `/quiz/rewards`
- `quiz_leaderboard_enabled` — quiz leaderboard page (default on)
- `quiz_leaderboard_min_attempts` — minimum distinct questions for accuracy ranking (default 20)
- `quiz_leaderboard_user_limit` — users per page on leaderboard (default 50, max 100)

## Quiz leaderboard (optional)

Enabled by default (`quiz_leaderboard_enabled`). Link `/quiz/leaderboard` from your site nav (not shown in the quiz panel).

### Math / LaTeX support

- Quiz question text, answer options, and explanation are rendered through Discourse cooked Markdown.
- Use standard markdown and math syntax in content; for block formulas use `$$...$$`.
- Math rendering requires the official `discourse-math` plugin to be installed and enabled.

### Metrics

- **Questions attempted** — `COUNT(DISTINCT question_id)` per user (any attempt counts once per question).
- **Questions correct** — distinct questions with at least one correct attempt.
- **Accuracy** — `questions_correct / questions_attempted × 100%` (one decimal place).

### Period windows

- `all` — all-time
- `yearly` — last 365 days (rolling window)
- `quarterly` — last 90 days (rolling window)
- `monthly` — last 30 days (rolling window)
- `weekly` — last 7 days (rolling window)
- `daily` — today

### Tabs

1. **Rankings** — volume (total distinct questions) or accuracy (requires `quiz_leaderboard_min_attempts`); shows your rank when logged in.
2. **By category** — search a username and view a table of per-category stats (scheme C).

### API

- `GET /quiz/leaderboard.json?metric=volume|accuracy&period=all|yearly|quarterly|monthly|weekly|daily&page=1`
- `GET /quiz/leaderboard/user_categories.json?username=&period=all|yearly|quarterly|monthly|weekly|daily`

Stats are stored in `discourse_quiz_leaderboard_stats` and refreshed hourly (`Jobs::RefreshQuizLeaderboardStats`) and after each logged-in submit when enabled.

## Changelog

### v0.19.0

- Quiz leaderboard period filters: `all`, `yearly`, `quarterly`, `monthly`, `weekly`, `daily`
- Ranking and category stats APIs now accept `period` and return period metadata
- Leaderboard stats table expanded with period dimensions for cached period rankings

### v0.18.7

- Add cooked Markdown rendering for quiz question text, options, and explanation
- Support LaTeX math blocks (`$$...$$`) in quiz content when `discourse-math` is enabled

### v0.18.6

- Leaderboard/rewards title size and header spacing aligned with gamification leaderboard style
- Leaderboard toolbar refined: center metric switch (`答题总数` / `正确率`) and keep `分类统计` as a right-side auxiliary action

### v0.18.1

- Fix: idempotent leaderboard/rewards migrations (`if_not_exists` indexes; safe table creation)
- Fix: load leaderboard refresh jobs inside `after_initialize` (matches discourse-gamification)

### v0.18.0

- Quiz leaderboard: volume and accuracy rankings, per-user category stats table
- Distinct-question metrics (not raw attempt counts); accuracy uses distinct correct ÷ distinct attempted
- Cached stats with per-user refresh on submit and hourly full refresh
- Settings: `quiz_leaderboard_enabled`, `quiz_leaderboard_min_attempts`, `quiz_leaderboard_user_limit`

### v0.17.1

- Points redemption UI: centered `/quiz/rewards` layout; claim list no longer shifted by global `.body-page ul` margin
- Claim records: name + description on one line; fixed datetime format; admin claims datetime formatting
- Admin rewards: mobile cards, form UX, cancel button fix, claim actions column clarity
- Renamed user-facing copy from「里程碑奖品」to「积分兑换」
- Removed points redemption link from quiz panel home (use site nav instead)

### v0.17.0

- Milestone / points redemption module, tiered scoring, quiz panel UX improvements

## Next steps

- Configurable day boundary (e.g. Beijing midnight) for quiz daily cap vs. gamification
- Clarify or customize gamification daily leaderboard vs. quiz「today」points
- Admin notification on new claims (PM / email)
- Phase C: admin analytics and user attempt history
