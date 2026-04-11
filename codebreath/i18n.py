"""
Internationalization (i18n) for CodeBreath.
Supports: English (en), Chinese (zh).

Design: All translatable strings live here. Content modules and UI
modules call `t(key)` or use `get_tips(lang)` to get localized content.
"""

from dataclasses import dataclass
from typing import Dict, List

from .content import Tip


# ---------------------------------------------------------------------------
# Current language state (set once at startup from Config)
# ---------------------------------------------------------------------------

_current_lang: str = "en"


def set_language(lang: str):
    """Set the global language. Called once at startup."""
    global _current_lang
    _current_lang = lang if lang in ("en", "zh") else "en"


def get_language() -> str:
    """Get the current language."""
    return _current_lang


def t(key: str) -> str:
    """Translate a UI string key to the current language."""
    return UI_STRINGS.get(_current_lang, UI_STRINGS["en"]).get(
        key, UI_STRINGS["en"].get(key, key)
    )


# ---------------------------------------------------------------------------
# UI strings (labels, messages, prompts)
# ---------------------------------------------------------------------------

UI_STRINGS: Dict[str, Dict[str, str]] = {
    "en": {
        # Category headers
        "cat.eye": "Eye Care",
        "cat.neck": "Neck Exercise",
        "cat.eyeneck": "Eye + Neck",
        "cat.sedentary": "Move Break",
        "cat.outdoor": "Go Outside!",
        "cat.health_break": "Health Break",
        # Terminal UI
        "ui.what_to_do": "What to do:",
        "ui.why_helps": "Why it helps:",
        "ui.if_skip": "If you skip:",
        "ui.skip_hint": "Press Ctrl+C to skip this timer",
        "ui.great_job": "Great job!",
        "ui.session_complete": "Session complete!",
        "ui.back_to_coding": "Your body thanks you. Back to coding!",
        "ui.next_exercise": "Next exercise in 3 seconds...",
        "ui.exercise_n": "Exercise {i}/{total}",
        "ui.remaining": "remaining",
        "ui.done": "Done!",
        "ui.skipped": "(Skipped)",
        # Status
        "status.title": "CodeBreath Status",
        "status.not_running": "Not running",
        "status.start_hint": "Start with: codebreath start",
        "status.paused": "Paused",
        "status.resume_hint": "Resume with: codebreath resume",
        "status.running": "Running",
        "status.today_stats": "Today's stats:",
        "status.no_reminders": "No reminders yet",
        "status.completed": "completed",
        "status.next_eyeneck": "Next eye+neck:",
        "status.next_sedentary": "Next move break:",
        # Report
        "report.title": "CodeBreath Daily Report",
        "report.completion": "Completion rate:",
        "report.streak": "{n}-day streak! Keep it up!",
        # Notifier
        "notify.noon_title": "NOON: Go Outside Now!",
        "notify.noon_subtitle": "15 min outdoor walk — your eyes NEED real sunlight",
        "notify.noon_default": "Indoor = 400 lux. Outdoor = 10,000+ lux. This is the #1 thing you can do for myopia control.",
        # CLI
        "cli.auto_selected": "Auto-selected: {type} (use 'codebreath exercise eye/neck/sedentary/outdoor' to choose)",
        "cli.unknown_exercise": "Unknown exercise type: {type}",
        "cli.available_types": "Available: eye, neck, sedentary, outdoor",
        "cli.config_title": "CodeBreath Configuration",
        "cli.config_file": "Config file: ~/.codebreath/config.json",
        "cli.config_edit": "Edit with: codebreath config set <key> <value>",
        "cli.config_keys": "Available keys:",
        "cli.set_done": "Set {key} = {value}",
        "cli.restart_hint": "Restart CodeBreath for changes to take effect.",
        "cli.lang_switched": "Language switched to: {lang}",
        # Scheduler
        "sched.already_running": "CodeBreath is already running (PID {pid}).",
        "sched.stop_first": "Use 'codebreath stop' to stop it first.",
        "sched.started": "CodeBreath started (PID {pid}).",
        "sched.stop_hint": "Use 'codebreath stop' to stop.",
        "sched.fg_start": "CodeBreath started (foreground mode). Press Ctrl+C to stop.",
        "sched.stopped": "CodeBreath stopped.",
        "sched.not_running": "CodeBreath is not running.",
        "sched.stale_pid": "CodeBreath was not running (stale PID file cleaned up).",
        "sched.paused": "CodeBreath paused for {min} minutes.",
        "sched.pause_hint": "Reminders will resume automatically, or use 'codebreath resume'.",
        "sched.resumed": "CodeBreath resumed.",
    },
    "zh": {
        # Category headers
        "cat.eye": "护眼时间",
        "cat.neck": "颈椎锻炼",
        "cat.eyeneck": "护眼 + 颈肩",
        "cat.sedentary": "起来动动",
        "cat.outdoor": "出去走走！",
        "cat.health_break": "健康休息",
        # Terminal UI
        "ui.what_to_do": "做什么：",
        "ui.why_helps": "为什么要做：",
        "ui.if_skip": "不做的后果：",
        "ui.skip_hint": "按 Ctrl+C 跳过计时",
        "ui.great_job": "做得好！",
        "ui.session_complete": "锻炼完成！",
        "ui.back_to_coding": "身体感谢你，继续写代码吧！",
        "ui.next_exercise": "下一个动作 3 秒后开始...",
        "ui.exercise_n": "动作 {i}/{total}",
        "ui.remaining": "剩余",
        "ui.done": "完成！",
        "ui.skipped": "（已跳过）",
        # Status
        "status.title": "CodeBreath 状态",
        "status.not_running": "未运行",
        "status.start_hint": "启动命令：codebreath start",
        "status.paused": "已暂停",
        "status.resume_hint": "恢复命令：codebreath resume",
        "status.running": "运行中",
        "status.today_stats": "今日统计：",
        "status.no_reminders": "暂无提醒",
        "status.completed": "已完成",
        "status.next_eyeneck": "下次护眼+颈肩：",
        "status.next_sedentary": "下次起身：",
        # Report
        "report.title": "CodeBreath 每日报告",
        "report.completion": "完成率：",
        "report.streak": "连续 {n} 天！继续保持！",
        # Notifier
        "notify.noon_title": "中午了：出去晒太阳！",
        "notify.noon_subtitle": "户外走 15 分钟——你的眼睛需要自然光",
        "notify.noon_default": "室内 400 勒克斯，室外 10,000+ 勒克斯。这是控制近视最有效的方法。",
        # CLI
        "cli.auto_selected": "自动选择：{type}（用 'codebreath exercise eye/neck/sedentary/outdoor' 手动选择）",
        "cli.unknown_exercise": "未知锻炼类型：{type}",
        "cli.available_types": "可选：eye, neck, sedentary, outdoor",
        "cli.config_title": "CodeBreath 配置",
        "cli.config_file": "配置文件：~/.codebreath/config.json",
        "cli.config_edit": "修改命令：codebreath config set <key> <value>",
        "cli.config_keys": "可用配置项：",
        "cli.set_done": "已设置 {key} = {value}",
        "cli.restart_hint": "重启 CodeBreath 后生效。",
        "cli.lang_switched": "语言已切换为：{lang}",
        # Scheduler
        "sched.already_running": "CodeBreath 已在运行（PID {pid}）。",
        "sched.stop_first": "请先用 'codebreath stop' 停止。",
        "sched.started": "CodeBreath 已启动（PID {pid}）。",
        "sched.stop_hint": "用 'codebreath stop' 停止。",
        "sched.fg_start": "CodeBreath 已启动（前台模式）。按 Ctrl+C 停止。",
        "sched.stopped": "CodeBreath 已停止。",
        "sched.not_running": "CodeBreath 未在运行。",
        "sched.stale_pid": "CodeBreath 未在运行（已清理残留 PID 文件）。",
        "sched.paused": "CodeBreath 已暂停 {min} 分钟。",
        "sched.pause_hint": "提醒将自动恢复，或用 'codebreath resume' 手动恢复。",
        "sched.resumed": "CodeBreath 已恢复。",
    },
}


# ---------------------------------------------------------------------------
# Chinese content: tips, exercises, messages
# ---------------------------------------------------------------------------

EYE_TIPS_ZH: List[Tip] = [
    Tip(
        name="闭眼深呼吸",
        instruction="闭上眼睛 20 秒，做 3 次缓慢的深呼吸。",
        duration_seconds=20,
        benefit="睫状肌完全放松（调节力 = 0），比看远处效果更好。深呼吸还能降低肩部紧张。",
        consequence="睫状肌持续收缩——下班后看远处模糊。长期痉挛加速近视进展。",
        ascii_art=r"""
    之前            之后
   (o  o)         (—  —)
    \  /           \  /
     ||             ||
   紧绷           放松
        """,
        source="眼科生理学：闭眼 = 调节需求为 0",
    ),
    Tip(
        name="掌心热敷",
        instruction="双手搓热 5 秒，轻轻捂在闭合的眼睛上 20 秒。",
        duration_seconds=25,
        benefit="完全黑暗 + 温热改善眼周血液循环，缓解干眼。",
        consequence="眼周微循环差，干眼和黑眼圈加重。",
        ascii_art=r"""
     _____
    / o o \      搓热双手...
    \_____/      然后捂眼
                 
    /‾‾‾‾‾\
    |  ——  |     温暖的黑暗
    \_____/      = 深度休息
        """,
        source="经典护眼方法，经眼科验证",
    ),
    Tip(
        name="远眺放松",
        instruction="看房间最远的点（墙角、天花板）20 秒。",
        duration_seconds=20,
        benefit="睫状肌从近距离紧张中释放。3-4 米就能达到 85% 以上的放松效果。",
        consequence="调节灵活性下降——远近切换越来越慢（p=0.010）。",
        ascii_art=r"""
    屏幕 50cm     墙壁 3-4m
    ┌──────┐
    │ code │  -->    . (远点)
    │ code │
    └──────┘
    0.33D 调节    ~0D 调节
        """,
        source="Talens-Estarelles 等, Contact Lens & Anterior Eye, 2023",
    ),
    Tip(
        name="眨眼操",
        instruction="快速眨眼 20 次，然后轻闭双眼 10 秒。",
        duration_seconds=15,
        benefit="盯屏幕时眨眼频率下降 66%。主动眨眼重建泪膜，滋润角膜。",
        consequence="泪膜破裂，角膜干燥——烧灼感、瘙痒、视力模糊。",
        ascii_art=r"""
    正常:  15-20 次/分钟
    盯屏:   5-7  次/分钟  (↓66%)

    (o o)  →  (- -)  →  (o o)
     眨眼      眨眼      眨眼
      快速 x20 + 闭眼 10s
        """,
        source="AAO 建议 + 干眼研究",
    ),
    Tip(
        name="转眼球",
        instruction="闭眼。慢慢转动眼球：上→右→下→左，转 3 圈。再反方向转 3 圈。",
        duration_seconds=20,
        benefit="放松盯屏时锁死的 6 条眼外肌，改善眼球运动灵活性。",
        consequence="眼外肌因长时间固定注视而僵硬，眼球运动范围缩小。",
        ascii_art=r"""
          ↑
        ╱   ╲
      ←   •   →    顺时针 3 圈
        ╲   ╱      逆时针 3 圈
          ↓
        """,
        source="眼科眼外肌放松训练",
    ),
]

EYE_EXTRA_BENEFITS_ZH = [
    "20 秒换 2 小时清晰视力——今天性价比最高的事。",
    "闭眼时大脑进入默认模式网络——创造力提升。",
    "顺便做 3 次深呼吸——血氧瞬间提升。",
    "你的眼睛每天承受 12 小时近距离工作，它值得休息。",
    "坚持休息可减轻数码眼疲劳症状（p≤0.045，瓦伦西亚大学 2023）。",
    "高度近视 + 持续近距离用眼 = 眼轴增长风险。打断这个循环。",
    "这 20 秒能预防下午 3 点的头痛-模糊-注意力崩溃。",
]

EYE_EXTRA_CONSEQUENCES_ZH = [
    "不休息→近距离工作诱发的暂时性近视（NITM）累积。",
    "到下午 3 点：眼酸、头痛、注意力归零。生产力断崖。",
    "高度近视：每次跳过休息都在给眼轴增长加油。",
    "92% 的屏幕用户至少有 1 个数码眼疲劳症状。别再加一个。",
    "不眨眼泪膜就会破裂——角膜干燥→微损伤。",
    "现在的调节痉挛 = 以后需要更厚的镜片。",
    "连续 4 小时不休息→调节功能下降 30%。",
]

NECK_CORE_ZH: List[Tip] = [
    Tip(
        name="收下巴",
        instruction="把下巴往后收（做出双下巴）。保持 5 秒，重复 10 次。",
        duration_seconds=50,
        benefit="黄金标准动作。直接矫正头前伸，激活深层颈屈肌，恢复正常颈椎曲度。",
        consequence="头每前伸一英寸，颈椎负重增加约 4.5 公斤。前倾 60° 时颈椎承受约 27 公斤。",
        ascii_art=r"""
    错误          正确
      O  →          O
     /| 前伸       /|  下巴内收
      |             |
   +4.5kg/寸     正常负重
        """,
        source="康复医学矫正头前伸的金标准",
    ),
    Tip(
        name="胸椎伸展",
        instruction="坐直，双手交叉放脑后。上背部轻轻靠在椅背上向后弓。保持 10 秒，重复 5 次。",
        duration_seconds=50,
        benefit="打开胸腔，矫正驼背（胸椎后凸），解决颈椎代偿的根本原因。还能改善呼吸容量。",
        consequence="胸椎后凸加重，迫使颈椎前伸代偿——恶性循环。",
        ascii_art=r"""
    之前           之后
      ╮              |
     ╭╯  驼背       ╱  伸展
    ╱    圆背      ╱   打开胸腔
   坐姿          靠椅背弓
        """,
        source="Kang 等, Turk J Phys Med Rehabil, 2021 (RCT)",
    ),
    Tip(
        name="肩胛骨内收",
        instruction="两侧肩胛骨向中间夹紧，像夹住一支铅笔。保持 5 秒，重复 10 次。",
        duration_seconds=50,
        benefit="激活菱形肌和中下斜方肌，矫正圆肩，恢复肩胛骨稳定性。",
        consequence="圆肩加重，肩胛不稳导致颈肩连锁问题。",
        ascii_art=r"""
    俯视图
    
    ╭ ╮  肩膀      ╭ ╮  肩膀
    │→│  前伸      │←│  内收
    ╰ ╯  (差)      ╰ ╯  (好)
    
    像夹住一支铅笔
        """,
        source="Kang 2021 + Cools 等, Br J Sports Med, 2014",
    ),
]

NECK_AUX_ZH: List[Tip] = [
    Tip(
        name="侧颈拉伸",
        instruction="慢慢将头向左肩倾斜（耳朵靠肩膀）。保持 15 秒。换右侧。每侧再做一次。",
        duration_seconds=60,
        benefit="释放上斜方肌和斜角肌——盯屏幕时最容易僵硬的肌肉。",
        consequence="上斜方肌长期紧张→紧张型头痛，办公室人群最常见的头痛类型。",
        ascii_art=r"""
         O            O
        /|\\         //|
         |     →      |
     直立      侧倾 (耳→肩)
     每侧保持 15 秒
        """,
        source="上斜方肌基础拉伸",
    ),
    Tip(
        name="颈部旋转",
        instruction="慢慢转头看左肩方向。保持 10 秒。转向右侧。每侧再做一次。",
        duration_seconds=40,
        benefit="维持颈椎活动范围，防止关节僵硬。",
        consequence="关节活动度逐渐下降，可能导致退行性变化。",
        ascii_art=r"""
         O     →      O
        /|           /|
         |            |
       正面     转头 (看肩膀方向)
       每侧保持 10 秒
        """,
        source="颈椎活动度维持训练",
    ),
    Tip(
        name="耸肩放松",
        instruction="用力耸肩到耳朵位置（5 秒），然后突然放下完全放松。重复 5 次。",
        duration_seconds=50,
        benefit="快速释放上斜方肌紧张——肩颈僵硬的即时缓解。",
        consequence="上斜方肌长期过度激活，形成触发点和放射痛。",
        ascii_art=r"""
     ╱O╲   耸肩        O    放下 & 放松
    ╱ | ╲  (5 秒)     ╱|╲   (释放！)
      |                |
    紧绷！           舒服...
      x5 次
        """,
        source="斜方肌肌肉放松技术",
    ),
]

SEDENTARY_TIPS_ZH: List[Tip] = [
    Tip(
        name="接杯水",
        instruction="走到茶水间，把水杯灌满。",
        duration_seconds=180,
        benefit="走路 + 补水一举两得。充足饮水还能缓解干眼。",
        consequence="脱水加重干眼和认知能力下降。你现在很可能已经缺水了。",
    ),
    Tip(
        name="走廊走 50 步",
        instruction="离开工位，至少走 50 步。挑远路走。",
        duration_seconds=180,
        benefit="恢复下肢血液循环，减少血液淤积导致的腿部肿胀。",
        consequence="久坐时血液淤积在下肢→深静脉血栓风险 + 下午腿沉。",
    ),
    Tip(
        name="站立拉伸",
        instruction="站起来，双臂举过头顶，全身向上拉伸 10 秒。重复 3 次。",
        duration_seconds=60,
        benefit="给脊椎减压。坐着时腰椎间盘承受的压力是站立时的 1.4 倍。",
        consequence="腰椎间盘持续受压→加速椎间盘退变。",
    ),
    Tip(
        name="10 个深蹲",
        instruction="站起来做 10 个慢速深蹲（3 秒下蹲，1 秒起立）。",
        duration_seconds=60,
        benefit="激活身体最大肌群（股四头肌 + 臀肌）。快速提升心率和代谢。",
        consequence="下肢肌肉因废用而萎缩，基础代谢率下降。",
    ),
    Tip(
        name="上个厕所",
        instruction="去趟洗手间——即使你觉得不太急。",
        duration_seconds=180,
        benefit="强制走路 + 避免憋尿（久坐族的常见坏习惯）。",
        consequence="憋尿增加泌尿道感染风险，久坐族常常忽视这点。",
    ),
    Tip(
        name="靠墙站 1 分钟",
        instruction="背靠墙站：后脑勺、肩胛骨、臀部、脚后跟都贴墙。保持 1 分钟。",
        duration_seconds=60,
        benefit="重置正确体态。一个动作同时矫正圆肩和头前伸。",
        consequence="错误姿势变成你的默认设定。身体会真的忘记「直」是什么感觉。",
    ),
    Tip(
        name="20 个提踵",
        instruction="站立，慢慢踮脚尖 20 次。控制节奏，慢上慢下。",
        duration_seconds=40,
        benefit="激活小腿肌肉泵——你的「第二心脏」，促进下肢静脉回流。",
        consequence="小腿肌肉泵因废用而减弱→静脉回流差→脚踝肿胀。",
    ),
]

NOON_OUTDOOR_ZH = Tip(
    name="午间户外走走",
    instruction="出去走 15 分钟。散步、买饭、或者就站在阳光下。",
    duration_seconds=900,
    benefit="户外光照（10,000+ 勒克斯）触发视网膜多巴胺释放——已知最强的延缓近视进展因素。还能重置生物钟，改善今晚睡眠。",
    consequence="室内照明只有 300-500 勒克斯（不到户外的三十分之一）。缺少日光：近视继续进展、生物钟紊乱、维生素 D 不足、情绪低落。",
    source="多项 RCT 研究证实户外时间与近视控制的关系，尤其在东亚人群中",
)

NOON_EXTRA_MESSAGES_ZH = [
    "即使阴天，户外光照也有 5,000-10,000 勒克斯。你的办公室？大约 400。",
    "这是你今天能为眼睛做的最有价值的事。",
    "15 分钟日光还能提升血清素。回来写代码更高效。",
    "你的视网膜需要真正的阳光——人造光源无法完全替代。",
    "户外时间是循证医学中排名第一的近视控制干预手段。",
]


# ---------------------------------------------------------------------------
# Language-aware content accessor
# ---------------------------------------------------------------------------


def get_eye_tips(lang: str = "") -> list:
    """Get eye tips for the specified language."""
    lang = lang or _current_lang
    if lang == "zh":
        return EYE_TIPS_ZH
    from .content import EYE_TIPS

    return EYE_TIPS


def get_eye_extra_benefits(lang: str = "") -> list:
    """Get eye extra benefit messages."""
    lang = lang or _current_lang
    if lang == "zh":
        return EYE_EXTRA_BENEFITS_ZH
    from .content import EYE_EXTRA_BENEFITS

    return EYE_EXTRA_BENEFITS


def get_eye_extra_consequences(lang: str = "") -> list:
    """Get eye extra consequence messages."""
    lang = lang or _current_lang
    if lang == "zh":
        return EYE_EXTRA_CONSEQUENCES_ZH
    from .content import EYE_EXTRA_CONSEQUENCES

    return EYE_EXTRA_CONSEQUENCES


def get_neck_core(lang: str = "") -> list:
    """Get core neck exercises."""
    lang = lang or _current_lang
    if lang == "zh":
        return NECK_CORE_ZH
    from .content import NECK_CORE

    return NECK_CORE


def get_neck_aux(lang: str = "") -> list:
    """Get auxiliary neck exercises."""
    lang = lang or _current_lang
    if lang == "zh":
        return NECK_AUX_ZH
    from .content import NECK_AUX

    return NECK_AUX


def get_sedentary_tips(lang: str = "") -> list:
    """Get sedentary break tips."""
    lang = lang or _current_lang
    if lang == "zh":
        return SEDENTARY_TIPS_ZH
    from .content import SEDENTARY_TIPS

    return SEDENTARY_TIPS


def get_noon_outdoor(lang: str = "") -> Tip:
    """Get the noon outdoor reminder tip."""
    lang = lang or _current_lang
    if lang == "zh":
        return NOON_OUTDOOR_ZH
    from .content import NOON_OUTDOOR

    return NOON_OUTDOOR


def get_noon_extra_messages(lang: str = "") -> list:
    """Get noon extra messages."""
    lang = lang or _current_lang
    if lang == "zh":
        return NOON_EXTRA_MESSAGES_ZH
    from .content import NOON_EXTRA_MESSAGES

    return NOON_EXTRA_MESSAGES
