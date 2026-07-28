CREATE TABLE IF NOT EXISTS helen.chat_prompts_backup_20260727 LIKE helen.chat_prompts;
INSERT IGNORE INTO helen.chat_prompts_backup_20260727
SELECT * FROM helen.chat_prompts;

START TRANSACTION;

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

COMMIT;

SELECT prompt_id, title, is_active, showoff, createtime
FROM helen.chat_prompts
ORDER BY is_active DESC, id DESC;
