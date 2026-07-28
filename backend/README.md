# menopause_Xia

本地 Tornado + MySQL 项目骨架。

## 快速开始

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python scripts/init_db.py
python main.py
```

启动后访问：

- `GET http://127.0.0.1:8888/login`
- `GET http://127.0.0.1:8888/chat`
- `GET http://127.0.0.1:8888/privacy`，隐私政策 URL
- `GET http://127.0.0.1:8888/terms`，用户协议 URL
- `GET http://127.0.0.1:8888/data-deletion`，数据删除/撤回同意说明
- `GET http://127.0.0.1:8888/ai-health-disclaimer`，AI/健康建议免责声明
- `GET http://127.0.0.1:8888/support`，用户支持与联系方式
- `GET http://127.0.0.1:8888/daily_quote`
- `GET http://127.0.0.1:8888/health`
- `GET http://127.0.0.1:8888/api/users`
- `POST http://127.0.0.1:8888/api/users`，JSON 示例：`{"name":"Alice","email":"alice@example.com"}`
- `POST http://127.0.0.1:8888/api/mobile/entity`，JSON 示例：`{"mobile":"13800138000"}`
- `GET http://127.0.0.1:8888/api/data/json?block_id=32位UUID`
- `GET http://127.0.0.1:8888/api/login_search?login=mobile:8613800138000`
- `POST http://127.0.0.1:8888/api/send_code`，JSON 示例：`{"mobile":"13800138000"}`
- `POST http://127.0.0.1:8888/api/login`，JSON 示例：`{"mobile":"13800138000","code":"123456"}`
- `GET http://127.0.0.1:8888/api/check_login`，根据登录 cookie 判断是否已登录
- `GET http://127.0.0.1:8888/api/app/daily_quote`，随机读取一条“我的”页顶部每日一言
- `GET http://127.0.0.1:8888/api/app/daily_quote?manage=1`，读取每日一言完整列表
- `POST http://127.0.0.1:8888/api/app/daily_quote`，新增/更新/删除每日一言，新增示例：`{"quote":"...","source":"《...》","speaker":"..."}`
- `GET/POST http://127.0.0.1:8888/api/chat/ensure`，根据登录 cookie 的用户 entity 创建或返回默认 `chat_id`
- `GET http://127.0.0.1:8888/api/chat/load?chat_id=32位UUID`，读取最近一组聊天记录；可加 `last_comment_id=32位UUID`
- `POST http://127.0.0.1:8888/api/chat/submit`，JSON 示例：`{"chat_id":"32位UUID","uuid":"32位UUID","content":"你好","ws_block_ids":[]}`
- `GET http://127.0.0.1:8888/api/chat/prompts/list?chat_id=32位UUID`，查看应用级全局 system prompt 版本列表；`chat_id` 仅用于登录用户身份校验
- `POST http://127.0.0.1:8888/api/chat/prompts/create`，创建全局版本，JSON 示例：`{"chat_id":"32位UUID","title":"v1","desc":"测试版本","system_prompt":"你是...","activate":true}`。激活后，所有现有和新建 chat 都会使用该版本
- `POST http://127.0.0.1:8888/api/chat/prompts/select`，JSON 示例：`{"chat_id":"32位UUID","prompt_id":"32位UUID"}`
- `GET/POST http://127.0.0.1:8888/api/trend_report/ensure`，根据登录用户创建或返回身体变化趋势 block，内部包含 `7d`、`30d`、`90d`
- `GET http://127.0.0.1:8888/api/trend_report/load`，读取当前用户的身体变化趋势 block；如尚不存在会自动创建。若未带登录 cookie，可传 `?user_id=32位UUID`
- `POST http://127.0.0.1:8888/api/trend_report/save`，保存某个周期的趋势报告，JSON 示例：`{"range":"7d","report":{...}}`
- `POST http://127.0.0.1:8888/api/meditation/practice/record`，记录一次呼吸练习。JSON 示例：`{"mode_key":"sleep","started_at":"2026-06-13T21:30:00+08:00","ended_at":"2026-06-13T21:35:00+08:00","duration_seconds":300,"cycle_count":15,"completed":true,"source":"ios"}`。`mode_key` 支持 `mood`（舒缓心情，吸4呼6）、`sleep`（助眠安睡，吸4停7呼8）、`hot_flash`（缓解潮热，吸5呼5）
- `GET http://127.0.0.1:8888/api/meditation/practice/summary?year=2026&month=6&tz_offset_minutes=480`，返回本月练习日期、次数、连续练习天数、总时长和各模式次数；`/api/chat/activity` 已合并这些数据，供“我的”页的 `practice_count` 和 `meditation_days` 使用
- `GET http://127.0.0.1:8888/api/meditation/practice/correlation?days=30&tz_offset_minutes=480`，按天聚合练习记录和聊天症状关键词，返回练习日期与症状记录之间的初步相关性统计。该结果只表示相关性，不表示因果
- `GET http://127.0.0.1:8888/api/medical_checklist/load?range=30d`，把趋势报告整理成就医沟通清单结构，支持 `7d`、`30d`、`90d`
- `POST http://127.0.0.1:8888/api/medical_checklist/save`，保存当前用户该周期的就医清单草稿，JSON 示例：`{"range":"30d","selected_questions":["..."],"custom_question":"...","preview_text":"..."}` 
- `GET http://127.0.0.1:8888/api/knowledge/list?q=关键词`，查看知识库条目
- `GET http://127.0.0.1:8888/api/knowledge/search?q=潮热`，测试知识库命中结果
- `POST http://127.0.0.1:8888/api/knowledge/create`，JSON 示例：`{"title":"潮热护理","category":"症状","tags":"潮热,夜汗","content":"...","is_active":true}`
- `POST http://127.0.0.1:8888/api/knowledge/active`，JSON 示例：`{"knowledge_id":"32位UUID","is_active":false}`
- `WS ws://127.0.0.1:8888/api/ws?block_id=32位UUID`，订阅后会收到 `/api/chat/submit` 的转发消息

## MySQL

默认使用本机 MySQL：

- host: `127.0.0.1`
- port: `3306`
- user: `root`
- database: `menopause_xia`

如你的 root 用户设置了密码，请编辑 `.env` 里的 `MYSQL_PASSWORD`。

## 阿里云短信验证码

在 `.env` 里配置阿里云凭据和短信参数：

```bash
ALIBABA_CLOUD_ACCESS_KEY_ID=你的AccessKeyId
ALIBABA_CLOUD_ACCESS_KEY_SECRET=你的AccessKeySecret
ALIYUN_SMS_SCHEME_NAME=你的方案名，不能超过20字符
ALIYUN_SMS_SIGN_NAME=你的短信签名
ALIYUN_SMS_TEMPLATE_CODE=你的模板Code
ALIYUN_SMS_TEMPLATE_PARAM={"code":"##code##","min":"5"}
```

本地联调但不真实调用阿里云时，可以临时设置：

```bash
ALIYUN_SMS_MOCK=true
```

mock 模式验证码固定为 `123456`。

## DeepSeek

在 `.env` 里配置 DeepSeek：

```bash
DEEPSEEK_API_KEY=你的DeepSeekKey
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-chat
DEEPSEEK_MAX_HISTORY=40
DEEPSEEK_MAX_TOKENS=1200
```

`/api/chat/submit` 默认会调用 DeepSeek：先存用户消息，再用当前应用级全局 system prompt 和最近消息构造上下文，最后把 assistant 回复也存回同一个 chat。每条消息会保存当时的 prompt 版本快照，后续切换全局版本不会改写历史。需要只存用户消息时，可以传 `{"ask_ai": false}`。每次提交聊天后，接口也会自动刷新当前用户的身体变化趋势 block，把 `7d`、`30d`、`90d` 三个周期的概况、高频症状、睡眠趋势、可能触发因素和推荐下一步写入 `trend_report_blocks` 对应的实体 body。

如果知识库里有启用的条目，`/api/chat/submit` 会用用户本次问题检索知识库，并把命中的参考内容作为后台 system message 注入给 DeepSeek。知识库内容不会直接显示在用户聊天气泡里，但会跟 assistant 消息一起保存为 `knowledge_refs`，方便之后排查回答依据。

## 反恶意使用保护

后端默认开启基础保护：

- 全局 API IP 限流，避免脚本刷接口。
- 短信验证码按 IP 和手机号双维度限流，避免短信轰炸。
- 验证码登录失败次数限制，降低撞库/爆破风险。
- 聊天按用户限流，并限制每日 AI 调用次数，控制模型调用成本。
- 聊天内容检测明显的 prompt injection、系统提示词泄露请求、批量垃圾内容和异常长输入。
- 生产环境聊天相关接口必须使用登录 cookie；`user_id` 直传只在 `DEBUG=true` 的本地联调中可用。
- 命中的拒绝事件会写入 `helen.abuse_events`，用于排查 `client_ip`、`user_entity_id`、`category`、`reason` 和 `metadata_json`。

可在 `.env` 中调整 `SECURITY_*` 配置。多实例部署时建议把当前内存限流器替换为 Redis 等共享存储。

## 数据库结构

- `schema.sql`：项目示例库 `menopause_xia` 和 `users` 表。
- `helen_schema.sql`：`helen`、`helen1`、`helen2` 三个库，以及 `index_login`、`sms_verify_logs`、`chat_index`、`chat_prompts`、`chat_blocks`、`trend_report_blocks`、`knowledge_items`、`app_blocks`、`entities` 表。
- `content/daily_quote.json`：“我的”页每日一言的管理 JSON，格式为 `{"quotes":[{"quote":"...","source":"...","speaker":"..."}]}`。

重新执行 Helen 相关库表初始化：

```bash
mysql -u root < helen_schema.sql
```
