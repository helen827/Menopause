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
- `GET http://127.0.0.1:8888/health`
- `GET http://127.0.0.1:8888/api/users`
- `POST http://127.0.0.1:8888/api/users`，JSON 示例：`{"name":"Alice","email":"alice@example.com"}`
- `POST http://127.0.0.1:8888/api/mobile/entity`，JSON 示例：`{"mobile":"13800138000"}`
- `GET http://127.0.0.1:8888/api/data/json?block_id=32位UUID`
- `GET http://127.0.0.1:8888/api/login_search?login=mobile:8613800138000`
- `POST http://127.0.0.1:8888/api/send_code`，JSON 示例：`{"mobile":"13800138000"}`
- `POST http://127.0.0.1:8888/api/login`，JSON 示例：`{"mobile":"13800138000","code":"123456"}`
- `GET http://127.0.0.1:8888/api/check_login`，根据登录 cookie 判断是否已登录
- `GET/POST http://127.0.0.1:8888/api/chat/ensure`，根据登录 cookie 的用户 entity 创建或返回默认 `chat_id`
- `GET http://127.0.0.1:8888/api/chat/load?chat_id=32位UUID`，读取最近一组聊天记录；可加 `last_comment_id=32位UUID`
- `POST http://127.0.0.1:8888/api/chat/submit`，JSON 示例：`{"chat_id":"32位UUID","uuid":"32位UUID","content":"你好","ws_block_ids":[]}`
- `GET http://127.0.0.1:8888/api/chat/prompts/list?chat_id=32位UUID`，查看当前 chat 的 system prompt 版本列表
- `POST http://127.0.0.1:8888/api/chat/prompts/create`，JSON 示例：`{"chat_id":"32位UUID","title":"v1","desc":"测试版本","system_prompt":"你是...","activate":true}`
- `POST http://127.0.0.1:8888/api/chat/prompts/select`，JSON 示例：`{"chat_id":"32位UUID","prompt_id":"32位UUID"}`
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

`/api/chat/submit` 默认会调用 DeepSeek：先存用户消息，再用当前 chat 的 system prompt 和最近消息构造上下文，最后把 assistant 回复也存回同一个 chat。需要只存用户消息时，可以传 `{"ask_ai": false}`。

如果知识库里有启用的条目，`/api/chat/submit` 会用用户本次问题检索知识库，并把命中的参考内容作为后台 system message 注入给 DeepSeek。知识库内容不会直接显示在用户聊天气泡里，但会跟 assistant 消息一起保存为 `knowledge_refs`，方便之后排查回答依据。

## 数据库结构

- `schema.sql`：项目示例库 `menopause_xia` 和 `users` 表。
- `helen_schema.sql`：`helen`、`helen1`、`helen2` 三个库，以及 `index_login`、`sms_verify_logs`、`chat_index`、`chat_prompts`、`chat_blocks`、`knowledge_items`、`entities` 表。

重新执行 Helen 相关库表初始化：

```bash
mysql -u root < helen_schema.sql
```
