# App Store Connect App Privacy 填表稿

更新日期：2026-07-10

Apple 参考文档：

- Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/

> 说明：以下按当前产品功能准备。正式提交前，请用生产环境的真实域名、运营主体、第三方服务商合同和 SDK 清单复核。若后续加入广告、归因、统计 SDK、崩溃分析或数据出售/共享用途，App Privacy 需要重新更新。

## 上架需要填写的 URL

请将 `https://your-domain.example` 替换为生产域名：

- 隐私政策 URL：`https://your-domain.example/privacy`
- 用户协议 URL：`https://your-domain.example/terms`
- 数据删除/撤回同意说明：`https://your-domain.example/data-deletion`
- AI/健康建议免责声明：`https://your-domain.example/ai-health-disclaimer`

可用别名：

- `/privacy-policy`
- `/user-agreement`
- `/consent-withdrawal`

## Data Used to Track You

建议选择：No

前提：

- 不把用户数据用于第三方广告、广告衡量或数据经纪。
- 不把本 App 收集的数据与第三方公司 App、网站或离线属性数据合并用于广告或广告衡量。
- 未接入会跨 App/网站追踪的广告、归因或分析 SDK。

如未来接入广告、归因或跨站追踪 SDK，需要重新评估。

## Data Linked to You

建议选择：Yes

原因：手机号、聊天内容、健康/症状记录、冥想记录会与账号或内部用户标识关联，用于登录、记录、AI 对话和趋势报告。

## Data Not Linked to You

当前无必须填报项。若后续仅以匿名、不可回溯方式统计整体使用量，可在这里补充相应类别。

## Data Types

### Contact Info

Data Type: Phone Number

- Collected: Yes
- Linked to user: Yes
- Used for tracking: No
- Purposes:
  - App Functionality
  - Account Management
- 说明：用于短信验证码登录、账号识别、登录状态维护和账号找回/客服核验。

### Health and Fitness

Data Type: Health

- Collected: Yes
- Linked to user: Yes
- Used for tracking: No
- Purposes:
  - App Functionality
  - Product Personalization
- 说明：包括更年期相关症状、睡眠、情绪、生活方式、可能触发因素、趋势报告、就医清单草稿等。用于记录、AI 对话、趋势分析和就医沟通准备。

Data Type: Fitness

- Collected: Yes
- Linked to user: Yes
- Used for tracking: No
- Purposes:
  - App Functionality
  - Product Personalization
- 说明：包括冥想/呼吸练习模式、开始结束时间、时长、完成状态、次数和连续天数。用于练习记录、统计和趋势展示。

### User Content

Data Type: Other User Content

- Collected: Yes
- Linked to user: Yes
- Used for tracking: No
- Purposes:
  - App Functionality
  - Product Personalization
- 说明：包括用户在 AI 对话中输入的自由文本、系统回复、聊天上下文和用户主动记录的补充说明。部分内容会发送给 AI 服务提供方生成回复和总结。

### Identifiers

Data Type: User ID

- Collected: Yes
- Linked to user: Yes
- Used for tracking: No
- Purposes:
  - App Functionality
  - Account Management
- 说明：包括内部用户实体 ID、会话 ID、聊天 ID 等，用于关联账号数据、读取记录和维护登录会话。

### Usage Data

Data Type: Product Interaction

- Collected: Optional / only if production logs retain it
- Linked to user: If retained with user/session ID, choose Yes
- Used for tracking: No
- Purposes:
  - App Functionality
  - Analytics
- 说明：当前核心功能会保存冥想练习记录，这已在 Health and Fitness/Fitness 中披露。若生产环境还保留页面访问、点击、接口调用等产品交互日志，并能关联用户，需要开启本项。

### Diagnostics

Data Type: Crash Data / Performance Data / Other Diagnostic Data

- Collected: No, unless a crash or analytics SDK is added
- 说明：如果接入 Sentry、Firebase Crashlytics、友盟、Bugly 或类似 SDK，需要按 SDK 实际采集项更新。

## Third-Party Data Processing

需要在隐私政策中说明以下委托处理/第三方服务：

- 短信服务商：发送和校验手机号验证码。
- 云服务/数据库/运维服务：存储账号、聊天、健康记录和冥想记录。
- AI 服务提供方：处理聊天内容、健康/症状记录、趋势报告所需上下文，生成 AI 回复和总结。

提交前必须确认：

- AI 服务商是否会保留输入/输出。
- AI 服务商是否会用数据训练模型。
- 数据处理地区和跨境传输安排。
- 是否支持删除请求同步处理。

## App 内建议露出

- 登录页：勾选或明确提示“登录即表示同意《用户协议》《隐私政策》，并理解部分聊天和健康记录会发送给 AI 服务处理。”
- AI 对话页：首次使用前展示 AI/健康免责声明。
- 我的 > 数据与隐私：展示隐私政策、用户协议、数据删除/撤回同意、AI/健康建议免责声明入口。
- 数据删除：提供 App 内入口或邮件入口，并说明处理时限。
