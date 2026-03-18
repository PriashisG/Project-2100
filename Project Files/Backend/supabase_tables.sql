-- ─────────────────────────────────────────────
--  Run this in Supabase SQL Editor
-- ─────────────────────────────────────────────

-- User stats per platform
CREATE TABLE IF NOT EXISTS user_stats (
  id           SERIAL PRIMARY KEY,
  user_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  platform     TEXT NOT NULL,
  handle       TEXT NOT NULL,
  rating       INT  DEFAULT 0,
  max_rating   INT  DEFAULT 0,
  rank         TEXT DEFAULT '',
  solved_count INT  DEFAULT 0,
  updated_at   TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, platform)
);

-- Contest history
CREATE TABLE IF NOT EXISTS contest_history (
  id            SERIAL PRIMARY KEY,
  user_id       UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  platform      TEXT NOT NULL,
  contest_name  TEXT NOT NULL,
  rank          INT  DEFAULT 0,
  rating_change INT  DEFAULT 0,
  new_rating    INT  DEFAULT 0,
  date          TIMESTAMP,
  UNIQUE(user_id, platform, contest_name)
);

-- Enable RLS
ALTER TABLE user_stats     ENABLE ROW LEVEL SECURITY;
ALTER TABLE contest_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users read own stats"
  ON user_stats FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users read own contest history"
  ON contest_history FOR SELECT USING (auth.uid() = user_id);

-- Allow backend service key to write
CREATE POLICY "Service can write user_stats"
  ON user_stats FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Service can write contest_history"
  ON contest_history FOR ALL USING (true) WITH CHECK (true);
