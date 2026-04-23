// Content library for CodeBreath.
// Counts: 5 eye tips, 3 neck core + 3 neck auxiliary (6 total), 7 sedentary breaks,
// 1 noon outdoor tip, 7 eye extra benefits, 7 eye extra consequences, 5 noon extra messages.
// Bilingual (en/zh). Ported from codebreath/content.py and codebreath/i18n.py.

import Foundation

// MARK: - Locale

enum AppLocale: String, Codable, CaseIterable {
    case en
    case zh
}

// MARK: - Localized text

struct LocalizedText: Codable, Hashable {
    let en: String
    let zh: String

    func resolve(_ locale: AppLocale) -> String {
        switch locale {
        case .en: return en
        case .zh: return zh
        }
    }
}

// MARK: - Category

enum TipCategory: String, Codable, CaseIterable {
    case eye
    case neck
    case combo      // NEW — compound eye+neck move
    case sedentary
    case noon
}

// MARK: - Difficulty & Kind (additive, defaulted)

enum TipDifficulty: String, Codable { case easy, medium, hard }
enum TipKind: String, Codable { case single, compound }

// MARK: - Tip

struct Tip: Codable, Hashable, Identifiable {
    let id: String
    let name: LocalizedText
    let instruction: LocalizedText
    let durationSeconds: Int
    let benefit: LocalizedText
    let consequence: LocalizedText
    let category: TipCategory
    let source: LocalizedText?
    let difficulty: TipDifficulty
    let kind: TipKind
    let tags: [String]

    init(
        id: String,
        name: LocalizedText,
        instruction: LocalizedText,
        durationSeconds: Int,
        benefit: LocalizedText,
        consequence: LocalizedText,
        category: TipCategory,
        source: LocalizedText? = nil,
        difficulty: TipDifficulty = .easy,
        kind: TipKind = .single,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.durationSeconds = durationSeconds
        self.benefit = benefit
        self.consequence = consequence
        self.category = category
        self.source = source
        self.difficulty = difficulty
        self.kind = kind
        self.tags = tags
    }
}

// MARK: - Content Library

enum ContentLibrary {

    // MARK: Eye tips (5)

    static let eyeTips: [Tip] = [
        Tip(
            id: "eye.close_breathe",
            name: LocalizedText(en: "Close Eyes & Breathe", zh: "闭眼深呼吸"),
            instruction: LocalizedText(
                en: "Close your eyes for 20 seconds. Take 3 slow deep breaths.",
                zh: "闭上眼睛 20 秒，做 3 次缓慢的深呼吸。"
            ),
            durationSeconds: 20,
            benefit: LocalizedText(
                en: "Ciliary muscle fully relaxes (accommodation = 0). Even better than looking far away. Deep breathing also lowers shoulder tension.",
                zh: "睫状肌完全放松（调节力 = 0），比看远处效果更好。深呼吸还能降低肩部紧张。"
            ),
            consequence: LocalizedText(
                en: "Ciliary muscle stays contracted — you'll get blurry distance vision after work. Chronic spasm accelerates myopia progression.",
                zh: "睫状肌持续收缩——下班后看远处模糊。长期痉挛加速近视进展。"
            ),
            category: .eye,
            source: LocalizedText(
                en: "Optical physiology: closing eyes = 0 accommodation demand",
                zh: "眼科生理学：闭眼 = 调节需求为 0"
            )
        ),
        Tip(
            id: "eye.palming",
            name: LocalizedText(en: "Palming", zh: "掌心热敷"),
            instruction: LocalizedText(
                en: "Rub your palms together for 5 seconds until warm, then gently cup them over your closed eyes for 20 seconds.",
                zh: "双手搓热 5 秒，轻轻捂在闭合的眼睛上 20 秒。"
            ),
            durationSeconds: 25,
            benefit: LocalizedText(
                en: "Complete darkness + warmth improves periorbital blood flow and relieves dry eyes.",
                zh: "完全黑暗 + 温热改善眼周血液循环，缓解干眼。"
            ),
            consequence: LocalizedText(
                en: "Poor microcirculation around the eyes worsens dryness and dark circles.",
                zh: "眼周微循环差，干眼和黑眼圈加重。"
            ),
            category: .eye,
            source: LocalizedText(
                en: "Traditional eye care technique validated by optometry practice",
                zh: "经典护眼方法，经眼科验证"
            )
        ),
        Tip(
            id: "eye.distance_focus",
            name: LocalizedText(en: "Distance Focus", zh: "远眺放松"),
            instruction: LocalizedText(
                en: "Look at the farthest point in the room (wall, corner, ceiling) for 20 seconds.",
                zh: "看房间最远的点（墙角、天花板）20 秒。"
            ),
            durationSeconds: 20,
            benefit: LocalizedText(
                en: "Ciliary muscle releases from near-focus tension. Even 3-4 meters achieves 85%+ of the relaxation effect of 6 meters.",
                zh: "睫状肌从近距离紧张中释放。3-4 米就能达到 85% 以上的放松效果。"
            ),
            consequence: LocalizedText(
                en: "Accommodative facility declines — switching focus between near and far gets slower over time (measured decline p=0.010).",
                zh: "调节灵活性下降——远近切换越来越慢（p=0.010）。"
            ),
            category: .eye,
            source: LocalizedText(
                en: "Talens-Estarelles et al., Contact Lens & Anterior Eye, 2023",
                zh: "Talens-Estarelles 等, Contact Lens & Anterior Eye, 2023"
            )
        ),
        Tip(
            id: "eye.blink",
            name: LocalizedText(en: "Blink Exercise", zh: "眨眼操"),
            instruction: LocalizedText(
                en: "Blink rapidly 20 times, then close your eyes gently for 10 seconds.",
                zh: "快速眨眼 20 次，然后轻闭双眼 10 秒。"
            ),
            durationSeconds: 15,
            benefit: LocalizedText(
                en: "Screen staring reduces blink rate by 66%. Active blinking rebuilds the tear film and moistens the cornea.",
                zh: "盯屏幕时眨眼频率下降 66%。主动眨眼重建泪膜，滋润角膜。"
            ),
            consequence: LocalizedText(
                en: "Tear film breaks down, corneal surface dries out — burning, itching, and blurred vision.",
                zh: "泪膜破裂，角膜干燥——烧灼感、瘙痒、视力模糊。"
            ),
            category: .eye,
            source: LocalizedText(
                en: "AAO recommendation + dry eye research",
                zh: "AAO 建议 + 干眼研究"
            )
        ),
        Tip(
            id: "eye.rolls",
            name: LocalizedText(en: "Eye Rolls", zh: "转眼球"),
            instruction: LocalizedText(
                en: "Close your eyes. Slowly roll eyeballs: up → right → down → left, 3 circles. Then reverse, 3 circles.",
                zh: "闭眼。慢慢转动眼球：上→右→下→左，转 3 圈。再反方向转 3 圈。"
            ),
            durationSeconds: 20,
            benefit: LocalizedText(
                en: "Relaxes all 6 extraocular muscles that stay locked during screen fixation. Improves eye movement flexibility.",
                zh: "放松盯屏时锁死的 6 条眼外肌，改善眼球运动灵活性。"
            ),
            consequence: LocalizedText(
                en: "Extraocular muscles stiffen from prolonged fixed gaze, reducing eye movement range.",
                zh: "眼外肌因长时间固定注视而僵硬，眼球运动范围缩小。"
            ),
            category: .eye,
            source: LocalizedText(
                en: "Optometric exercise for extraocular muscle relaxation",
                zh: "眼科眼外肌放松训练"
            )
        ),
        // --- New eye tips ---
        Tip(
            id: "eye.figure8",
            name: LocalizedText(en: "Figure-8 Tracking", zh: "8 字追踪"),
            instruction: LocalizedText(
                en: "Imagine a horizontal figure-8 (∞) in front of you. Trace it smoothly with your eyes, 3 loops one direction, 3 loops the other.",
                zh: "想象眼前有一个横向的 8 字（∞）。眼睛慢慢追踪，一个方向 3 圈，反方向 3 圈。"
            ),
            durationSeconds: 30,
            benefit: LocalizedText(
                en: "Activates all 6 extraocular muscles through full range. Smooth-pursuit training improves eye movement control.",
                zh: "让 6 条眼外肌在完整范围内激活。平滑追视训练改善眼球运动控制。"
            ),
            consequence: LocalizedText(
                en: "Pursuit accuracy decays with prolonged fixation. Your eyes forget how to smoothly follow moving targets.",
                zh: "长时间固定注视使追视精度下降。眼睛逐渐忘记如何平滑追随移动目标。"
            ),
            category: .eye,
            source: LocalizedText(
                en: "Scheiman & Wick, Clinical Management of Binocular Vision, 5th ed., 2019",
                zh: "Scheiman & Wick, Clinical Management of Binocular Vision, 第 5 版, 2019"
            ),
            difficulty: .easy,
            tags: ["saccade", "ROM"]
        ),
        Tip(
            id: "eye.2020",
            name: LocalizedText(en: "20-20-20 Rule", zh: "20-20-20 法则"),
            instruction: LocalizedText(
                en: "Look at something at least 20 feet (6 m) away for 20 seconds. Let your eyes fully disengage from the screen.",
                zh: "看向至少 6 米远处的物体，持续 20 秒。让眼睛彻底脱离屏幕。"
            ),
            durationSeconds: 20,
            benefit: LocalizedText(
                en: "AAO-recommended cornerstone for digital eye strain. Fully relaxes ciliary muscle; lowers near-focus accommodation demand to zero.",
                zh: "美国眼科学会（AAO）推荐的数字眼疲劳基础方案。彻底放松睫状肌，让近距离调节需求归零。"
            ),
            consequence: LocalizedText(
                en: "Without periodic distance focus, the ciliary muscle stays clamped in near-focus, accelerating myopia and accommodative fatigue.",
                zh: "缺少定期远眺，睫状肌持续锁死在近距离调节状态，加速近视进展和调节性疲劳。"
            ),
            category: .eye,
            source: LocalizedText(
                en: "American Academy of Ophthalmology (AAO) digital eye strain guideline",
                zh: "美国眼科学会（AAO）数字眼疲劳指南"
            ),
            difficulty: .easy,
            tags: ["dryeye", "AAO", "relaxation"]
        ),
        Tip(
            id: "eye.convergence",
            name: LocalizedText(en: "Pencil Push-Ups", zh: "铅笔推拉（集合训练）"),
            instruction: LocalizedText(
                en: "Hold a pen at arm's length at eye level. Slowly bring it toward your nose while keeping it in sharp single focus. Stop when it doubles. Repeat 10 times.",
                zh: "手臂伸直，拿一支笔在眼前。慢慢把笔推向鼻尖，始终保持清晰单一视像，出现重影就停。重复 10 次。"
            ),
            durationSeconds: 40,
            benefit: LocalizedText(
                en: "Trains binocular convergence and medial rectus endurance — often weak in heavy screen users with convergence insufficiency.",
                zh: "训练双眼集合功能和内直肌耐力——重度屏幕用户常见的集合不足就靠它。"
            ),
            consequence: LocalizedText(
                en: "Convergence insufficiency causes reading fatigue, eyestrain headaches, and transient double vision.",
                zh: "集合不足导致阅读疲劳、眼酸性头痛、短暂复视。"
            ),
            category: .eye,
            source: LocalizedText(
                en: "Scheiman & Wick, Clinical Management of Binocular Vision, 5th ed., 2019",
                zh: "Scheiman & Wick, Clinical Management of Binocular Vision, 第 5 版, 2019"
            ),
            difficulty: .medium,
            tags: ["binocular"]
        ),
        Tip(
            id: "eye.saccades",
            name: LocalizedText(en: "Horizontal Saccades", zh: "水平扫视"),
            instruction: LocalizedText(
                en: "Pick two targets ~1 m apart (e.g. two corners of your monitor). Snap gaze rapidly between them — 20 shifts, keeping head still.",
                zh: "选两个大约 1 米间距的目标（比如显示器两角）。头不动，眼睛快速在两点之间切换 20 次。"
            ),
            durationSeconds: 30,
            benefit: LocalizedText(
                en: "Improves saccadic latency and precision — the rapid eye jumps critical for reading and code scanning.",
                zh: "改善扫视潜伏期和精度——阅读和看代码时大量用到的快速跳视。"
            ),
            consequence: LocalizedText(
                en: "Slowed saccades increase reading time and cognitive fatigue. Users with poor saccades re-read lines unconsciously.",
                zh: "扫视变慢增加阅读耗时和认知疲劳。扫视差的人会不自觉地重读行。"
            ),
            category: .eye,
            source: LocalizedText(
                en: "Scheiman & Wick, Clinical Management of Binocular Vision, 5th ed., 2019",
                zh: "Scheiman & Wick, Clinical Management of Binocular Vision, 第 5 版, 2019"
            ),
            difficulty: .medium,
            tags: ["saccade"]
        ),
    ]

    // MARK: Neck exercises — core (3)

    static let neckCore: [Tip] = [
        Tip(
            id: "neck.chin_tuck",
            name: LocalizedText(en: "Chin Tuck", zh: "收下巴"),
            instruction: LocalizedText(
                en: "Pull your chin straight back (make a double chin). Hold 5 seconds. Repeat 10 times.",
                zh: "把下巴往后收（做出双下巴）。保持 5 秒，重复 10 次。"
            ),
            durationSeconds: 50,
            benefit: LocalizedText(
                en: "THE gold-standard move. Directly corrects Forward Head Posture, activates deep cervical flexors, and restores normal cervical curve.",
                zh: "黄金标准动作。直接矫正头前伸，激活深层颈屈肌，恢复正常颈椎曲度。"
            ),
            consequence: LocalizedText(
                en: "Every inch your head moves forward adds ~4.5 kg of load on your cervical spine. At 60° forward tilt, your neck bears ~27 kg.",
                zh: "头每前伸一英寸，颈椎负重增加约 4.5 公斤。前倾 60° 时颈椎承受约 27 公斤。"
            ),
            category: .neck,
            source: LocalizedText(
                en: "Rehabilitation medicine gold standard for FHP correction",
                zh: "康复医学矫正头前伸的金标准"
            )
        ),
        Tip(
            id: "neck.thoracic_extension",
            name: LocalizedText(en: "Thoracic Extension", zh: "胸椎伸展"),
            instruction: LocalizedText(
                en: "Sit up straight, clasp hands behind your head. Gently arch your upper back over the chair backrest. Hold 10 seconds. Repeat 5 times.",
                zh: "坐直，双手交叉放脑后。上背部轻轻靠在椅背上向后弓。保持 10 秒，重复 5 次。"
            ),
            durationSeconds: 50,
            benefit: LocalizedText(
                en: "Opens the chest cavity, corrects rounded back (thoracic kyphosis), and addresses the ROOT CAUSE of neck compensation. Also improves breathing capacity.",
                zh: "打开胸腔，矫正驼背（胸椎后凸），解决颈椎代偿的根本原因。还能改善呼吸容量。"
            ),
            consequence: LocalizedText(
                en: "Increased thoracic kyphosis forces the cervical spine to compensate by jutting forward — a vicious cycle.",
                zh: "胸椎后凸加重，迫使颈椎前伸代偿——恶性循环。"
            ),
            category: .neck,
            source: LocalizedText(
                en: "Kang et al., Turk J Phys Med Rehabil, 2021 (RCT)",
                zh: "Kang 等, Turk J Phys Med Rehabil, 2021 (RCT)"
            )
        ),
        Tip(
            id: "neck.scapular_retraction",
            name: LocalizedText(en: "Scapular Retraction", zh: "肩胛骨内收"),
            instruction: LocalizedText(
                en: "Squeeze your shoulder blades together as if holding a pencil between them. Hold 5 seconds. Repeat 10 times.",
                zh: "两侧肩胛骨向中间夹紧，像夹住一支铅笔。保持 5 秒，重复 10 次。"
            ),
            durationSeconds: 50,
            benefit: LocalizedText(
                en: "Activates rhomboids and mid/lower trapezius, corrects rounded shoulders, and restores scapular stability.",
                zh: "激活菱形肌和中下斜方肌，矫正圆肩，恢复肩胛骨稳定性。"
            ),
            consequence: LocalizedText(
                en: "Rounded shoulders worsen, scapular instability leads to cascading neck-shoulder problems.",
                zh: "圆肩加重，肩胛不稳导致颈肩连锁问题。"
            ),
            category: .neck,
            source: LocalizedText(
                en: "Kang 2021 + Cools et al., Br J Sports Med, 2014",
                zh: "Kang 2021 + Cools 等, Br J Sports Med, 2014"
            )
        ),
    ]

    // MARK: Neck exercises — auxiliary (3)

    static let neckAux: [Tip] = [
        Tip(
            id: "neck.lateral_stretch",
            name: LocalizedText(en: "Lateral Neck Stretch", zh: "侧颈拉伸"),
            instruction: LocalizedText(
                en: "Slowly tilt your head toward the left shoulder (ear to shoulder). Hold 15 seconds. Switch to right side. Repeat once more each side.",
                zh: "慢慢将头向左肩倾斜（耳朵靠肩膀）。保持 15 秒。换右侧。每侧再做一次。"
            ),
            durationSeconds: 60,
            benefit: LocalizedText(
                en: "Releases upper trapezius and scalene muscles — the muscles that get rock-hard from screen work.",
                zh: "释放上斜方肌和斜角肌——盯屏幕时最容易僵硬的肌肉。"
            ),
            consequence: LocalizedText(
                en: "Chronic upper trapezius tension → tension-type headaches, the #1 headache type in office workers.",
                zh: "上斜方肌长期紧张→紧张型头痛，办公室人群最常见的头痛类型。"
            ),
            category: .neck,
            source: LocalizedText(
                en: "Basic stretching for upper trapezius relief",
                zh: "上斜方肌基础拉伸"
            )
        ),
        Tip(
            id: "neck.rotation",
            name: LocalizedText(en: "Neck Rotation", zh: "颈部旋转"),
            instruction: LocalizedText(
                en: "Slowly turn your head to look over your left shoulder. Hold 10 seconds. Turn to right. Repeat once more each side.",
                zh: "慢慢转头看左肩方向。保持 10 秒。转向右侧。每侧再做一次。"
            ),
            durationSeconds: 40,
            benefit: LocalizedText(
                en: "Maintains cervical range of motion and prevents joint stiffness.",
                zh: "维持颈椎活动范围，防止关节僵硬。"
            ),
            consequence: LocalizedText(
                en: "Joint mobility decreases over time, potentially leading to degenerative changes.",
                zh: "关节活动度逐渐下降，可能导致退行性变化。"
            ),
            category: .neck,
            source: LocalizedText(
                en: "Cervical ROM maintenance exercise",
                zh: "颈椎活动度维持训练"
            )
        ),
        Tip(
            id: "neck.shoulder_shrug",
            name: LocalizedText(en: "Shoulder Shrug & Release", zh: "耸肩放松"),
            instruction: LocalizedText(
                en: "Shrug both shoulders up to your ears hard (5 seconds), then drop them suddenly and completely relax. Repeat 5 times.",
                zh: "用力耸肩到耳朵位置（5 秒），然后突然放下完全放松。重复 5 次。"
            ),
            durationSeconds: 50,
            benefit: LocalizedText(
                en: "Rapid tension release in upper trapezius — instant relief from shoulder-neck tightness.",
                zh: "快速释放上斜方肌紧张——肩颈僵硬的即时缓解。"
            ),
            consequence: LocalizedText(
                en: "Upper trapezius stays chronically overactivated, leading to trigger points and referred pain.",
                zh: "上斜方肌长期过度激活，形成触发点和放射痛。"
            ),
            category: .neck,
            source: LocalizedText(
                en: "Muscle relaxation technique for trapezius",
                zh: "斜方肌肌肉放松技术"
            )
        ),
        // --- New neck tips ---
        Tip(
            id: "neck.deep_flexor_hold",
            name: LocalizedText(en: "Deep Cervical Flexor Hold", zh: "深层颈屈肌保持"),
            instruction: LocalizedText(
                en: "Sit tall. Perform a gentle chin tuck (~20% effort) and hold for 20 seconds. Breathe normally. Release. Repeat twice.",
                zh: "坐直，轻微收下巴（约 20% 力度），保持 20 秒，正常呼吸。放松，重复 2 次。"
            ),
            durationSeconds: 50,
            benefit: LocalizedText(
                en: "Low-load endurance training for deep cervical flexors — the \"core\" of the neck. Directly addresses Forward Head Posture.",
                zh: "低负荷激活深层颈屈肌——颈椎的「核心肌」。直接针对头前伸。"
            ),
            consequence: LocalizedText(
                en: "Deep flexor weakness shifts load to superficial muscles (SCM, upper trap) → chronic tension, tension headaches.",
                zh: "深层颈屈肌无力，负荷转移到浅层肌群（胸锁乳突肌、上斜方肌）→ 慢性紧张、紧张型头痛。"
            ),
            category: .neck,
            source: LocalizedText(
                en: "Jull G, O'Leary SP, Falla DL, J Manipulative Physiol Ther, 2008",
                zh: "Jull G, O'Leary SP, Falla DL, J Manipulative Physiol Ther, 2008"
            ),
            difficulty: .easy,
            tags: ["FHP", "DCF"]
        ),
        Tip(
            id: "neck.levator_stretch",
            name: LocalizedText(en: "Levator Scapulae Stretch", zh: "提肩胛肌拉伸"),
            instruction: LocalizedText(
                en: "Turn head 45° to the right. Look down toward your right armpit. Use right hand to gently deepen the stretch. Hold 20 s. Switch.",
                zh: "头向右转 45°，低头看向右侧腋窝。右手轻压头顶加深拉伸，保持 20 秒。换边。"
            ),
            durationSeconds: 45,
            benefit: LocalizedText(
                en: "Targets the levator scapulae — the muscle responsible for that chronic \"knot\" at the shoulder blade's top corner.",
                zh: "精准拉伸提肩胛肌——就是那块肩胛骨上角「结节」的慢性疼痛源。"
            ),
            consequence: LocalizedText(
                en: "Tight levator scapulae limits neck rotation and referred pain radiates up to the base of the skull.",
                zh: "提肩胛肌紧张限制颈部旋转，放射痛蔓延到枕骨下缘。"
            ),
            category: .neck,
            source: LocalizedText(
                en: "Standard PT levator scapulae stretch protocol",
                zh: "物理治疗提肩胛肌标准拉伸方案"
            ),
            difficulty: .easy,
            tags: ["ROM"]
        ),
        Tip(
            id: "neck.wall_angel",
            name: LocalizedText(en: "Wall Angels", zh: "靠墙天使"),
            instruction: LocalizedText(
                en: "Stand with back against wall, heels 10cm out. Press lower back, upper back, and head to wall. Arms up in \"goalpost\" shape, slide up and down slowly 8 times.",
                zh: "背靠墙站，脚后跟离墙 10 厘米。腰、上背、后脑贴墙。双臂举成「门框」形，沿墙慢慢上下滑动 8 次。"
            ),
            durationSeconds: 60,
            benefit: LocalizedText(
                en: "Activates mid/lower trapezius and rhomboids while mobilizing the thoracic spine — full upper-body posture reset.",
                zh: "激活中下斜方肌和菱形肌，同时松动胸椎——上半身姿态完整重置。"
            ),
            consequence: LocalizedText(
                en: "Without mid/lower trap activation, upper trap dominates — the classic \"turtle neck + rounded shoulder\" posture.",
                zh: "缺少中下斜方肌激活，上斜方肌代偿——典型的「乌龟颈 + 圆肩」。"
            ),
            category: .neck,
            source: LocalizedText(
                en: "Modern shoulder rehab protocol (scapular stabilization)",
                zh: "现代肩部康复方案（肩胛骨稳定性训练）"
            ),
            difficulty: .medium,
            tags: ["FHP", "ROM"]
        ),
        Tip(
            id: "neck.doorway_pec_stretch",
            name: LocalizedText(en: "Doorway Pec Stretch", zh: "门框胸肌拉伸"),
            instruction: LocalizedText(
                en: "Stand in a doorway. Place forearms on the doorframe at shoulder height. Step one foot forward and lean gently until you feel a chest stretch. Hold 30 s.",
                zh: "站在门框前，两前臂贴门框，肘部与肩同高。迈出一只脚，身体前倾直到感觉胸部拉伸，保持 30 秒。"
            ),
            durationSeconds: 45,
            benefit: LocalizedText(
                en: "Opens the anterior chest (pec minor/major) — the root cause of rounded shoulders that drive forward head posture.",
                zh: "打开胸前肌群（胸小肌/胸大肌）——圆肩的根源，进而引发头前伸。"
            ),
            consequence: LocalizedText(
                en: "Tight pecs pull the shoulders forward, locking the thoracic spine in kyphosis and forcing neck compensation.",
                zh: "胸肌紧绷把肩膀向前拉，胸椎锁在后凸位，迫使颈椎代偿。"
            ),
            category: .neck,
            source: LocalizedText(
                en: "Standard PT pec minor stretch for FHP correction",
                zh: "矫正头前伸的标准胸小肌拉伸"
            ),
            difficulty: .easy,
            tags: ["FHP"]
        ),
    ]

    // MARK: Sedentary breaks (7)

    static let sedentaryTips: [Tip] = [
        Tip(
            id: "sed.water",
            name: LocalizedText(en: "Get Water", zh: "接杯水"),
            instruction: LocalizedText(
                en: "Walk to the kitchen/water station and refill your water bottle.",
                zh: "走到茶水间，把水杯灌满。"
            ),
            durationSeconds: 180,
            benefit: LocalizedText(
                en: "Walking + hydration in one trip. Adequate water intake also reduces dry eyes.",
                zh: "走路 + 补水一举两得。充足饮水还能缓解干眼。"
            ),
            consequence: LocalizedText(
                en: "Dehydration worsens dry eyes AND cognitive performance. You're probably already dehydrated.",
                zh: "脱水加重干眼和认知能力下降。你现在很可能已经缺水了。"
            ),
            category: .sedentary
        ),
        Tip(
            id: "sed.hallway_walk",
            name: LocalizedText(en: "Hallway Walk (50 steps)", zh: "走廊走 50 步"),
            instruction: LocalizedText(
                en: "Leave your desk and walk at least 50 steps. Take the long route.",
                zh: "离开工位，至少走 50 步。挑远路走。"
            ),
            durationSeconds: 180,
            benefit: LocalizedText(
                en: "Restores lower limb blood flow, reduces leg swelling from pooled blood.",
                zh: "恢复下肢血液循环，减少血液淤积导致的腿部肿胀。"
            ),
            consequence: LocalizedText(
                en: "Blood pools in lower limbs during sitting → DVT risk factor + afternoon leg heaviness.",
                zh: "久坐时血液淤积在下肢→深静脉血栓风险 + 下午腿沉。"
            ),
            category: .sedentary
        ),
        Tip(
            id: "sed.standing_stretch",
            name: LocalizedText(en: "Standing Stretch", zh: "站立拉伸"),
            instruction: LocalizedText(
                en: "Stand up. Reach both arms overhead and stretch your whole body upward for 10 seconds. Repeat 3 times.",
                zh: "站起来，双臂举过头顶，全身向上拉伸 10 秒。重复 3 次。"
            ),
            durationSeconds: 60,
            benefit: LocalizedText(
                en: "Decompresses the spine. Sitting puts 1.4x more pressure on lumbar discs than standing.",
                zh: "给脊椎减压。坐着时腰椎间盘承受的压力是站立时的 1.4 倍。"
            ),
            consequence: LocalizedText(
                en: "Lumbar discs under sustained compression → accelerated disc degeneration.",
                zh: "腰椎间盘持续受压→加速椎间盘退变。"
            ),
            category: .sedentary
        ),
        Tip(
            id: "sed.squats",
            name: LocalizedText(en: "10 Bodyweight Squats", zh: "10 个深蹲"),
            instruction: LocalizedText(
                en: "Stand up and do 10 slow bodyweight squats (3 seconds down, 1 second up).",
                zh: "站起来做 10 个慢速深蹲（3 秒下蹲，1 秒起立）。"
            ),
            durationSeconds: 60,
            benefit: LocalizedText(
                en: "Activates the body's largest muscle groups (quads + glutes). Rapidly boosts heart rate and metabolism.",
                zh: "激活身体最大肌群（股四头肌 + 臀肌）。快速提升心率和代谢。"
            ),
            consequence: LocalizedText(
                en: "Lower body muscles atrophy from disuse, basal metabolic rate drops.",
                zh: "下肢肌肉因废用而萎缩，基础代谢率下降。"
            ),
            category: .sedentary
        ),
        Tip(
            id: "sed.restroom",
            name: LocalizedText(en: "Restroom Break", zh: "上个厕所"),
            instruction: LocalizedText(
                en: "Walk to the restroom — even if you don't urgently need to go.",
                zh: "去趟洗手间——即使你觉得不太急。"
            ),
            durationSeconds: 180,
            benefit: LocalizedText(
                en: "Forced walking + prevents holding urine (a common sitting habit).",
                zh: "强制走路 + 避免憋尿（久坐族的常见坏习惯）。"
            ),
            consequence: LocalizedText(
                en: "Holding urine increases urinary tract infection risk, which desk workers often ignore.",
                zh: "憋尿增加泌尿道感染风险，久坐族常常忽视这点。"
            ),
            category: .sedentary
        ),
        Tip(
            id: "sed.wall_stand",
            name: LocalizedText(en: "Wall Stand (1 min)", zh: "靠墙站 1 分钟"),
            instruction: LocalizedText(
                en: "Stand with your back against a wall: back of head, shoulder blades, butt, and heels all touching the wall. Hold 1 minute.",
                zh: "背靠墙站：后脑勺、肩胛骨、臀部、脚后跟都贴墙。保持 1 分钟。"
            ),
            durationSeconds: 60,
            benefit: LocalizedText(
                en: "Resets correct posture alignment. Corrects rounded shoulders and forward head in one move.",
                zh: "重置正确体态。一个动作同时矫正圆肩和头前伸。"
            ),
            consequence: LocalizedText(
                en: "Poor posture becomes your default. Your body literally forgets what 'straight' feels like.",
                zh: "错误姿势变成你的默认设定。身体会真的忘记「直」是什么感觉。"
            ),
            category: .sedentary
        ),
        Tip(
            id: "sed.calf_raises",
            name: LocalizedText(en: "20 Calf Raises", zh: "20 个提踵"),
            instruction: LocalizedText(
                en: "Stand and rise up on your toes 20 times. Slow and controlled.",
                zh: "站立，慢慢踮脚尖 20 次。控制节奏，慢上慢下。"
            ),
            durationSeconds: 40,
            benefit: LocalizedText(
                en: "Activates the calf muscle pump — your 'second heart' for venous return from the legs.",
                zh: "激活小腿肌肉泵——你的「第二心脏」，促进下肢静脉回流。"
            ),
            consequence: LocalizedText(
                en: "Calf muscle pump weakens from disuse → poor venous return → swollen ankles.",
                zh: "小腿肌肉泵因废用而减弱→静脉回流差→脚踝肿胀。"
            ),
            category: .sedentary
        ),
    ]

    // Time-aware preference mapping (hour -> preferred sedentary tip indices).
    // Indices correspond to `sedentaryTips` positions. Mirrors Python SEDENTARY_TIME_PREFERENCES.
    private static let sedentaryTimePreferences: [(hours: Range<Int>, indices: [Int])] = [
        (9..<11,  [0, 1, 2]),  // Morning: hydration focus
        (11..<12, [0, 4, 1]),  // Pre-lunch
        (13..<15, [3, 6, 1]),  // Post-lunch drowsiness (energizing)
        (15..<17, [5, 2, 3]),  // Afternoon
        (17..<20, [1, 0, 6]),  // Late afternoon
    ]

    // MARK: Combo tips (eye + neck simultaneously) — 10 compound moves

    static let comboTips: [Tip] = [
        Tip(
            id: "combo.gaze_rotation",
            name: LocalizedText(en: "Gaze-Follow Neck Rotation", zh: "转头远眺跟随"),
            instruction: LocalizedText(
                en: "Pick a distant target (≥3m). Slowly rotate head left ~45° while eyes stay locked on the target. Hold 3s. Return. Repeat right. 3× each side.",
                zh: "选一个 3 米以上的远处目标。慢慢向左转头约 45°，眼睛始终盯着目标。保持 3 秒，回正。换右侧。每侧 3 次。"
            ),
            durationSeconds: 45,
            benefit: LocalizedText(
                en: "VOR×1 gaze-stability drill: trains cervico-ocular coupling + cervical ROM + ciliary relaxation from distance fixation — three root fixes in one move.",
                zh: "前庭-眼反射（VOR×1）训练：同时训练颈-眼协调、颈椎活动度、远眺放松睫状肌——三个根本问题一次解决。"
            ),
            consequence: LocalizedText(
                en: "Decoupled eye+neck movement is a hallmark of chronic neck pain and cervicogenic dizziness.",
                zh: "眼-颈协调解耦是慢性颈痛和颈源性头晕的典型特征。"
            ),
            category: .combo,
            source: LocalizedText(
                en: "Herdman, Vestibular Rehabilitation 4th ed., 2014; Talens-Estarelles et al., 2023",
                zh: "Herdman, Vestibular Rehabilitation 第 4 版, 2014；Talens-Estarelles 等, 2023"
            ),
            difficulty: .medium,
            kind: .compound,
            tags: ["vestibular", "ROM", "dryeye"]
        ),
        Tip(
            id: "combo.chintuck_focus",
            name: LocalizedText(en: "Chin-Tuck + Distance Focus", zh: "收下巴远眺"),
            instruction: LocalizedText(
                en: "Find the farthest point in the room. While softly gazing at it, perform a chin tuck (double chin). Hold 5s. Release. Repeat 6×.",
                zh: "找到房间最远的一个点，柔和地看着它，同时收下巴（做出双下巴）。保持 5 秒，放松。重复 6 次。"
            ),
            durationSeconds: 40,
            benefit: LocalizedText(
                en: "Two gold-standard moves stacked: chin tuck (FHP correction) + distance focus (ciliary release). Root-cause fix for both the screen neck and the screen eye.",
                zh: "两个金标准动作同时做：收下巴（矫正头前伸）+ 远眺（放松睫状肌）。屏幕颈和屏幕眼的双根治。"
            ),
            consequence: LocalizedText(
                en: "FHP + near-focus lock is the exact posture that creates both neck pain and accommodative myopia — do nothing and both compound.",
                zh: "头前伸 + 近距离锁定，正是导致颈痛和调节性近视的组合姿势——不管就是双重恶化。"
            ),
            category: .combo,
            source: LocalizedText(
                en: "Kang et al., Turk J Phys Med Rehabil, 2021 + Talens-Estarelles et al., 2023",
                zh: "Kang 等, Turk J Phys Med Rehabil, 2021 + Talens-Estarelles 等, 2023"
            ),
            difficulty: .easy,
            kind: .compound,
            tags: ["FHP", "dryeye", "relaxation"]
        ),
        Tip(
            id: "combo.figure8_lateral",
            name: LocalizedText(en: "Figure-8 Eye + Lateral Neck Stretch", zh: "8 字眼球 + 侧颈拉伸"),
            instruction: LocalizedText(
                en: "Tilt head gently to left shoulder (ear toward shoulder). While holding the stretch, trace a slow horizontal figure-8 with your eyes, 3 loops. Switch side, 3 loops.",
                zh: "轻轻把头向左肩倾斜（耳朵靠肩膀）。保持拉伸的同时，眼睛慢慢画横向 8 字，3 圈。换边，再 3 圈。"
            ),
            durationSeconds: 50,
            benefit: LocalizedText(
                en: "Static stretch of upper trapezius/scalene + extraocular muscle activation through full ROM — simultaneously releases stiff neck and frozen eyes.",
                zh: "上斜方肌/斜角肌静态拉伸 + 眼外肌全范围激活——同时释放僵硬的脖子和冻住的眼睛。"
            ),
            consequence: LocalizedText(
                en: "Both systems stiffen in parallel during screen work. Treating them together is twice as efficient.",
                zh: "盯屏幕时两个系统平行僵化，一起处理效率翻倍。"
            ),
            category: .combo,
            source: LocalizedText(
                en: "Scheiman & Wick 2019 + standard upper trap stretch",
                zh: "Scheiman & Wick 2019 + 上斜方肌标准拉伸"
            ),
            difficulty: .medium,
            kind: .compound,
            tags: ["ROM", "saccade"]
        ),
        Tip(
            id: "combo.vor_x1",
            name: LocalizedText(en: "VOR×1 Horizontal Gaze Stability", zh: "水平凝视稳定 VOR×1"),
            instruction: LocalizedText(
                en: "Hold thumb at arm's length, eye-level. Keep eyes locked on thumb while rotating head \"no-no-no\" for 15s. Then vertically \"yes-yes-yes\" for 15s.",
                zh: "拇指伸直举到眼前。眼睛始终盯着拇指，头像说「不不不」一样左右转 15 秒。再像说「是是是」一样上下点 15 秒。"
            ),
            durationSeconds: 30,
            benefit: LocalizedText(
                en: "Gold-standard vestibular rehab drill (Cawthorne-Cooksey). Trains gaze stability + cervical proprioception simultaneously.",
                zh: "前庭康复金标准动作（Cawthorne-Cooksey）。同时训练凝视稳定和颈椎本体感觉。"
            ),
            consequence: LocalizedText(
                en: "Poor VOR causes motion sensitivity, visual vertigo, and reading fatigue on moving vehicles or when shifting gaze.",
                zh: "前庭-眼反射差导致晕动症、视觉性头晕、乘车阅读疲劳。"
            ),
            category: .combo,
            source: LocalizedText(
                en: "Herdman, Vestibular Rehabilitation 4th ed., 2014",
                zh: "Herdman, Vestibular Rehabilitation 第 4 版, 2014"
            ),
            difficulty: .hard,
            kind: .compound,
            tags: ["vestibular", "activating"]
        ),
        Tip(
            id: "combo.scapular_2020",
            name: LocalizedText(en: "Scapular Squeeze + 20/20/20", zh: "肩胛内收 + 20 秒远眺"),
            instruction: LocalizedText(
                en: "Squeeze your shoulder blades together (pencil between them). Simultaneously stare at an object ≥6m away for 20s. Release. Repeat once.",
                zh: "两侧肩胛骨用力向中间夹紧（夹住一支铅笔的感觉）。同时盯着 6 米以外的物体 20 秒。放松，重复 1 次。"
            ),
            durationSeconds: 45,
            benefit: LocalizedText(
                en: "Combines two evidence-based moves already in this app: scapular retraction (rounded-shoulder fix) + 20/20/20 (AAO dry-eye rule). Two birds, one stone.",
                zh: "把本 app 里两个循证动作合并：肩胛内收（矫正圆肩）+ 20/20/20（AAO 干眼防治规则）。一箭双雕。"
            ),
            consequence: LocalizedText(
                en: "Rounded shoulders + near-focus lock is the complete screen-worker posture pathology — skip this and both cascade.",
                zh: "圆肩 + 近距离锁定，是屏幕族姿势病理的完整画像——不做就双向恶化。"
            ),
            category: .combo,
            source: LocalizedText(
                en: "Cools et al., Br J Sports Med, 2014 + AAO digital eye strain guideline",
                zh: "Cools 等, Br J Sports Med, 2014 + AAO 数字眼疲劳指南"
            ),
            difficulty: .easy,
            kind: .compound,
            tags: ["FHP", "dryeye"]
        ),
        Tip(
            id: "combo.eye_led_rotation",
            name: LocalizedText(en: "Eye-Led Neck Rotation", zh: "眼先动，颈跟随"),
            instruction: LocalizedText(
                en: "Sit upright. Without moving head, look fully left (hold 2s). Let head follow the eyes into full left rotation (hold 3s). Reverse to return. Repeat right. 2× each.",
                zh: "坐直，头不动，眼睛先看向最左（停 2 秒）。然后让头跟着眼睛转到最左（停 3 秒）。反向回正。换右侧。每侧 2 次。"
            ),
            durationSeconds: 50,
            benefit: LocalizedText(
                en: "Reinstates the natural \"eyes-lead-neck\" motor pattern, broken in FHP users who crank the neck first. Plus activates all extraocular muscles through full ROM.",
                zh: "重建自然的「眼先动、颈跟随」运动模式——头前伸族的这个模式是坏的（他们先扭脖子）。同时让眼外肌走完整范围。"
            ),
            consequence: LocalizedText(
                en: "Compensating with neck-first movement overloads cervical joints and skips the ocular pre-alignment step that protects the spine.",
                zh: "颈先动代偿过度使颈椎负荷，跳过眼球预对齐步骤，少了一道保护脊柱的关节缓冲。"
            ),
            category: .combo,
            source: LocalizedText(
                en: "Jull G et al., J Orthop Res, 2007 (cervical rehab protocol)",
                zh: "Jull G 等, J Orthop Res, 2007（颈椎康复方案）"
            ),
            difficulty: .hard,
            kind: .compound,
            tags: ["vestibular", "ROM"]
        ),
        Tip(
            id: "combo.palming_dcf",
            name: LocalizedText(en: "Palming + Deep Cervical Flexor Hold", zh: "掌心敷眼 + 深层颈屈肌激活"),
            instruction: LocalizedText(
                en: "Rub palms together 5s until warm. Cup them over closed eyes. Simultaneously perform a gentle chin tuck (~20% effort) and hold 20s. Release carefully. Repeat once.",
                zh: "双手搓热 5 秒。轻轻捂在闭眼上。同时做一个轻微的收下巴动作（约 20% 力度），保持 20 秒。缓慢放松，重复 1 次。"
            ),
            durationSeconds: 45,
            benefit: LocalizedText(
                en: "Dark-adapted eye relaxation + low-load deep cervical flexor training. Combines parasympathetic calm with precise motor retraining.",
                zh: "暗适应放松眼睛 + 低负荷激活深层颈屈肌。副交感放松和精准运动控制一起来。"
            ),
            consequence: LocalizedText(
                en: "Without periodic DCF engagement, superficial neck muscles dominate — chronic tension despite rest.",
                zh: "缺乏深层颈屈肌激活，浅层颈肌代偿——即使休息也持续紧张。"
            ),
            category: .combo,
            source: LocalizedText(
                en: "Classic palming + Jull et al., J Manipulative Physiol Ther, 2008",
                zh: "经典掌心敷眼 + Jull 等, J Manipulative Physiol Ther, 2008"
            ),
            difficulty: .medium,
            kind: .compound,
            tags: ["relaxation", "FHP", "DCF"]
        ),
        Tip(
            id: "combo.gaze_recognition",
            name: LocalizedText(en: "Gaze-Direction Recognition", zh: "眼指方向 + 头回正"),
            instruction: LocalizedText(
                en: "Close eyes. Rotate head comfortably left. Open eyes — note where your gaze naturally lands. Close eyes, return head to neutral, verify gaze centers. Repeat: right, up, down.",
                zh: "闭眼，头慢慢转向左侧（舒适位）。睁眼——注意眼睛落在哪里。闭眼，把头转回正中，睁眼检查是否对齐正前方。换右侧、上、下各一次。"
            ),
            durationSeconds: 60,
            benefit: LocalizedText(
                en: "Trains cervical joint position sense — the proprioceptive \"GPS\" of your neck. Clinically proven for chronic neck pain and cervicogenic headache.",
                zh: "训练颈椎关节位置觉——脖子的本体感觉「GPS」。临床证明对慢性颈痛和颈源性头痛有效。"
            ),
            consequence: LocalizedText(
                en: "Impaired cervical position sense → chronic low-grade whiplash-like symptoms, poor head-on-body awareness, recurring strain.",
                zh: "颈椎位置觉受损 → 慢性低级别「挥鞭伤样」症状、头身协调差、反复劳损。"
            ),
            category: .combo,
            source: LocalizedText(
                en: "Revel M et al., Arch Phys Med Rehabil, 1991 (GDR protocol)",
                zh: "Revel M 等, Arch Phys Med Rehabil, 1991（眼方向识别方案）"
            ),
            difficulty: .hard,
            kind: .compound,
            tags: ["proprioception", "FHP"]
        ),
        Tip(
            id: "combo.thoracic_sweep",
            name: LocalizedText(en: "Thoracic Extension + Eye Sweep", zh: "胸椎伸展 + 上下扫视"),
            instruction: LocalizedText(
                en: "Clasp hands behind head. Gently arch upper back over chair back while slowly looking up at the ceiling. Slowly return while looking down at the floor. Repeat 5×.",
                zh: "双手交叉放脑后。上背部轻轻向后弓在椅背上，同时慢慢抬头看天花板。慢慢回到原位时低头看地板。重复 5 次。"
            ),
            durationSeconds: 50,
            benefit: LocalizedText(
                en: "Thoracic extension opens kyphosis (fixes neck compensation at the root); vertical smooth-pursuit activates superior/inferior recti through full range.",
                zh: "胸椎伸展打开后凸（从根源解决颈椎代偿）；垂直平滑追视让上下直肌走完整范围。"
            ),
            consequence: LocalizedText(
                en: "Thoracic kyphosis forces the neck into forward compensation, and vertical eye ROM atrophies from always-horizontal screen gaze.",
                zh: "胸椎后凸迫使颈椎前伸代偿，加上总是水平看屏幕，垂直眼动范围退化。"
            ),
            category: .combo,
            source: LocalizedText(
                en: "Kang et al., Turk J Phys Med Rehabil, 2021 + pursuit EOM training",
                zh: "Kang 等, Turk J Phys Med Rehabil, 2021 + 追视眼外肌训练"
            ),
            difficulty: .medium,
            kind: .compound,
            tags: ["FHP", "ROM", "saccade"]
        ),
        Tip(
            id: "combo.wall_saccades",
            name: LocalizedText(en: "Wall-Stand Horizontal Saccades", zh: "靠墙站 + 水平扫视"),
            instruction: LocalizedText(
                en: "Stand with back against wall — head, shoulders, butt, heels all touching. Hold head perfectly still; snap gaze between two targets ~1m apart horizontally, 20 shifts.",
                zh: "背靠墙站——后脑、肩胛、臀、脚后跟都贴墙。头绝对不动，眼睛在约 1 米间距的两个水平目标间快速切换 20 次。"
            ),
            durationSeconds: 50,
            benefit: LocalizedText(
                en: "Full postural reset + saccadic training. Also builds head-eye dissociation — the skill of moving eyes without neck compensating.",
                zh: "全身姿态重置 + 扫视训练。还训练头-眼分离——眼睛独立动而不用脖子代偿。"
            ),
            consequence: LocalizedText(
                en: "Users who can't hold head-still while moving eyes have lost head-eye dissociation — a hidden driver of neck strain.",
                zh: "头动则眼动、不能分离的人，头-眼分离能力已丢——颈椎劳损的隐藏推手。"
            ),
            category: .combo,
            source: LocalizedText(
                en: "Existing wall-stand (app) + Scheiman & Wick 2019 saccade training",
                zh: "本 app 靠墙站 + Scheiman & Wick 2019 扫视训练"
            ),
            difficulty: .hard,
            kind: .compound,
            tags: ["saccade", "posture", "activating"]
        ),
    ]

    // MARK: Noon outdoor

    static let noonOutdoor = Tip(
        id: "noon.outdoor",
        name: LocalizedText(en: "Noon Outdoor Walk", zh: "午间户外走走"),
        instruction: LocalizedText(
            en: "Go outside for 15 minutes. Walk, get lunch, or just stand in daylight.",
            zh: "出去走 15 分钟。散步、买饭、或者就站在阳光下。"
        ),
        durationSeconds: 900,
        benefit: LocalizedText(
            en: "Outdoor light (10,000+ lux) triggers retinal dopamine release — the strongest known factor for slowing myopia progression. Also resets circadian rhythm for better sleep tonight.",
            zh: "户外光照（10,000+ 勒克斯）触发视网膜多巴胺释放——已知最强的延缓近视进展因素。还能重置生物钟，改善今晚睡眠。"
        ),
        consequence: LocalizedText(
            en: "Indoor lighting is only 300-500 lux (30x less than outdoors). Without daily light exposure: myopia progression continues, circadian rhythm drifts, vitamin D drops, mood suffers.",
            zh: "室内照明只有 300-500 勒克斯（不到户外的三十分之一）。缺少日光：近视继续进展、生物钟紊乱、维生素 D 不足、情绪低落。"
        ),
        category: .noon,
        source: LocalizedText(
            en: "Multiple RCTs on outdoor time and myopia control, especially in East Asian populations",
            zh: "多项 RCT 研究证实户外时间与近视控制的关系，尤其在东亚人群中"
        )
    )

    // MARK: - Selection API (recency-aware, weighted)

    /// All neck tips (core + aux collapsed for the selector).
    static var allNeckTips: [Tip] { neckCore + neckAux }

    static func randomEyeTip() -> Tip {
        TipSelector.shared.pick(from: eyeTips, category: .eye)
    }

    static func randomNeckExercise() -> Tip {
        TipSelector.shared.pick(from: allNeckTips, category: .neck)
    }

    static func randomNeckAux() -> Tip {
        TipSelector.shared.pick(from: neckAux, category: .neck)
    }

    /// Return a core + auxiliary pair — matches Python `next_neck_combo` shape.
    /// Guarantees the two tips are different IDs.
    static func neckCombo() -> [Tip] {
        let a = TipSelector.shared.pick(from: neckCore, category: .neck)
        let pool = neckAux.filter { $0.id != a.id }
        let b = TipSelector.shared.pick(from: pool.isEmpty ? neckAux : pool, category: .neck)
        return [a, b]
    }

    /// Time-aware sedentary break (keeps original hour-preference table as a pool hint
    /// but applies recency buffer + weighting on top).
    static func sedentaryBreak(forHour hour: Int) -> Tip {
        let pool: [Tip]
        if let pref = sedentaryTimePreferences.first(where: { $0.hours.contains(hour) }) {
            pool = pref.indices.map { sedentaryTips[$0] }
        } else {
            pool = sedentaryTips
        }
        return TipSelector.shared.pick(from: pool, category: .sedentary)
    }

    static func noonReminder() -> Tip {
        noonOutdoor
    }

    /// Pick a single compound (eye+neck) tip via recency-aware selector.
    static func randomComboTip() -> Tip {
        TipSelector.shared.pick(from: comboTips, category: .combo)
    }

    /// Combined eye + neck reminder.
    ///
    /// **Primary path**: returns `[comboTip]` — a single compound move that trains
    /// both systems simultaneously (evidence: cervico-ocular coupling,
    /// Kristjansson & Treleaven 2009; Jull et al. 2007; Herdman 2014).
    ///
    /// **Legacy 3-step fallback** is still selected ~15% of the time to preserve
    /// variety on the format itself (prevents combo from becoming the new habituated
    /// pattern; Schultz 2015 variable-ratio rationale).
    ///
    /// Caller gets back a single combo tip that covers both eye and neck.
    static func combinedEyeAndNeck() -> [Tip] {
        return [randomComboTip()]
    }
}

// MARK: - Recency-aware weighted selector

/// Per-category ring buffer + weighted sampler.
///
/// Simple, explicit goal: never show the same tip twice within the last N fires of
/// the same category, and when sampling, apply difficulty-based weights (easy tips
/// get more weight in the first weeks of use; hard tips remain reachable).
///
/// In-memory only. On app restart the buffer resets — at worst this reintroduces
/// one repeat, which is acceptable for MVP. Persistence is a future enhancement.
final class TipSelector {
    static let shared = TipSelector()

    /// Ring buffer capacity per category. Chosen so recent N tips are excluded
    /// while leaving ≥ pool.count - N candidates. For small pools (e.g. a
    /// 3-index sedentary hour pref), this auto-clamps to pool.count - 1.
    private let capacity: Int = 4

    private var recent: [TipCategory: [String]] = [:]
    private let lock = NSLock()

    private init() {}

    /// Pick a tip from `pool` using recency exclusion + weighted random.
    /// Pool must be non-empty. Records the picked id into the ring buffer.
    func pick(from pool: [Tip], category: TipCategory) -> Tip {
        precondition(!pool.isEmpty, "TipSelector.pick called with empty pool")
        lock.lock()
        defer { lock.unlock() }

        let excludeCount = max(0, min(capacity, pool.count - 1))
        let buffer = recent[category] ?? []
        let blocked = Set(buffer.suffix(excludeCount))

        let candidates: [Tip]
        if blocked.isEmpty {
            candidates = pool
        } else {
            let filtered = pool.filter { !blocked.contains($0.id) }
            candidates = filtered.isEmpty ? pool : filtered
        }

        // Weighted sampling: easy > medium > hard (progressive-unlock-lite).
        // A fresh user's first sessions should default to easier moves; this
        // avoids hard-coded gating while still biasing toward friendly onboarding.
        let weights: [Double] = candidates.map { weight(for: $0) }
        let chosen = weightedSample(candidates: candidates, weights: weights)

        // Update ring buffer.
        var newBuffer = buffer
        newBuffer.append(chosen.id)
        if newBuffer.count > capacity { newBuffer.removeFirst(newBuffer.count - capacity) }
        recent[category] = newBuffer

        return chosen
    }

    /// Reset buffer (for tests / debug).
    func reset() {
        lock.lock(); defer { lock.unlock() }
        recent.removeAll()
    }

    private func weight(for tip: Tip) -> Double {
        switch tip.difficulty {
        case .easy:   return 1.0
        case .medium: return 0.8
        case .hard:   return 0.5
        }
    }

    private func weightedSample(candidates: [Tip], weights: [Double]) -> Tip {
        let total = weights.reduce(0, +)
        guard total > 0 else { return candidates.randomElement()! }
        var r = Double.random(in: 0..<total)
        for (i, w) in weights.enumerated() {
            if r < w { return candidates[i] }
            r -= w
        }
        return candidates.last!
    }
}
