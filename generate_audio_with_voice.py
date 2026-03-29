#!/usr/bin/env python3
"""
generate_audio_with_voice.py
Generates realistic medical consultation audio files using Google TTS.
Each file contains a realistic dialogue matching the sample patient data.

Produces:
  - 3 WAV files (16kHz mono for optimal AI_TRANSCRIBE compatibility)
  - 2 MP3 files (128kbps)

Usage:
  source .venv/bin/activate
  python generate_audio_with_voice.py
"""

import os
import subprocess
import json
import time
from gtts import gTTS

AUDIO_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sample_files", "audio")
os.makedirs(AUDIO_DIR, exist_ok=True)


def get_duration(filepath):
    """Get audio duration in seconds using ffprobe."""
    result = subprocess.run(
        ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", filepath],
        capture_output=True, text=True
    )
    info = json.loads(result.stdout)
    return float(info["format"]["duration"])


def text_to_wav(text, filepath, lang="en", max_retries=3):
    """Generate WAV file from text using gTTS + ffmpeg (no pydub)."""
    tmp_mp3 = filepath + ".tmp.mp3"
    for attempt in range(max_retries):
        try:
            tts = gTTS(text=text, lang=lang, slow=False)
            tts.save(tmp_mp3)
            break
        except Exception as e:
            if attempt < max_retries - 1:
                wait = 10 * (attempt + 1)
                print(f"    Retry {attempt+1}/{max_retries} after {wait}s: {e}")
                time.sleep(wait)
            else:
                raise
    # Convert MP3 to WAV: 16kHz mono, PCM signed 16-bit
    subprocess.run(
        ["ffmpeg", "-y", "-i", tmp_mp3, "-ar", "16000", "-ac", "1",
         "-acodec", "pcm_s16le", filepath],
        capture_output=True, check=True
    )
    os.remove(tmp_mp3)
    duration = get_duration(filepath)
    print(f"  Created {os.path.basename(filepath)} ({duration:.1f}s)")


def text_to_mp3(text, filepath, lang="en", max_retries=3):
    """Generate MP3 file from text using gTTS."""
    for attempt in range(max_retries):
        try:
            tts = gTTS(text=text, lang=lang, slow=False)
            tts.save(filepath)
            break
        except Exception as e:
            if attempt < max_retries - 1:
                wait = 10 * (attempt + 1)
                print(f"    Retry {attempt+1}/{max_retries} after {wait}s: {e}")
                time.sleep(wait)
            else:
                raise
    duration = get_duration(filepath)
    print(f"  Created {os.path.basename(filepath)} ({duration:.1f}s)")


# =========================================================================
# CONSULTATION SCRIPTS — matching our sample patient data
# =========================================================================

# WAV 1: John Whitfield — BP follow-up with Dr. Sarah Chen
# Matches: Patient 101, Provider 1, Appointment 2016
WHITFIELD_BP = """
Good morning, Mr. Whitfield. I'm Dr. Chen. How are you feeling today?

I'm doing much better, Doctor. The headaches have completely gone away since I started back on the medications.

That's excellent news. Let me check your blood pressure. One forty two over eighty eight. That's much improved from when you were admitted with two ten over one thirty. Are you taking all your medications regularly?

Yes, every single day. The social worker helped me get into the patient assistance program, so I don't have to worry about the cost anymore. I'm taking the amlodipine, lisinopril, hydrochlorothiazide, metformin, atorvastatin, and aspirin.

Perfect. That's all six medications. Have you been monitoring your blood pressure at home like we discussed?

Yes, I've been checking it twice a day. Most readings are in the one thirty to one forty range over eighty to ninety. I wrote them all down in my log book.

That's great compliance, Mr. Whitfield. Your blood pressure is well controlled now. I want to keep you on the current regimen. Have you had any side effects? Dizziness, coughing, swelling in your ankles?

No side effects at all. I feel better than I have in months honestly.

Good. I'm also going to refer you to Dr. Okafor in cardiology for an echocardiogram follow-up. When you were admitted, we noticed some mild left ventricular hypertrophy, and we want to monitor that. Are you following the low sodium diet?

My wife has been cooking everything from scratch. We've cut out processed foods completely. She's been following the DASH diet recipes you recommended.

Excellent. Let's schedule your next appointment in four weeks. Continue all medications, keep monitoring blood pressure, and I'll have Dr. Okafor's office call you for the cardiology appointment. Any questions?

No, I think I'm good. Thank you, Dr. Chen.

You're welcome. Remember, if your blood pressure goes above one eighty over one twenty, or you get a severe headache or chest pain, go directly to the emergency department. Take care.
"""

# WAV 2: Roberto Garcia — Cardiac follow-up with Dr. James Okafor
# Matches: Patient 105, Provider 2, Appointment 2018
GARCIA_CARDIAC = """
Good morning, Mr. Garcia. I'm Dr. Okafor. I'm reviewing the results from your catheterization in August. How have you been feeling?

Hello, Doctor. I've been okay. A little tired sometimes, but much better than before the procedure. The chest pain hasn't come back.

That's reassuring. Your catheterization showed significant atherosclerotic disease in your left anterior descending artery. We placed a stent successfully, and the follow-up imaging looks good. Are you taking your clopidogrel every day? That's the Plavix.

Yes, I haven't missed a single dose. I take it with breakfast every morning along with the metoprolol, atorvastatin, and lisinopril.

Good. The clopidogrel is critical. You absolutely cannot stop it for at least twelve months after the stent placement. Even if you need a dental procedure or minor surgery, we need to discuss it first. How about the nitroglycerin? Have you needed to use it?

No, I haven't had any chest pain at all since the procedure.

Excellent. Let me listen to your heart. Heart sounds are regular, no murmurs. Your blood pressure today is one thirty over seventy eight, which is well controlled. Your last lab work showed your cholesterol is responding to the high-dose atorvastatin. LDL is down to ninety-five, which is where we want it.

That's good to hear. I have been watching my diet carefully.

I want to talk about cardiac rehabilitation. Have you enrolled in the program yet?

Not yet. I wasn't sure if my Medicare Advantage plan would cover it.

It should be covered. Cardiac rehab is strongly recommended after a catheterization with stent placement. It's a supervised exercise program that helps strengthen your heart and teaches you about heart-healthy lifestyle changes. I'll have my nurse coordinator help you with the referral and insurance verification.

That would be helpful. My wife has been worried about me exercising too much.

The rehab program is medically supervised, so it's actually the safest way to increase your activity level. Let's schedule your next follow-up in eight weeks. We'll repeat your lipid panel and check your kidney function. Continue all medications exactly as prescribed.

Thank you, Dr. Okafor. I appreciate everything you've done.
"""

# WAV 3: Patricia O'Brien — Therapy session with Dr. David Thompson
# Matches: Patient 108, Provider 6, Appointment 2017
OBRIEN_THERAPY = """
Hi Patricia. How have you been since our last session?

Hi Dr. Thompson. It's been an up and down couple of weeks honestly. Some days I feel like I'm making progress, and other days the depression just hits me hard.

Can you tell me more about what the harder days look like?

It's usually related to the divorce proceedings. We had a custody mediation last week, and my ex is pushing for fifty-fifty time with the kids. I know that might be fair, but the thought of not seeing them every day makes me feel so guilty and anxious.

That guilt you're feeling, let's explore that. What specifically are you feeling guilty about?

I feel like the divorce is my fault, like I'm breaking up the family. The kids are adjusting, but my daughter has been acting out at school, and I keep thinking that's because of me.

Patricia, I want to gently challenge that thought. Divorce involves two people, and staying in an unhappy marriage can also affect children. Remember the cognitive restructuring work we've been doing? What would you say to a friend in the same situation?

I'd probably tell them it's not all their fault. That sometimes relationships just don't work out, and what matters is being a good parent going forward.

Exactly. And how is the sertraline working? Any changes in sleep or appetite?

Sleep is better. I'm getting about six hours now, but I still wake up around four thirty in the morning and can't fall back asleep. My appetite is slowly coming back. I've been eating regular meals.

Good. Your PHQ-9 score today is eleven, which is down from fifteen at our last session. That's meaningful improvement. The melatonin we discussed, did you try it?

Yes, I started with three milligrams at bedtime. It helps me fall asleep faster, but it doesn't prevent the early morning awakening.

That early morning awakening pattern is common with depression. As the sertraline continues to work, that should improve. I don't want to increase the dose yet because you are making progress. Let's continue at one hundred milligrams and reassess in two weeks.

Okay. The walking has been helping too. I've been doing thirty minutes four days a week like we discussed.

That's excellent. Physical activity is one of the best complementary treatments for depression. Let's schedule our next session for September fifteenth. Keep up with the walking, the sertraline, and the melatonin. And remember, if you're having a really difficult day, the nine eight eight crisis line is available twenty-four seven.

Thank you, Dr. Thompson. These sessions really help.
"""

# MP3 1: Amara Johnson — Pediatric well-child visit with Dr. Lisa Wang
# Matches: Patient 110, Provider 7, Appointment 2011
JOHNSON_PEDIATRIC = """
Hi there! You must be Amara. I'm Dr. Wang. And you must be Mom. Please have a seat.

Hi Doctor. Yes, this is Amara. She just turned nine in June.

Happy belated birthday, Amara! So this is her well-child check-up. Let me look at her chart. She's up to date on vaccinations through age seven. We'll need to do a couple of catch-up immunizations today. How has she been doing overall?

She's been great. Really active, doing well in school. She's in fourth grade now and loves reading.

That's wonderful. Any concerns? Fevers, coughs, frequent illnesses?

No, she's been very healthy. She did have a stomach bug a couple months ago but recovered quickly.

That's normal. Let me do her physical exam. Height is four feet four inches, weight is sixty-two pounds. She's right at the fiftieth percentile for both, which is perfect. Heart sounds normal, lungs clear, abdomen soft. Eyes and ears look good. Amara, can you read the letters on that chart on the wall for me?

E, F, P, T, O, Z.

Perfect vision. Okay, she looks fantastic. For immunizations today, she's due for her DTaP booster and her second dose of HPV vaccine. We'll also do a quick hearing screen.

Is the HPV vaccine really necessary at her age?

Great question. The CDC recommends starting the HPV series between ages nine and twelve because the immune response is strongest at this age. It protects against several types of cancer later in life. It's very safe and very effective.

Okay, that makes sense. Let's go ahead with it.

Alright. The nurse will come in to administer the vaccines. Amara might have some arm soreness for a day or two, which is completely normal. I'd recommend children's Tylenol if it bothers her. Her next well-child visit will be at age ten. Any other questions?

No, I think we're all set. Thank you, Dr. Wang.

You're welcome! Amara, keep up the great reading. See you next year!
"""

# MP3 2: Yuki Tanaka — Dermatology visit with Dr. Michael Johnson
# Matches: Patient 115, Provider 8, Appointment 2019
TANAKA_DERMATOLOGY = """
Good afternoon, Ms. Tanaka. I'm Dr. Johnson. What brings you in today?

Hi Doctor. I have this spot on my left shoulder that's been bothering me. It's been there for maybe six months, but recently it seems like it's gotten a little bigger and darker.

Let me take a look. Can you pull down your sleeve? Okay, I see the lesion. It's about eight millimeters in diameter, slightly raised, with irregular borders. Does it itch or bleed?

It itches sometimes, but it hasn't bled.

I'm going to examine it with my dermatoscope. This is a magnifying instrument with a light that lets me see the structure of the skin more closely. Hold still for just a moment.

Okay.

I can see some pigment network patterns. The good news is that this has features most consistent with a seborrheic keratosis, which is a very common benign skin growth. However, given the irregular borders and the fact that it's changed, I'd like to do a tangential biopsy just to be safe. That means I'll shave off a thin layer and send it to the pathology lab.

Is that going to hurt?

I'll numb the area with a local anesthetic first. You'll feel a small pinch from the injection, and then you won't feel anything during the biopsy itself. The whole procedure takes about five minutes.

Okay, let's do it.

I'm going to clean the area first with an antiseptic. Now I'll inject the lidocaine. Small pinch. Good. Give that a minute to take effect. Can you feel this? 

No, nothing.

Perfect. I'm going to do the biopsy now. You'll feel some pressure but no pain. And we're done. I'm applying a small bandage. Keep it clean and dry for twenty-four hours, then you can wash it gently with soap and water. Apply a thin layer of petroleum jelly and a bandaid for about a week until it heals.

When will I get the results?

The pathology results usually take five to seven business days. My office will call you with the results. If it's benign as I expect, no further treatment is needed. If there's anything concerning, we'll schedule a follow-up right away.

Thank you, Dr. Johnson.

You're welcome, Ms. Tanaka. One more thing. Since you're here, I'd recommend wearing sunscreen daily, SPF thirty or higher, especially on exposed areas. You have fair skin, and sun protection is the best prevention for skin issues. We'll be in touch with your results.
"""


def main():
    print("Generating audio files with real voice (Google TTS)...\n")

    # Remove old tone-based files (keep already-generated voice files)
    for f in os.listdir(AUDIO_DIR):
        old_path = os.path.join(AUDIO_DIR, f)
        size_kb = os.path.getsize(old_path) / 1024
        # Only remove small tone-based files (< 50KB); keep large voice files
        if size_kb < 50:
            os.remove(old_path)
            print(f"  Removed old tone-based file: {f}")
    print()

    delay_between = 15  # seconds between API calls to avoid rate limits

    # WAV files
    print("Generating WAV files...")
    wav1 = os.path.join(AUDIO_DIR, "consultation_whitfield_bp.wav")
    if os.path.exists(wav1) and os.path.getsize(wav1) > 100000:
        print(f"  Skipping {os.path.basename(wav1)} (already exists)")
    else:
        text_to_wav(WHITFIELD_BP, wav1)
    time.sleep(delay_between)

    wav2 = os.path.join(AUDIO_DIR, "consultation_garcia_cardiac.wav")
    if os.path.exists(wav2) and os.path.getsize(wav2) > 100000:
        print(f"  Skipping {os.path.basename(wav2)} (already exists)")
    else:
        text_to_wav(GARCIA_CARDIAC, wav2)
    time.sleep(delay_between)

    wav3 = os.path.join(AUDIO_DIR, "consultation_obrien_therapy.wav")
    if os.path.exists(wav3) and os.path.getsize(wav3) > 100000:
        print(f"  Skipping {os.path.basename(wav3)} (already exists)")
    else:
        text_to_wav(OBRIEN_THERAPY, wav3)
    time.sleep(delay_between)

    print("\nGenerating MP3 files...")
    mp3_1 = os.path.join(AUDIO_DIR, "consultation_johnson_pediatric.mp3")
    if os.path.exists(mp3_1) and os.path.getsize(mp3_1) > 50000:
        print(f"  Skipping {os.path.basename(mp3_1)} (already exists)")
    else:
        text_to_mp3(JOHNSON_PEDIATRIC, mp3_1)
    time.sleep(delay_between)

    mp3_2 = os.path.join(AUDIO_DIR, "consultation_tanaka_dermatology.mp3")
    if os.path.exists(mp3_2) and os.path.getsize(mp3_2) > 50000:
        print(f"  Skipping {os.path.basename(mp3_2)} (already exists)")
    else:
        text_to_mp3(TANAKA_DERMATOLOGY, mp3_2)

    # Summary
    print("\nAll audio files generated:")
    for f in sorted(os.listdir(AUDIO_DIR)):
        path = os.path.join(AUDIO_DIR, f)
        size_kb = os.path.getsize(path) / 1024
        duration = get_duration(path)
        print(f"  {f}: {size_kb:.0f} KB, {duration:.1f}s")


if __name__ == "__main__":
    main()
