"""
Content library for CodeBreath.
All health tips, exercises, and messages with scientific backing.
Each entry includes: what to do, why it helps, and what happens if you don't.
"""

import random
from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class Tip:
    """A single health tip with benefit/consequence messaging."""

    name: str
    instruction: str
    duration_seconds: int
    benefit: str
    consequence: str
    ascii_art: str = ""
    source: str = ""


# ---------------------------------------------------------------------------
# Eye care: 5 rotating methods
# ---------------------------------------------------------------------------

EYE_TIPS: List[Tip] = [
    Tip(
        name="Close Eyes & Breathe",
        instruction="Close your eyes for 20 seconds. Take 3 slow deep breaths.",
        duration_seconds=20,
        benefit="Ciliary muscle fully relaxes (accommodation = 0). Even better than looking far away. Deep breathing also lowers shoulder tension.",
        consequence="Ciliary muscle stays contracted — you'll get blurry distance vision after work. Chronic spasm accelerates myopia progression.",
        ascii_art=r"""
    Before          After
   (o  o)         (—  —)
    \  /           \  /
     ||             ||
  stressed      relaxed
        """,
        source="Optical physiology: closing eyes = 0 accommodation demand",
    ),
    Tip(
        name="Palming",
        instruction="Rub your palms together for 5 seconds until warm, then gently cup them over your closed eyes for 20 seconds.",
        duration_seconds=25,
        benefit="Complete darkness + warmth improves periorbital blood flow and relieves dry eyes.",
        consequence="Poor microcirculation around the eyes worsens dryness and dark circles.",
        ascii_art=r"""
     _____
    / o o \      Rub palms...
    \_____/      then cup eyes
                 
    /‾‾‾‾‾\
    |  ——  |     Warm darkness
    \_____/      = deep rest
        """,
        source="Traditional eye care technique validated by optometry practice",
    ),
    Tip(
        name="Distance Focus",
        instruction="Look at the farthest point in the room (wall, corner, ceiling) for 20 seconds.",
        duration_seconds=20,
        benefit="Ciliary muscle releases from near-focus tension. Even 3-4 meters achieves 85%+ of the relaxation effect of 6 meters.",
        consequence="Accommodative facility declines — switching focus between near and far gets slower over time (measured decline p=0.010).",
        ascii_art=r"""
    Screen 50cm     Wall 3-4m
    ┌──────┐
    │ code │  -->    . (far point)
    │ code │
    └──────┘
    0.33D demand    ~0D demand
        """,
        source="Talens-Estarelles et al., Contact Lens & Anterior Eye, 2023",
    ),
    Tip(
        name="Blink Exercise",
        instruction="Blink rapidly 20 times, then close your eyes gently for 10 seconds.",
        duration_seconds=15,
        benefit="Screen staring reduces blink rate by 66%. Active blinking rebuilds the tear film and moistens the cornea.",
        consequence="Tear film breaks down, corneal surface dries out — burning, itching, and blurred vision.",
        ascii_art=r"""
    Normal:  15-20 blinks/min
    Screen:   5-7  blinks/min  (↓66%)

    (o o)  →  (- -)  →  (o o)
     blink     blink     blink
      x20 rapid + 10s rest
        """,
        source="AAO recommendation + dry eye research",
    ),
    Tip(
        name="Eye Rolls",
        instruction="Close your eyes. Slowly roll eyeballs: up → right → down → left, 3 circles. Then reverse, 3 circles.",
        duration_seconds=20,
        benefit="Relaxes all 6 extraocular muscles that stay locked during screen fixation. Improves eye movement flexibility.",
        consequence="Extraocular muscles stiffen from prolonged fixed gaze, reducing eye movement range.",
        ascii_art=r"""
          ↑
        ╱   ╲
      ←   •   →    3x clockwise
        ╲   ╱      3x counter
          ↓
        """,
        source="Optometric exercise for extraocular muscle relaxation",
    ),
]

# Rotating sub-messages for eye tips (to avoid repetition)
EYE_EXTRA_BENEFITS = [
    "20 seconds for 2 hours of clear vision — best ROI of your day.",
    "Your brain enters Default Mode Network when eyes close — creativity boost.",
    "You also get 3 deep breaths — instant blood oxygen boost.",
    "Your eyes endure 12 hours of near-focus daily. They deserve this.",
    "Consistent breaks reduce DES symptoms (p≤0.045, Valencia University 2023).",
    "High myopia + continuous near work = axial elongation risk. Break the cycle.",
    "This 20-second pause prevents the 3 PM headache-blurry-vision crash.",
]

EYE_EXTRA_CONSEQUENCES = [
    "Skipping breaks → near-work-induced transient myopia (NITM) builds up.",
    "By 3 PM: sore eyes, headache, focus gone. Productivity cliff incoming.",
    "High myopia: every skipped break adds to axial elongation stimulus.",
    "92% of screen users report at least 1 DES symptom. Don't add to the stat.",
    "Tear film breaks down without blinking — dry cornea → micro-abrasions.",
    "Accommodative spasm now = needing stronger glasses later.",
    "No breaks for 4 hours straight → 30% decline in accommodative function.",
]

# ---------------------------------------------------------------------------
# Neck exercises: 6 moves, categorized as core vs auxiliary
# ---------------------------------------------------------------------------

NECK_CORE: List[Tip] = [
    Tip(
        name="Chin Tuck",
        instruction="Pull your chin straight back (make a double chin). Hold 5 seconds. Repeat 10 times.",
        duration_seconds=50,
        benefit="THE gold-standard move. Directly corrects Forward Head Posture, activates deep cervical flexors, and restores normal cervical curve.",
        consequence="Every inch your head moves forward adds ~4.5 kg of load on your cervical spine. At 60° forward tilt, your neck bears ~27 kg.",
        ascii_art=r"""
    WRONG         RIGHT
      O  →          O
     /| forward    /|  chin tucked
      |             |
  +4.5kg/inch    neutral load
        """,
        source="Rehabilitation medicine gold standard for FHP correction",
    ),
    Tip(
        name="Thoracic Extension",
        instruction="Sit up straight, clasp hands behind your head. Gently arch your upper back over the chair backrest. Hold 10 seconds. Repeat 5 times.",
        duration_seconds=50,
        benefit="Opens the chest cavity, corrects rounded back (thoracic kyphosis), and addresses the ROOT CAUSE of neck compensation. Also improves breathing capacity.",
        consequence="Increased thoracic kyphosis forces the cervical spine to compensate by jutting forward — a vicious cycle.",
        ascii_art=r"""
    BEFORE         AFTER
      ╮              |
     ╭╯  rounded    ╱  extended
    ╱    back      ╱   open chest
   seated        arched over chair
        """,
        source="Kang et al., Turk J Phys Med Rehabil, 2021 (RCT)",
    ),
    Tip(
        name="Scapular Retraction",
        instruction="Squeeze your shoulder blades together as if holding a pencil between them. Hold 5 seconds. Repeat 10 times.",
        duration_seconds=50,
        benefit="Activates rhomboids and mid/lower trapezius, corrects rounded shoulders, and restores scapular stability.",
        consequence="Rounded shoulders worsen, scapular instability leads to cascading neck-shoulder problems.",
        ascii_art=r"""
    TOP VIEW
    
    ╭ ╮  shoulders   ╭ ╮  shoulders
    │→│  forward     │←│  retracted
    ╰ ╯  (bad)       ╰ ╯  (good)
    
    Squeeze like holding a pencil
        """,
        source="Kang 2021 + Cools et al., Br J Sports Med, 2014",
    ),
]

NECK_AUX: List[Tip] = [
    Tip(
        name="Lateral Neck Stretch",
        instruction="Slowly tilt your head toward the left shoulder (ear to shoulder). Hold 15 seconds. Switch to right side. Repeat once more each side.",
        duration_seconds=60,
        benefit="Releases upper trapezius and scalene muscles — the muscles that get rock-hard from screen work.",
        consequence="Chronic upper trapezius tension → tension-type headaches, the #1 headache type in office workers.",
        ascii_art=r"""
         O            O
        /|\\         //|
         |     →      |
     straight    tilted (ear→shoulder)
     hold 15s each side
        """,
        source="Basic stretching for upper trapezius relief",
    ),
    Tip(
        name="Neck Rotation",
        instruction="Slowly turn your head to look over your left shoulder. Hold 10 seconds. Turn to right. Repeat once more each side.",
        duration_seconds=40,
        benefit="Maintains cervical range of motion and prevents joint stiffness.",
        consequence="Joint mobility decreases over time, potentially leading to degenerative changes.",
        ascii_art=r"""
         O     →      O
        /|           /|
         |            |
      front     turned (look over shoulder)
      hold 10s each side
        """,
        source="Cervical ROM maintenance exercise",
    ),
    Tip(
        name="Shoulder Shrug & Release",
        instruction="Shrug both shoulders up to your ears hard (5 seconds), then drop them suddenly and completely relax. Repeat 5 times.",
        duration_seconds=50,
        benefit="Rapid tension release in upper trapezius — instant relief from shoulder-neck tightness.",
        consequence="Upper trapezius stays chronically overactivated, leading to trigger points and referred pain.",
        ascii_art=r"""
     ╱O╲   shrug UP     O    DROP & relax
    ╱ | ╲   (5 sec)    ╱|╲   (release!)
      |                 |
    tense!            ahhh...
      x5 times
        """,
        source="Muscle relaxation technique for trapezius",
    ),
]

# ---------------------------------------------------------------------------
# Sedentary break activities: 7 rotating options
# ---------------------------------------------------------------------------

SEDENTARY_TIPS: List[Tip] = [
    Tip(
        name="Get Water",
        instruction="Walk to the kitchen/water station and refill your water bottle.",
        duration_seconds=180,
        benefit="Walking + hydration in one trip. Adequate water intake also reduces dry eyes.",
        consequence="Dehydration worsens dry eyes AND cognitive performance. You're probably already dehydrated.",
    ),
    Tip(
        name="Hallway Walk (50 steps)",
        instruction="Leave your desk and walk at least 50 steps. Take the long route.",
        duration_seconds=180,
        benefit="Restores lower limb blood flow, reduces leg swelling from pooled blood.",
        consequence="Blood pools in lower limbs during sitting → DVT risk factor + afternoon leg heaviness.",
    ),
    Tip(
        name="Standing Stretch",
        instruction="Stand up. Reach both arms overhead and stretch your whole body upward for 10 seconds. Repeat 3 times.",
        duration_seconds=60,
        benefit="Decompresses the spine. Sitting puts 1.4x more pressure on lumbar discs than standing.",
        consequence="Lumbar discs under sustained compression → accelerated disc degeneration.",
    ),
    Tip(
        name="10 Bodyweight Squats",
        instruction="Stand up and do 10 slow bodyweight squats (3 seconds down, 1 second up).",
        duration_seconds=60,
        benefit="Activates the body's largest muscle groups (quads + glutes). Rapidly boosts heart rate and metabolism.",
        consequence="Lower body muscles atrophy from disuse, basal metabolic rate drops.",
    ),
    Tip(
        name="Restroom Break",
        instruction="Walk to the restroom — even if you don't urgently need to go.",
        duration_seconds=180,
        benefit="Forced walking + prevents holding urine (a common sitting habit).",
        consequence="Holding urine increases urinary tract infection risk, which desk workers often ignore.",
    ),
    Tip(
        name="Wall Stand (1 min)",
        instruction="Stand with your back against a wall: back of head, shoulder blades, butt, and heels all touching the wall. Hold 1 minute.",
        duration_seconds=60,
        benefit="Resets correct posture alignment. Corrects rounded shoulders and forward head in one move.",
        consequence="Poor posture becomes your default. Your body literally forgets what 'straight' feels like.",
    ),
    Tip(
        name="20 Calf Raises",
        instruction="Stand and rise up on your toes 20 times. Slow and controlled.",
        duration_seconds=40,
        benefit="Activates the calf muscle pump — your 'second heart' for venous return from the legs.",
        consequence="Calf muscle pump weakens from disuse → poor venous return → swollen ankles.",
    ),
]

# Time-aware preference mapping (hour -> preferred sedentary tip indices)
# Indices correspond to SEDENTARY_TIPS list positions
SEDENTARY_TIME_PREFERENCES = {
    # Morning: hydration focus
    range(9, 11): [0, 1, 2],  # Get water, Walk, Stretch
    # Pre-lunch
    range(11, 12): [0, 4, 1],  # Water, Restroom, Walk
    # Post-lunch drowsiness
    range(13, 15): [3, 6, 1],  # Squats, Calf raises, Walk (energizing)
    # Afternoon
    range(15, 17): [5, 2, 3],  # Wall stand, Stretch, Squats
    # Late afternoon
    range(17, 20): [1, 0, 6],  # Walk, Water, Calf raises
}

# ---------------------------------------------------------------------------
# Noon outdoor reminder
# ---------------------------------------------------------------------------

NOON_OUTDOOR = Tip(
    name="Noon Outdoor Walk",
    instruction="Go outside for 15 minutes. Walk, get lunch, or just stand in daylight.",
    duration_seconds=900,
    benefit="Outdoor light (10,000+ lux) triggers retinal dopamine release — the strongest known factor for slowing myopia progression. Also resets circadian rhythm for better sleep tonight.",
    consequence="Indoor lighting is only 300-500 lux (30x less than outdoors). Without daily light exposure: myopia progression continues, circadian rhythm drifts, vitamin D drops, mood suffers.",
    source="Multiple RCTs on outdoor time and myopia control, especially in East Asian populations",
)

NOON_EXTRA_MESSAGES = [
    "Even on a cloudy day, outdoor light is 5,000-10,000 lux. Your office? ~400 lux.",
    "This is the single most impactful thing you can do for your eyes today.",
    "15 minutes of daylight also boosts serotonin. You'll code better after this.",
    "Your retina needs real sunlight — no artificial light can fully substitute.",
    "Outdoor time is the #1 evidence-based intervention for myopia control.",
]


# ---------------------------------------------------------------------------
# Rotation engine
# ---------------------------------------------------------------------------


class ContentRotator:
    """Ensures variety by tracking what has been shown recently.

    Uses i18n module to resolve content for the current language.
    """

    def __init__(self):
        self._eye_history: List[int] = []
        self._neck_core_history: List[int] = []
        self._neck_aux_history: List[int] = []
        self._sedentary_history: List[int] = []
        self._eye_benefit_idx = 0
        self._eye_consequence_idx = 0
        self._noon_msg_idx = 0
        # Track which core neck exercises have been shown today
        self._neck_core_today: set = set()

    def next_eye_tip(self) -> tuple[Tip, str, str]:
        """Return next eye tip, ensuring no immediate repeat.
        Returns (tip, extra_benefit, extra_consequence)."""
        from .i18n import (
            get_eye_tips,
            get_eye_extra_benefits,
            get_eye_extra_consequences,
        )

        tips = get_eye_tips()
        idx = self._pick_no_repeat(len(tips), self._eye_history, max_history=2)
        self._eye_history.append(idx)

        extra_benefits = get_eye_extra_benefits()
        extra_consequences = get_eye_extra_consequences()
        extra_b = extra_benefits[self._eye_benefit_idx % len(extra_benefits)]
        extra_c = extra_consequences[
            self._eye_consequence_idx % len(extra_consequences)
        ]
        self._eye_benefit_idx += 1
        self._eye_consequence_idx += 1

        return tips[idx], extra_b, extra_c

    def next_neck_combo(self) -> List[Tip]:
        """Return 2-3 neck exercises: 1 core + 1-2 auxiliary.
        Ensures each core exercise appears at least once per day."""
        from .i18n import get_neck_core, get_neck_aux

        neck_core = get_neck_core()
        neck_aux = get_neck_aux()

        # Pick core: prefer ones not yet shown today
        unseen_core = [
            i for i in range(len(neck_core)) if i not in self._neck_core_today
        ]
        if unseen_core:
            core_idx = random.choice(unseen_core)
        else:
            core_idx = self._pick_no_repeat(
                len(neck_core), self._neck_core_history, max_history=1
            )
        self._neck_core_history.append(core_idx)
        self._neck_core_today.add(core_idx)

        # Pick 1 auxiliary
        aux_idx = self._pick_no_repeat(
            len(neck_aux), self._neck_aux_history, max_history=1
        )
        self._neck_aux_history.append(aux_idx)

        return [neck_core[core_idx], neck_aux[aux_idx]]

    def next_sedentary_tip(self, current_hour: int = 14) -> Tip:
        """Return next sedentary activity, with time-of-day awareness."""
        from .i18n import get_sedentary_tips

        sedentary_tips = get_sedentary_tips()

        preferred = None
        for hour_range, pref_indices in SEDENTARY_TIME_PREFERENCES.items():
            if current_hour in hour_range:
                # Filter out recently shown
                available = [
                    i for i in pref_indices if i not in self._sedentary_history[-2:]
                ]
                if available:
                    preferred = available
                break

        if preferred:
            idx = random.choice(preferred)
        else:
            idx = self._pick_no_repeat(
                len(sedentary_tips), self._sedentary_history, max_history=2
            )

        self._sedentary_history.append(idx)
        return sedentary_tips[idx]

    def next_noon_message(self) -> str:
        """Return rotating noon outdoor extra message."""
        from .i18n import get_noon_extra_messages

        messages = get_noon_extra_messages()
        msg = messages[self._noon_msg_idx % len(messages)]
        self._noon_msg_idx += 1
        return msg

    def get_noon_outdoor(self) -> Tip:
        """Return the noon outdoor tip in current language."""
        from .i18n import get_noon_outdoor

        return get_noon_outdoor()

    def reset_daily(self):
        """Reset daily tracking (call at start of each day)."""
        self._neck_core_today.clear()
        # Keep some history for continuity but trim
        self._eye_history = self._eye_history[-3:]
        self._neck_core_history = self._neck_core_history[-3:]
        self._neck_aux_history = self._neck_aux_history[-3:]
        self._sedentary_history = self._sedentary_history[-3:]

    @staticmethod
    def _pick_no_repeat(
        pool_size: int, history: List[int], max_history: int = 2
    ) -> int:
        """Pick a random index that wasn't in recent history."""
        recent = set(history[-max_history:]) if history else set()
        available = [i for i in range(pool_size) if i not in recent]
        if not available:
            available = list(range(pool_size))
        return random.choice(available)
