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
    case sedentary
    case noon
}

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

    init(
        id: String,
        name: LocalizedText,
        instruction: LocalizedText,
        durationSeconds: Int,
        benefit: LocalizedText,
        consequence: LocalizedText,
        category: TipCategory,
        source: LocalizedText? = nil
    ) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.durationSeconds = durationSeconds
        self.benefit = benefit
        self.consequence = consequence
        self.category = category
        self.source = source
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
    ]

    // MARK: Eye extra rotating messages

    static let eyeExtraBenefits: [LocalizedText] = [
        LocalizedText(
            en: "20 seconds for 2 hours of clear vision — best ROI of your day.",
            zh: "20 秒换 2 小时清晰视力——今天性价比最高的事。"
        ),
        LocalizedText(
            en: "Your brain enters Default Mode Network when eyes close — creativity boost.",
            zh: "闭眼时大脑进入默认模式网络——创造力提升。"
        ),
        LocalizedText(
            en: "You also get 3 deep breaths — instant blood oxygen boost.",
            zh: "顺便做 3 次深呼吸——血氧瞬间提升。"
        ),
        LocalizedText(
            en: "Your eyes endure 12 hours of near-focus daily. They deserve this.",
            zh: "你的眼睛每天承受 12 小时近距离工作，它值得休息。"
        ),
        LocalizedText(
            en: "Consistent breaks reduce DES symptoms (p≤0.045, Valencia University 2023).",
            zh: "坚持休息可减轻数码眼疲劳症状（p≤0.045，瓦伦西亚大学 2023）。"
        ),
        LocalizedText(
            en: "High myopia + continuous near work = axial elongation risk. Break the cycle.",
            zh: "高度近视 + 持续近距离用眼 = 眼轴增长风险。打断这个循环。"
        ),
        LocalizedText(
            en: "This 20-second pause prevents the 3 PM headache-blurry-vision crash.",
            zh: "这 20 秒能预防下午 3 点的头痛-模糊-注意力崩溃。"
        ),
    ]

    static let eyeExtraConsequences: [LocalizedText] = [
        LocalizedText(
            en: "Skipping breaks → near-work-induced transient myopia (NITM) builds up.",
            zh: "不休息→近距离工作诱发的暂时性近视（NITM）累积。"
        ),
        LocalizedText(
            en: "By 3 PM: sore eyes, headache, focus gone. Productivity cliff incoming.",
            zh: "到下午 3 点：眼酸、头痛、注意力归零。生产力断崖。"
        ),
        LocalizedText(
            en: "High myopia: every skipped break adds to axial elongation stimulus.",
            zh: "高度近视：每次跳过休息都在给眼轴增长加油。"
        ),
        LocalizedText(
            en: "92% of screen users report at least 1 DES symptom. Don't add to the stat.",
            zh: "92% 的屏幕用户至少有 1 个数码眼疲劳症状。别再加一个。"
        ),
        LocalizedText(
            en: "Tear film breaks down without blinking — dry cornea → micro-abrasions.",
            zh: "不眨眼泪膜就会破裂——角膜干燥→微损伤。"
        ),
        LocalizedText(
            en: "Accommodative spasm now = needing stronger glasses later.",
            zh: "现在的调节痉挛 = 以后需要更厚的镜片。"
        ),
        LocalizedText(
            en: "No breaks for 4 hours straight → 30% decline in accommodative function.",
            zh: "连续 4 小时不休息→调节功能下降 30%。"
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

    static let noonExtraMessages: [LocalizedText] = [
        LocalizedText(
            en: "Even on a cloudy day, outdoor light is 5,000-10,000 lux. Your office? ~400 lux.",
            zh: "即使阴天，户外光照也有 5,000-10,000 勒克斯。你的办公室？大约 400。"
        ),
        LocalizedText(
            en: "This is the single most impactful thing you can do for your eyes today.",
            zh: "这是你今天能为眼睛做的最有价值的事。"
        ),
        LocalizedText(
            en: "15 minutes of daylight also boosts serotonin. You'll code better after this.",
            zh: "15 分钟日光还能提升血清素。回来写代码更高效。"
        ),
        LocalizedText(
            en: "Your retina needs real sunlight — no artificial light can fully substitute.",
            zh: "你的视网膜需要真正的阳光——人造光源无法完全替代。"
        ),
        LocalizedText(
            en: "Outdoor time is the #1 evidence-based intervention for myopia control.",
            zh: "户外时间是循证医学中排名第一的近视控制干预手段。"
        ),
    ]

    // MARK: - Selection API

    static func randomEyeTip() -> Tip {
        eyeTips.randomElement()!
    }

    static func randomNeckExercise() -> Tip {
        neckCore.randomElement()!
    }

    static func randomNeckAux() -> Tip {
        neckAux.randomElement()!
    }

    /// Return a core + auxiliary pair — matches Python `next_neck_combo` shape.
    static func neckCombo() -> [Tip] {
        [randomNeckExercise(), randomNeckAux()]
    }

    /// Time-aware sedentary break. If `forHour` matches a preference window, pick
    /// from that window; otherwise pick uniformly at random.
    static func sedentaryBreak(forHour hour: Int) -> Tip {
        if let pref = sedentaryTimePreferences.first(where: { $0.hours.contains(hour) }) {
            let idx = pref.indices.randomElement() ?? 0
            return sedentaryTips[idx]
        }
        return sedentaryTips.randomElement()!
    }

    static func noonReminder() -> Tip {
        noonOutdoor
    }

    /// Combined eye + neck reminder — returns an eye tip plus a neck core/aux pair.
    /// The floating window steps through these as a single multi-step session.
    static func combinedEyeAndNeck() -> [Tip] {
        [randomEyeTip()] + neckCombo()
    }

    static func randomEyeExtraBenefit() -> LocalizedText {
        eyeExtraBenefits.randomElement()!
    }

    static func randomEyeExtraConsequence() -> LocalizedText {
        eyeExtraConsequences.randomElement()!
    }

    static func randomNoonExtraMessage() -> LocalizedText {
        noonExtraMessages.randomElement()!
    }
}
