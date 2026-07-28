CREATE DATABASE IF NOT EXISTS helen
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS helen1
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS helen2
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS helen.index_login (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  login VARCHAR(255) NOT NULL,
  entity_id CHAR(32) NOT NULL,
  createtime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  search VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_index_login_login (login),
  KEY idx_index_login_entity_id (entity_id),
  KEY idx_index_login_search (search)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS helen.sms_verify_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  mobile VARCHAR(11) NOT NULL,
  out_id CHAR(32) DEFAULT NULL,
  action ENUM('send', 'check') NOT NULL,
  success TINYINT(1) NOT NULL DEFAULT 0,
  request_id VARCHAR(128) DEFAULT NULL,
  message TEXT DEFAULT NULL,
  verify_result VARCHAR(64) DEFAULT NULL,
  createtime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_sms_verify_mobile (mobile),
  KEY idx_sms_verify_out_id (out_id),
  KEY idx_sms_verify_createtime (createtime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE helen.sms_verify_logs
  MODIFY COLUMN message TEXT DEFAULT NULL;

CREATE TABLE IF NOT EXISTS helen.abuse_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  client_ip VARCHAR(64) DEFAULT NULL,
  path VARCHAR(255) DEFAULT NULL,
  user_entity_id VARCHAR(64) DEFAULT NULL,
  category VARCHAR(64) NOT NULL,
  reason VARCHAR(512) NOT NULL,
  metadata_json JSON DEFAULT NULL,
  createtime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_abuse_events_client_ip_time (client_ip, createtime),
  KEY idx_abuse_events_user_time (user_entity_id, createtime),
  KEY idx_abuse_events_category_time (category, createtime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS helen.chat_index (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  chat_id CHAR(32) NOT NULL,
  user_entity_id CHAR(32) NOT NULL,
  title VARCHAR(255) DEFAULT NULL,
  active_prompt_id CHAR(32) DEFAULT NULL,
  showoff TINYINT(1) NOT NULL DEFAULT 1,
  head_block_id CHAR(32) DEFAULT NULL,
  tail_block_id CHAR(32) DEFAULT NULL,
  total_comments BIGINT UNSIGNED NOT NULL DEFAULT 0,
  createtime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatetime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_chat_index_chat_id (chat_id),
  KEY idx_chat_index_user_entity_id (user_entity_id),
  KEY idx_chat_index_updatetime (updatetime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @has_active_prompt_id := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = 'helen'
    AND TABLE_NAME = 'chat_index'
    AND COLUMN_NAME = 'active_prompt_id'
);
SET @active_prompt_ddl := IF(
  @has_active_prompt_id = 0,
  'ALTER TABLE helen.chat_index ADD COLUMN active_prompt_id CHAR(32) DEFAULT NULL AFTER title',
  'SET @active_prompt_noop := 1'
);
PREPARE active_prompt_stmt FROM @active_prompt_ddl;
EXECUTE active_prompt_stmt;
DEALLOCATE PREPARE active_prompt_stmt;

SET @has_chat_showoff := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = 'helen'
    AND TABLE_NAME = 'chat_index'
    AND COLUMN_NAME = 'showoff'
);
SET @chat_showoff_ddl := IF(
  @has_chat_showoff = 0,
  'ALTER TABLE helen.chat_index ADD COLUMN showoff TINYINT(1) NOT NULL DEFAULT 1 AFTER active_prompt_id',
  'SET @chat_showoff_noop := 1'
);
PREPARE chat_showoff_stmt FROM @chat_showoff_ddl;
EXECUTE chat_showoff_stmt;
DEALLOCATE PREPARE chat_showoff_stmt;

CREATE TABLE IF NOT EXISTS helen.chat_prompts (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  prompt_id CHAR(32) NOT NULL,
  chat_id CHAR(32) NOT NULL,
  title VARCHAR(255) NOT NULL,
  `desc` VARCHAR(1024) DEFAULT NULL,
  system_prompt MEDIUMTEXT NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 0,
  showoff TINYINT(1) NOT NULL DEFAULT 1,
  createtime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatetime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_chat_prompts_prompt_id (prompt_id),
  KEY idx_chat_prompts_chat_id_id (chat_id, id),
  KEY idx_chat_prompts_chat_active (chat_id, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @has_prompt_showoff := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = 'helen'
    AND TABLE_NAME = 'chat_prompts'
    AND COLUMN_NAME = 'showoff'
);
SET @prompt_showoff_ddl := IF(
  @has_prompt_showoff = 0,
  'ALTER TABLE helen.chat_prompts ADD COLUMN showoff TINYINT(1) NOT NULL DEFAULT 1 AFTER is_active',
  'SET @prompt_showoff_noop := 1'
);
PREPARE prompt_showoff_stmt FROM @prompt_showoff_ddl;
EXECUTE prompt_showoff_stmt;
DEALLOCATE PREPARE prompt_showoff_stmt;

-- Prompt versions are application-wide. Preserve the newest active legacy
-- version, then move every existing prompt into the shared global scope.
SET @global_prompt_chat_id := REPEAT('0', 32);
INSERT INTO helen.chat_prompts
  (prompt_id, chat_id, title, `desc`, system_prompt, is_active, showoff)
SELECT
  REPLACE(UUID(), '-', ''),
  @global_prompt_chat_id,
  'default-v1',
  '全新安装时自动创建的应用级默认版本',
  '你是潮安应用里的 AI 对话助手。请用中文、温和、清晰地回应用户。',
  1,
  1
WHERE NOT EXISTS (SELECT 1 FROM helen.chat_prompts LIMIT 1);
SET @global_active_prompt_id := (
  SELECT prompt_id
  FROM helen.chat_prompts
  ORDER BY is_active DESC, id DESC
  LIMIT 1
);
UPDATE helen.chat_prompts
SET chat_id = @global_prompt_chat_id,
    is_active = IF(prompt_id = @global_active_prompt_id, 1, 0);

CREATE TABLE IF NOT EXISTS helen.chat_blocks (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  chat_id CHAR(32) NOT NULL,
  block_id CHAR(32) NOT NULL,
  prev_block_id CHAR(32) DEFAULT NULL,
  next_block_id CHAR(32) DEFAULT NULL,
  start_comment_id CHAR(32) DEFAULT NULL,
  end_comment_id CHAR(32) DEFAULT NULL,
  comment_count INT UNSIGNED NOT NULL DEFAULT 0,
  createtime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatetime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_chat_blocks_block_id (block_id),
  KEY idx_chat_blocks_chat_id_id (chat_id, id),
  KEY idx_chat_blocks_chat_id_end_comment (chat_id, end_comment_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS helen.trend_report_blocks (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_entity_id CHAR(32) NOT NULL,
  block_id CHAR(32) NOT NULL,
  createtime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatetime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_trend_report_user_entity_id (user_entity_id),
  UNIQUE KEY uq_trend_report_block_id (block_id),
  KEY idx_trend_report_updatetime (updatetime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS helen.meditation_practice_records (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  practice_id CHAR(32) NOT NULL,
  user_entity_id CHAR(32) NOT NULL,
  mode_key VARCHAR(32) NOT NULL,
  mode_label VARCHAR(64) NOT NULL,
  started_at_utc DATETIME NOT NULL,
  ended_at_utc DATETIME DEFAULT NULL,
  duration_seconds INT UNSIGNED NOT NULL DEFAULT 0,
  cycle_count INT UNSIGNED NOT NULL DEFAULT 0,
  completed TINYINT(1) NOT NULL DEFAULT 1,
  source VARCHAR(64) DEFAULT NULL,
  createtime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatetime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_meditation_practice_id (practice_id),
  KEY idx_meditation_user_started (user_entity_id, started_at_utc),
  KEY idx_meditation_user_mode_started (user_entity_id, mode_key, started_at_utc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS helen.meditation_blocks (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_entity_id CHAR(32) NOT NULL,
  block_id CHAR(32) NOT NULL,
  createtime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatetime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_meditation_blocks_user_entity_id (user_entity_id),
  UNIQUE KEY uq_meditation_blocks_block_id (block_id),
  KEY idx_meditation_blocks_updatetime (updatetime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS helen.knowledge_items (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  knowledge_id CHAR(32) NOT NULL,
  title VARCHAR(255) NOT NULL,
  category VARCHAR(128) DEFAULT NULL,
  tags VARCHAR(512) DEFAULT NULL,
  content MEDIUMTEXT NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  createtime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatetime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_knowledge_items_knowledge_id (knowledge_id),
  KEY idx_knowledge_items_active_time (is_active, updatetime),
  KEY idx_knowledge_items_category (category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS helen.app_blocks (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  block_key VARCHAR(128) NOT NULL,
  block_id CHAR(32) NOT NULL,
  title VARCHAR(255) DEFAULT NULL,
  createtime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updatetime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_app_blocks_block_key (block_key),
  UNIQUE KEY uq_app_blocks_block_id (block_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS helen1.entities (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  entity_id CHAR(32) NOT NULL,
  body LONGBLOB NOT NULL,
  updatetime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_entities_entity_id (entity_id),
  KEY idx_entities_updatetime (updatetime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS helen2.entities (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  entity_id CHAR(32) NOT NULL,
  body LONGBLOB NOT NULL,
  updatetime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_entities_entity_id (entity_id),
  KEY idx_entities_updatetime (updatetime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
