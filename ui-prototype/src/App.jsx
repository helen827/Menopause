import { useEffect, useId, useMemo, useState } from "react";
import {
  AppleLogo,
  BellSimple,
  BookmarkSimple,
  CalendarBlank,
  CaretLeft,
  CaretRight,
  ChartLineUp,
  ChatCircleDots,
  CheckCircle,
  ClipboardText,
  ClockCounterClockwise,
  Coffee,
  DeviceMobile,
  EnvelopeSimple,
  Eye,
  Fire,
  GearSix,
  Heart,
  Lightbulb,
  FlowerLotus,
  LockKey,
  Microphone,
  MoonStars,
  PaperPlaneTilt,
  Pause,
  Play,
  Person,
  ShieldCheck,
  SmileySad,
  Sparkle,
  SpeakerHigh,
  Stethoscope,
  TrendUp,
  Wind,
} from "@phosphor-icons/react";
import {
  CartesianGrid,
  Legend,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

const trendData = {
  "7天": [
    { date: "6月16日", hot: 3, sleep: 2 },
    { date: "6月18日", hot: 4, sleep: 3 },
    { date: "6月20日", hot: 2, sleep: 2 },
    { date: "6月22日", hot: 2, sleep: 1 },
  ],
  "30天": [
    { date: "6月1日", hot: 11, sleep: 8 },
    { date: "6月8日", hot: 15, sleep: 6 },
    { date: "6月15日", hot: 11, sleep: 5 },
    { date: "6月22日", hot: 10, sleep: 6 },
    { date: "6月29日", hot: 6, sleep: 3 },
  ],
  "90天": [
    { date: "4月", hot: 38, sleep: 28 },
    { date: "5月", hot: 31, sleep: 22 },
    { date: "6月", hot: 24, sleep: 18 },
  ],
};

const prototypeToday = new Date(2026, 5, 22);
const dateKey = (date) => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
const aiCheckinDates = new Set([
  "2026-03-28", "2026-04-02", "2026-04-08", "2026-04-15", "2026-04-21", "2026-04-28",
  "2026-05-03", "2026-05-08", "2026-05-12", "2026-05-18", "2026-05-24", "2026-05-28",
  "2026-06-02", "2026-06-07", "2026-06-09", "2026-06-12", "2026-06-14", "2026-06-18",
  "2026-06-20", "2026-06-21", "2026-06-22",
]);

function GlassBlock({ className = "", source = "right", children }) {
  return (
    <div className={`glass-stage ${className}`}>
      <div className={`color-source source-${source}`} aria-hidden="true" />
      <section className="glass-panel">{children}</section>
    </div>
  );
}

function SectionTitle({ icon: Icon, children, trailing }) {
  return (
    <header className="section-title">
      <span className="icon-glass"><Icon size={20} weight="bold" /></span>
      <h2>{children}</h2>
      {trailing}
    </header>
  );
}

function MedicalNotice() {
  return (
    <section className="medical-notice" aria-label="医疗提示">
      <span className="icon-glass"><Stethoscope size={18} weight="bold" /></span>
      <p>
        <b>医疗提示</b>
        本 App 内容用于自我观察和就医沟通准备，不是医学诊断，不是治疗建议，不能替代医生判断。紧急、严重或持续加重症状请及时就医。
      </p>
    </section>
  );
}

function BrandMark({ size = 20 }) {
  const gradientId = useId();

  return (
    <svg className="brand-mark" width={size} height={size} viewBox="0 0 128 128" aria-hidden="true" focusable="false">
      <defs>
        <linearGradient id={gradientId} x1="28" y1="18" x2="99" y2="110" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#D77F8E" />
          <stop offset=".52" stopColor="#B591C0" />
          <stop offset="1" stopColor="#7F98BA" />
        </linearGradient>
      </defs>
      <g fill={`url(#${gradientId})`}>
        <path d="M64 20c16.2 14.6 17.9 32.6 0 48.9C46.1 52.6 47.8 34.6 64 20Z" />
        <path d="M28 61.4c22.2-6.8 39.9 0 47.2 21.5-21.9 7.2-39.7.3-47.2-21.5Z" />
        <path d="M100 61.4c-22.2-6.8-39.9 0-47.2 21.5 21.9 7.2 39.7.3 47.2-21.5Z" />
        <path d="M45.7 93.4c11.2-5.9 25.4-5.9 36.6 0-8.9 13.1-27.7 13.1-36.6 0Z" opacity=".86" />
      </g>
    </svg>
  );
}

const navItems = [
  ["AI 对话", ChatCircleDots],
  ["冥想练习", FlowerLotus],
  ["趋势", ChartLineUp],
  ["我的", Person],
];

function BottomNav({ tab, setTab }) {
  return (
    <nav className="tab-stage" aria-label="主导航">
      <div className="tab-bar">
        {navItems.map(([label, Icon]) => (
          <button key={label} className={tab === label ? "active" : ""} onClick={() => setTab(label)}>
            <Icon size={25} weight={tab === label ? "fill" : "regular"} />
            <span>{label}</span>
          </button>
        ))}
      </div>
    </nav>
  );
}

function LandingScreen({ onStart }) {
  return (
    <main className="app-shell page-landing">
      <div className="ambient ambient-b" />
      <div className="screen landing-screen">
        <div className="brand-pill"><BrandMark size={20} />潮安</div>
        <section className="landing-copy">
          <p>陪你读懂每一次变化</p>
          <h1>更懂身体，<br />也更安心</h1>
          <span>在更年期，找回自己的节奏</span>
        </section>

        <div className="hero-orb-label">
          <span>今天也要</span>
          <strong>温柔照顾自己</strong>
        </div>

        <section className="benefit-glass">
          <div><ChatCircleDots size={22} /><b>AI 陪伴记录</b></div>
          <div><ChartLineUp size={22} /><b>身体趋势洞察</b></div>
          <div><Wind size={22} /><b>呼吸放松练习</b></div>
        </section>

        <button className="landing-cta" onClick={onStart}>开始使用</button>
        <p className="privacy-note"><ShieldCheck size={16} />你的记录仅用于个人健康管理</p>
      </div>
    </main>
  );
}

function LoginScreen({ onSuccess }) {
  const [email, setEmail] = useState("jiaying@example.com");
  const [password, setPassword] = useState("••••••••");

  return (
    <main className="app-shell page-login">
      <div className="ambient ambient-b" />
      <div className="screen login-screen">
        <div className="login-brand">
          <span><BrandMark size={24} /></span>
          <b>潮安</b>
        </div>

        <section className="login-hero">
          <p>欢迎回来</p>
          <h1>继续照顾<br />今天的自己</h1>
          <span>安全登录后，你的记录、趋势和练习都会继续保留。</span>
        </section>

        <section className="login-card" aria-label="登录表单">
          <button className="login-option" onClick={onSuccess}>
            <AppleLogo size={22} weight="fill" />
            <span>通过 Apple 继续</span>
          </button>
          <button className="login-option" onClick={onSuccess}>
            <DeviceMobile size={22} weight="bold" />
            <span>通过手机号继续</span>
          </button>

          <div className="login-divider"><span>或使用邮箱</span></div>

          <label className="login-field">
            <EnvelopeSimple size={20} />
            <input value={email} onChange={(event) => setEmail(event.target.value)} aria-label="邮箱" />
          </label>
          <label className="login-field">
            <LockKey size={20} />
            <input value={password} onChange={(event) => setPassword(event.target.value)} aria-label="密码" />
            <Eye size={19} />
          </label>

          <div className="login-row">
            <span>记住我</span>
            <button type="button">忘记密码？</button>
          </div>

          <button className="login-submit" onClick={onSuccess}>登录</button>
        </section>

        <p className="login-note">
          <ShieldCheck size={16} />
          登录即表示同意服务条款与隐私政策，健康记录仅用于个人管理。
        </p>
      </div>
    </main>
  );
}

function AIChatScreen() {
  const [draft, setDraft] = useState("");
  const [messages, setMessages] = useState([
    ["ai", "晚上好。今天身体感觉怎么样？睡眠、潮热或心情，都可以慢慢告诉我。"],
    ["user", "昨晚睡得不太好，半夜醒了两次，今天还有一点潮热。"],
    ["ai", "辛苦了，我已经帮你记下睡眠中断和潮热。上午大概出现了几次呢？"],
  ]);

  const send = () => {
    const value = draft.trim();
    if (!value) return;
    setMessages((items) => [...items, ["user", value], ["ai", "记下了。这些内容会逐渐形成你的身体趋势，帮助你发现变化。"]]);
    setDraft("");
  };

  return (
    <div className="page-content chat-page">
      <header className="page-header">
        <div><h1>AI 对话</h1><p>说说今天的身体和心情</p></div>
        <button className="round-glass" aria-label="对话历史"><ClockCounterClockwise size={24} /></button>
      </header>
      <MedicalNotice />
      <div className="companion-pill"><BrandMark size={18} />潮安陪伴中</div>
      <div className="date-divider"><span>今天</span></div>
      <div className="messages">
        {messages.map(([role, text], index) => <div className={`message ${role}`} key={`${role}-${index}`}>{text}</div>)}
      </div>
      <div className="quick-chips">
        {["记录潮热", "记录睡眠", "记录心情"].map((item) => <button key={item} onClick={() => setDraft(item)}>{item}</button>)}
      </div>
      <div className="composer">
        <input value={draft} onChange={(event) => setDraft(event.target.value)} onKeyDown={(event) => event.key === "Enter" && send()} placeholder="记录今天的状态…" />
        <button aria-label="语音输入"><Microphone size={20} /></button>
        <button className="send" aria-label="发送" onClick={send}><PaperPlaneTilt size={21} weight="fill" /></button>
      </div>
    </div>
  );
}

function MeditationScreen({ onComplete }) {
  const modes = [
    { key: "meadow", name: "舒缓心情", scene: "柔风麦田", rhythm: "吸 4 秒 · 呼 6 秒", inhale: 4, guidance: "把空气带到胸口", image: "/meditation/meadow.png", theme: "light" },
    { key: "sleep", name: "助眠安睡", scene: "深睡轨道", rhythm: "吸 4 秒 · 停 7 秒 · 呼 8 秒", inhale: 4, guidance: "让身体慢慢沉下来", image: "/meditation/space.png", theme: "dark" },
    { key: "cool", name: "缓解潮热", scene: "清凉潮汐", rhythm: "吸 5 秒 · 呼 5 秒", inhale: 5, guidance: "慢慢吸入清凉空气", image: "/meditation/beach.png", theme: "light" },
  ];
  const [mode, setMode] = useState(2);
  const [status, setStatus] = useState("running");
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [showSummary, setShowSummary] = useState(false);
  const current = modes[mode];
  const running = status === "running";
  const previous = () => setMode((mode + modes.length - 1) % modes.length);
  const next = () => setMode((mode + 1) % modes.length);
  const duration = `${Math.floor(elapsedSeconds / 60)} 分 ${String(elapsedSeconds % 60).padStart(2, "0")} 秒`;

  useEffect(() => {
    if (!running) return undefined;
    const timer = window.setInterval(() => setElapsedSeconds((seconds) => seconds + 1), 1000);
    return () => window.clearInterval(timer);
  }, [running]);

  const handlePrimaryAction = () => {
    if (status === "running") {
      setStatus("paused");
      return;
    }
    setElapsedSeconds(0);
    setStatus("running");
  };

  const continuePractice = () => {
    setShowSummary(false);
    setStatus("running");
  };

  const finishPractice = () => {
    onComplete({ seconds: elapsedSeconds, scene: current.scene });
    setShowSummary(false);
    setStatus("completed");
  };

  return (
    <div className={`page-content meditation-page theme-${current.theme} mode-${current.key}`}>
      <div className="scene-background" style={{ backgroundImage: `url(${current.image})` }} aria-hidden="true" />
      <div className="scene-overlay" aria-hidden="true" />
      <header className="page-header meditation-header">
        <div><h1>冥想练习</h1><p>{current.name} · {current.rhythm}</p></div>
        <button className="round-glass" aria-label="声音"><SpeakerHigh size={23} /></button>
      </header>
      <div className={`breathing-orb ${running ? "breathing" : ""}`}>
        <div className="orb-inner"><span>吸气</span><strong>{current.inhale}</strong><small>{current.guidance}</small></div>
      </div>
      <div className="scene-name">
        <span>{current.scene}</span>
        <b>{status === "completed" ? `今日已完成 · ${duration}` : current.rhythm}</b>
        <small className="practice-timer">本次练习 {duration}</small>
      </div>
      <div className="mode-tabs">
        {modes.map((item, index) => <button className={mode === index ? "active" : ""} key={item.name} onClick={() => setMode(index)}>{item.name}</button>)}
      </div>
      <div className={`meditation-controls ${status === "paused" ? "is-paused" : ""}`}>
        <button aria-label="上一个练习" onClick={previous}><CaretLeft size={22} /></button>
        {status === "paused" ? (
          <>
            <button className="resume" onClick={continuePractice}><Play size={19} weight="fill" />继续</button>
            <button className="end-practice" onClick={() => setShowSummary(true)}><CheckCircle size={20} weight="fill" />结束</button>
          </>
        ) : (
          <button className="pause" onClick={handlePrimaryAction}>
            {status === "running" && <Pause size={19} weight="fill" />}
            {status === "completed" && <Sparkle size={19} weight="fill" />}
            {status === "running" ? "暂停" : "再次练习"}
          </button>
        )}
        <button aria-label="下一个练习" onClick={next}><CaretRight size={22} /></button>
      </div>
      {showSummary && (
        <div className="practice-summary-backdrop" role="presentation">
          <section className="practice-summary" role="dialog" aria-modal="true" aria-labelledby="practice-summary-title">
            <span className="summary-check"><CheckCircle size={32} weight="fill" /></span>
            <p>今天你完成了</p>
            <h2 id="practice-summary-title">{duration}</h2>
            <span>每一次停下来照顾自己，都值得被记录。</span>
            <div className="summary-actions">
              <button onClick={continuePractice}>继续练习</button>
              <button className="confirm" onClick={finishPractice}>完成并记录</button>
            </div>
          </section>
        </div>
      )}
    </div>
  );
}

function MineScreen({ meditationRecords, onToast }) {
  const [activityRange, setActivityRange] = useState("30天");
  const rangeLength = { "7天": 7, "30天": 30, "90天": 90 }[activityRange];
  const visibleDays = useMemo(() => Array.from({ length: rangeLength }, (_, index) => {
    const date = new Date(prototypeToday);
    date.setDate(prototypeToday.getDate() - (rangeLength - 1 - index));
    return { date, key: dateKey(date), day: date.getDate() };
  }), [rangeLength]);
  const visibleKeys = new Set(visibleDays.map((item) => item.key));
  const visibleMeditations = meditationRecords.filter((record) => visibleKeys.has(record.date));
  const recordByDate = new Map(meditationRecords.map((record) => [record.date, record]));
  const aiDays = visibleDays.filter((item) => aiCheckinDates.has(item.key)).length;
  const totalSeconds = visibleMeditations.reduce((sum, record) => sum + record.seconds, 0);
  const totalSessions = visibleMeditations.reduce((sum, record) => sum + record.sessions, 0);
  const weekdays = ["日", "一", "二", "三", "四", "五", "六"];
  const rangeLabel = `${visibleDays[0].date.getMonth() + 1}月${visibleDays[0].day}日 - ${prototypeToday.getMonth() + 1}月${prototypeToday.getDate()}日`;
  return (
    <div className="page-content mine-page">
      <header className="page-header">
        <div><h1>我的</h1><p>晚上好，今天也辛苦了</p></div>
        <button className="round-glass" aria-label="设置"><GearSix size={24} /></button>
      </header>
      <GlassBlock className="quote-card">
        <SectionTitle icon={Heart}>每日一言</SectionTitle>
        <blockquote>“更年期不是失去青春，而是重新认识自己的开始。”</blockquote>
      </GlassBlock>
      <div className="range-stage profile-range-stage">
        <div className="range-control">
          {["7天", "30天", "90天"].map((item) => <button key={item} className={activityRange === item ? "active" : ""} onClick={() => setActivityRange(item)}>{item}</button>)}
        </div>
      </div>
      <GlassBlock className="activity-checkin-card" source="left-low">
        <SectionTitle icon={FlowerLotus} trailing={<span className="activity-period">{rangeLabel}</span>}>身心打卡</SectionTitle>
        <div className="activity-legend">
          <span><i className="legend-ai" />与 AI 聊过</span>
          <span><i className="legend-meditation" />冥想练习</span>
          <small>填色越深，练习越久</small>
        </div>
        <div className="activity-stats">
          <div><strong>{aiDays}</strong><span>AI 对话天数</span></div>
          <div><strong>{totalSessions}</strong><span>冥想次数</span></div>
          <div><strong>{Math.round(totalSeconds / 60)}</strong><span>冥想分钟</span></div>
        </div>
        <div className="activity-weekdays">
          {visibleDays.slice(0, 7).map((item) => <span key={item.key}>{weekdays[item.date.getDay()]}</span>)}
        </div>
        <div className={`activity-board range-${rangeLength}`} aria-label={`${activityRange}身心打卡记录`}>
          {visibleDays.map((item) => {
            const record = recordByDate.get(item.key);
            const hasAi = aiCheckinDates.has(item.key);
            const level = !record ? 0 : record.seconds >= 900 ? 3 : record.seconds >= 480 ? 2 : 1;
            const details = [hasAi ? "与 AI 聊过" : "未与 AI 对话", record ? `冥想 ${Math.round(record.seconds / 60)} 分钟` : "未冥想"].join(" · ");
            return (
              <span key={item.key} className={`activity-day ${hasAi ? "has-ai" : ""}`} title={`${item.date.getMonth() + 1}月${item.day}日 · ${details}`}>
                <i className={`meditation-fill level-${level}`} />
                <b>{item.day === 1 ? `${item.date.getMonth() + 1}/1` : item.day}</b>
              </span>
            );
          })}
        </div>
      </GlassBlock>
      <div className="mine-links">
        {[
          [Stethoscope, "就医沟通清单", "整理症状和想问医生的问题"],
          [ClockCounterClockwise, "记录历史", "回看身体与心情变化"],
          [BellSimple, "记录提醒", "每日 21:00"],
          [BookmarkSimple, "收藏内容", "保存重要建议与练习"],
          [ShieldCheck, "数据与隐私", "管理你的健康数据"],
        ].map(([Icon, title, desc]) => (
          <button key={title} onClick={() => onToast(`${title}页面将在下一轮完善`)}><span className="icon-glass"><Icon size={20} /></span><span><b>{title}</b><small>{desc}</small></span><CaretRight size={18} /></button>
        ))}
      </div>
    </div>
  );
}

export function App() {
  const requestedScreen = new URLSearchParams(window.location.search).get("screen");
  const initialTab = requestedScreen === "chat" ? "AI 对话" : requestedScreen === "meditation" ? "冥想练习" : requestedScreen === "mine" ? "我的" : "趋势";
  const [range, setRange] = useState("30天");
  const [tab, setTab] = useState(initialTab);
  const [showLanding, setShowLanding] = useState(requestedScreen === "landing");
  const [showLogin, setShowLogin] = useState(requestedScreen === "login");
  const [toast, setToast] = useState("");
  const [meditationRecords, setMeditationRecords] = useState([
    { date: "2026-04-08", seconds: 420, sessions: 1, scene: "柔风麦田" },
    { date: "2026-04-21", seconds: 780, sessions: 1, scene: "深睡轨道" },
    { date: "2026-05-03", seconds: 300, sessions: 1, scene: "清凉潮汐" },
    { date: "2026-05-18", seconds: 1080, sessions: 2, scene: "柔风麦田" },
    { date: "2026-05-28", seconds: 660, sessions: 1, scene: "深睡轨道" },
    { date: "2026-06-02", seconds: 360, sessions: 1, scene: "柔风麦田" },
    { date: "2026-06-07", seconds: 720, sessions: 1, scene: "深睡轨道" },
    { date: "2026-06-09", seconds: 480, sessions: 1, scene: "清凉潮汐" },
    { date: "2026-06-14", seconds: 960, sessions: 2, scene: "柔风麦田" },
    { date: "2026-06-18", seconds: 600, sessions: 1, scene: "深睡轨道" },
    { date: "2026-06-21", seconds: 540, sessions: 1, scene: "柔风麦田" },
    { date: "2026-06-22", seconds: 480, sessions: 1, scene: "清凉潮汐" },
  ]);
  const data = useMemo(() => trendData[range], [range]);

  const recordMeditation = ({ seconds, scene }) => {
    const todayKey = dateKey(prototypeToday);
    setMeditationRecords((records) => {
      const existing = records.find((record) => record.date === todayKey);
      if (!existing) return [...records, { date: todayKey, seconds, sessions: 1, scene }];
      return records.map((record) => record.date === todayKey
        ? { ...record, seconds: record.seconds + seconds, sessions: record.sessions + 1, scene }
        : record);
    });
  };

  const showToast = (message) => {
    setToast(message);
    window.clearTimeout(window.__toastTimer);
    window.__toastTimer = window.setTimeout(() => setToast(""), 1800);
  };

  if (showLanding) {
    return <LandingScreen onStart={() => { setShowLanding(false); setShowLogin(true); }} />;
  }

  if (showLogin) {
    return <LoginScreen onSuccess={() => { setShowLogin(false); setTab("AI 对话"); }} />;
  }

  if (tab !== "趋势") {
    return (
      <main className={`app-shell page-${tab === "AI 对话" ? "chat" : tab === "冥想练习" ? "meditation" : "mine"}`}>
        <div className="ambient ambient-b" />
        <div className="screen">
          {tab === "AI 对话" && <AIChatScreen />}
          {tab === "冥想练习" && <MeditationScreen onComplete={recordMeditation} />}
          {tab === "我的" && <MineScreen meditationRecords={meditationRecords} onToast={showToast} />}
          <BottomNav tab={tab} setTab={setTab} />
        </div>
        {toast && <div className="toast"><BellSimple size={16} />{toast}</div>}
      </main>
    );
  }

  return (
    <main className="app-shell page-trend">
      <div className="ambient ambient-a" />
      <div className="ambient ambient-b" />

      <div className="screen trend-screen">
        <header className="page-header">
          <div>
            <h1>身体趋势</h1>
            <p>基于你的日常记录生成，仅供自我观察</p>
          </div>
          <button className="round-glass" aria-label="选择日期" onClick={() => showToast("日期筛选即将开放") }>
            <CalendarBlank size={24} weight="bold" />
          </button>
        </header>
        <MedicalNotice />

        <div className="range-stage">
          <div className="range-source" aria-hidden="true" />
          <div className="range-control">
            {Object.keys(trendData).map((item) => (
              <button key={item} className={range === item ? "active" : ""} onClick={() => setRange(item)}>
                {item}
              </button>
            ))}
          </div>
        </div>

        <GlassBlock className="summary-card" source="right">
          <SectionTitle icon={TrendUp}>近 {range}概况</SectionTitle>
          <p className="summary-copy">睡眠质量正在改善，潮热出现次数有所下降</p>
          <div className="metrics">
            <div><span>记录</span><strong>18<small>天</small></strong></div>
            <div><span>潮热</span><strong>12<small>次</small></strong></div>
            <div><span>平均睡眠</span><strong>6.4<small>小时</small></strong></div>
          </div>
        </GlassBlock>

        <GlassBlock className="chart-card" source="top-right">
          <SectionTitle
            icon={ChartLineUp}
            trailing={<span className="improve-chip">较上月改善 <b>18%</b></span>}
          >
            症状变化
          </SectionTitle>
          <p className="axis-label">症状次数（次）</p>
          <div className="chart-wrap">
            <ResponsiveContainer width="100%" height={238}>
              <LineChart data={data} margin={{ top: 10, right: 8, left: -18, bottom: 0 }}>
                <CartesianGrid stroke="rgba(93,67,76,.12)" strokeDasharray="3 5" vertical={false} />
                <XAxis dataKey="date" tick={{ fill: "#64545b", fontSize: 12 }} tickLine={false} axisLine={false} />
                <YAxis domain={[0, range === "90天" ? 45 : 15]} ticks={range === "90天" ? [0, 15, 30, 45] : [0, 5, 10, 15]} tick={{ fill: "#64545b", fontSize: 12 }} tickLine={false} axisLine={false} />
                <Tooltip contentStyle={{ background: "rgba(255,255,255,.9)", border: "1px solid rgba(255,255,255,.9)", borderRadius: 14 }} />
                <Legend verticalAlign="top" align="left" height={34} iconType="plainline" formatter={(value) => value === "hot" ? "潮热" : "睡眠问题"} />
                <Line isAnimationActive={false} type="monotone" dataKey="hot" stroke="#d77f8e" strokeWidth={3} dot={{ r: 4, fill: "#d77f8e", strokeWidth: 0 }} />
                <Line isAnimationActive={false} type="monotone" dataKey="sleep" stroke="#789bbf" strokeWidth={3} dot={{ r: 4, fill: "#789bbf", strokeWidth: 0 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </GlassBlock>

        <GlassBlock className="symptoms-card" source="left">
          <SectionTitle icon={Fire}>高频症状</SectionTitle>
          <div className="symptom-grid">
            <div className="inner-glass rose"><Fire size={20} /><span>潮热</span><b>12<small>次</small></b></div>
            <div className="inner-glass mauve"><MoonStars size={20} /><span>睡眠差</span><b>9<small>次</small></b></div>
            <div className="inner-glass blush"><SmileySad size={20} /><span>焦虑</span><b>6<small>次</small></b></div>
            <div className="inner-glass neutral"><Person size={20} /><span>疲惫</span><b>5<small>次</small></b></div>
          </div>
        </GlassBlock>

        <GlassBlock className="insight-card" source="right-low">
          <SectionTitle icon={Lightbulb}>可能的触发因素</SectionTitle>
          <p>睡眠不足后的第二天，潮热记录更频繁。</p>
          <small>建议继续观察作息与潮热之间的关系</small>
        </GlassBlock>

        <GlassBlock className="next-card" source="left-low">
          <SectionTitle icon={CheckCircle}>推荐下一步</SectionTitle>
          <button className="recommend-row" onClick={() => showToast("已为你打开助眠练习") }><Wind size={20} /><span>睡前进行助眠呼吸练习</span><b>›</b></button>
          <button className="recommend-row" onClick={() => showToast("已加入记录提醒") }><Coffee size={20} /><span>继续记录咖啡因摄入</span><b>›</b></button>
        </GlassBlock>

        <div className="action-stage">
          <div className="action-source" aria-hidden="true" />
          <button className="primary-glass" onClick={() => showToast("就医沟通清单已生成") }>
            <ClipboardText size={23} weight="bold" />生成就医沟通清单
          </button>
        </div>

        <BottomNav tab={tab} setTab={setTab} />
      </div>

      {toast && <div className="toast"><BellSimple size={16} />{toast}</div>}
    </main>
  );
}
