#include <genesis.h>
#include "resources.h"
#include "songs/song.h"
#include "songs/smoke_on_the_water.h"

/*
 * Guitar Lero
 * Minimal SGDK rhythm prototype
 *
 * Current goals:
 * - 3 lanes
 * - 1 falling note at a time
 * - hit line
 * - per-lane input
 * - hit / miss scoring
 *
 * The code is intentionally data-driven so scaling to 3 lanes later mostly
 * means updating constants / arrays instead of rewriting the game loop.
 */

#define LANE_COUNT         3
#define MAX_NOTES          16
#define SCREEN_ROWS        28
#define HIT_LINE_Y         200
#define NOTE_START_Y      -16
#define SPEED_DEN          10
#define MISS_SFX_FREQ      220
#define MISS_SFX_FRAMES    7
#define GUITAR_MIN_FRAMES   4
#define LANE_FEEDBACK_FRAMES 7
#define FIXED_FPS          60
#define TIME_FP_SHIFT      12
#define TIME_FP_ONE        (1 << TIME_FP_SHIFT)
#define CHART_STEPS_PER_BEAT 4
#define HEADER_ROWS        4
#define PLAYFIELD_TOP_ROW  5
#define NOTE_SPRITE_OFFSET_X 16
#define NOTE_SPRITE_OFFSET_Y 16
#define HIT_ZONE_OFFSET_X  12
#define HIT_ZONE_OFFSET_Y  5

/* noteLines X positions aligned to the converted gameplay background. */
static const s16 noteLinesX[LANE_COUNT] = { 16, 20, 24 };
static const char laneLabels[LANE_COUNT] = { 'A', 'B', 'C' };

/* Button mapping for each lane. */
static const u16 laneButtons[LANE_COUNT] = { BUTTON_A, BUTTON_B, BUTTON_C };

typedef enum
{
    DIFFICULTY_EASY = 0,
    DIFFICULTY_NORMAL,
    DIFFICULTY_HARD,
    DIFFICULTY_COUNT
} Difficulty;

/*
 * Future hook for difficulty selection:
 * speed values are in pixels * 10 per frame.
 * Old speed was 2.0 px/frame (20), now normal is 1.6 px/frame (16 = 80%).
 */
static const u16 speedByDifficulty[DIFFICULTY_COUNT] = { 12, 16, 20 };
static const u16 hitWindowByDifficulty[DIFFICULTY_COUNT] = { 12, 8, 6 };
static Difficulty currentDifficulty = DIFFICULTY_EASY;

typedef struct
{
    s16 x;
    s16 y;
    u16 lane;
    u16 durationSteps;
    u16 rootHz;
    u16 fifthHz;
    bool active;
    bool hit;
} Note;

static Note notes[MAX_NOTES];

static s16 score = 0;
static s16 misses = 0;
static u16 scrollAccumulator = 0;
static s16 uiSfxFramesLeft = 0;
static s16 guitarSfxFramesLeft = 0;
static s16 guitarSfxTotalFrames = 0;
static u16 guitarRootCurrentHz = 0;
static u16 guitarFifthCurrentHz = 0;
static s16 laneFeedbackTimer[LANE_COUNT];
static bool laneFeedbackHit[LANE_COUNT];

static const s16 hitLineRow = (HIT_LINE_Y >> 3);

static const u16 lanePalettes[LANE_COUNT] = { PAL1, PAL2, PAL3 };

static const SpriteDefinition* noteDefinitions[LANE_COUNT] = { &noteRed, &noteYellow, &noteGreen };
static const SpriteDefinition* hitZoneDefinitions[LANE_COUNT] = { &hitZoneRed, &hitZoneYellow, &hitZoneGreen };
static Sprite* noteSprites[MAX_NOTES];
static Sprite* hitZoneSprites[LANE_COUNT];

static const SongChart* activeSong = &songSmokeOnTheWater;
static u32 framesPerStepFP = 0;
static u32 travelFramesFP = 0;
static u32 songFrameFP = 0;
static u16 schedulerLeadSteps = 0;
static u16 nextEventIndex = 0;
static u16 loopCount = 0;

static void setupLaneColors(void)
{
    PAL_setPalette(PAL1, noteRed.palette->data, CPU);
    PAL_setPalette(PAL2, noteYellow.palette->data, CPU);
    PAL_setPalette(PAL3, noteGreen.palette->data, CPU);
    PAL_setColor((16 * PAL1) + 15, RGB24_TO_VDPCOLOR(0xFF0000));
    PAL_setColor((16 * PAL2) + 15, RGB24_TO_VDPCOLOR(0xFFFF00));
    PAL_setColor((16 * PAL3) + 15, RGB24_TO_VDPCOLOR(0x00FF00));
}

static void initSprites(void)
{
    u16 i;
    u16 lane;
    s16 laneX;

    SPR_init();

    for (lane = 0; lane < LANE_COUNT; lane++)
    {
        laneX = (noteLinesX[lane] << 3) - HIT_ZONE_OFFSET_X;
        hitZoneSprites[lane] = SPR_addSprite(hitZoneDefinitions[lane],
            laneX,
            HIT_LINE_Y - HIT_ZONE_OFFSET_Y,
            TILE_ATTR(lanePalettes[lane], TRUE, FALSE, FALSE));
        SPR_setVisibility(hitZoneSprites[lane], VISIBLE);
        SPR_setDepth(hitZoneSprites[lane], 8 + lane);
    }

    for (i = 0; i < MAX_NOTES; i++)
    {
        noteSprites[i] = SPR_addSprite(noteDefinitions[0],
            0,
            0,
            TILE_ATTR(PAL1, TRUE, FALSE, FALSE));
        SPR_setVisibility(noteSprites[i], HIDDEN);
        SPR_setDepth(noteSprites[i], 0);
    }
}

static void setLaneTextColor(u16 lane)
{
    VDP_setTextPalette(lanePalettes[lane]);
}

static void setDefaultTextColor(void)
{
    VDP_setTextPalette(PAL0);
}

static void setHitFeedbackColor(void)
{
    /* Green highlight when note is hit. */
    VDP_setTextPalette(PAL3);
}

static void setMissFeedbackColor(void)
{
    /* Red highlight when note is missed. */
    VDP_setTextPalette(PAL1);
}

/*
 * PSG guitar-ish power chord frequencies (approx):
 * root on channel 1 + fifth on channel 2.
 */
// This limits notes to these frequencies, but it's a simple way to get a more musical sound without needing custom samples or complex synthesis.
//static const u16 laneGuitarRootHz[LANE_COUNT] = { 147, 175, 196 };
//static const u16 laneGuitarFifthHz[LANE_COUNT] = { 220, 262, 294 };

static u16 getHitWindow(void)
{
    return hitWindowByDifficulty[currentDifficulty];
}

static u16 stepsToFrames(u16 durationSteps)
{
    u32 durationFramesFP;
    u16 frames;

    durationFramesFP = (u32)durationSteps * framesPerStepFP;
    frames = (u16)((durationFramesFP + (TIME_FP_ONE - 1)) >> TIME_FP_SHIFT);

    if (frames < GUITAR_MIN_FRAMES)
    {
        frames = GUITAR_MIN_FRAMES;
    }

    return frames;
}

static void playUiSfx(u16 frequency, u8 envelope, s16 durationFrames)
{
    PSG_setFrequency(0, frequency);
    PSG_setEnvelope(0, envelope);
    uiSfxFramesLeft = durationFrames;
}

static void playGuitarNote(u16 rootHz, u16 fifthHz, u16 durationSteps)
{
    u16 durationFrames = stepsToFrames(durationSteps);

    guitarRootCurrentHz = rootHz;
    guitarFifthCurrentHz = fifthHz;

    PSG_setFrequency(1, guitarRootCurrentHz);
    PSG_setFrequency(2, guitarFifthCurrentHz);

    PSG_setEnvelope(1, 1);
    PSG_setEnvelope(2, 3);

    guitarSfxFramesLeft = durationFrames;
    guitarSfxTotalFrames = durationFrames;
}

static void triggerLaneFeedback(u16 lane, bool hit)
{
    laneFeedbackTimer[lane] = LANE_FEEDBACK_FRAMES;
    laneFeedbackHit[lane] = hit;
}

static void updateLaneFeedback(void)
{
    u16 lane;

    for (lane = 0; lane < LANE_COUNT; lane++)
    {
        if (laneFeedbackTimer[lane] > 0)
        {
            laneFeedbackTimer[lane]--;
        }
    }
}

static void updateSfx(void)
{
    if (uiSfxFramesLeft > 0)
    {
        uiSfxFramesLeft--;
        if (uiSfxFramesLeft == 0)
        {
            PSG_setEnvelope(0, PSG_ENVELOPE_MIN);
        }
    }

    if (guitarSfxFramesLeft > 0)
    {
        s16 elapsed = guitarSfxTotalFrames - guitarSfxFramesLeft;
        s16 thirdPoint = guitarSfxTotalFrames / 3;
        s16 twoThirdsPoint = (guitarSfxTotalFrames * 2) / 3;
        u8 rootEnv;
        u8 fifthEnv;

        if (elapsed < 2)
        {
            rootEnv = 1;
            fifthEnv = 2;
        }
        else if (elapsed < thirdPoint)
        {
            rootEnv = 3;
            fifthEnv = 5;
        }
        else if (elapsed < twoThirdsPoint)
        {
            rootEnv = 6;
            fifthEnv = 8;
        }
        else
        {
            rootEnv = 10;
            fifthEnv = 12;
        }

        if (rootEnv > PSG_ENVELOPE_MIN) rootEnv = PSG_ENVELOPE_MIN;
        if (fifthEnv > PSG_ENVELOPE_MIN) fifthEnv = PSG_ENVELOPE_MIN;

        PSG_setEnvelope(1, rootEnv);
        PSG_setEnvelope(2, fifthEnv);

        if ((elapsed & 1) == 0)
        {
            PSG_setFrequency(1, guitarRootCurrentHz + 1);
            PSG_setFrequency(2, guitarFifthCurrentHz);
        }
        else
        {
            PSG_setFrequency(1, guitarRootCurrentHz);
            PSG_setFrequency(2, guitarFifthCurrentHz);
        }

        guitarSfxFramesLeft--;

        if (guitarSfxFramesLeft == 0)
        {
            PSG_setEnvelope(1, PSG_ENVELOPE_MIN);
            PSG_setEnvelope(2, PSG_ENVELOPE_MIN);
        }
    }
}

/*
 * Fractional frame speed so we can run at 1.6 px/frame (80% of old 2.0).
 * This keeps motion smooth and easy to tune per difficulty later.
 */
static s16 getNoteStepPixels(void)
{
    s16 pixels;

    scrollAccumulator += speedByDifficulty[currentDifficulty];
    pixels = scrollAccumulator / SPEED_DEN;
    scrollAccumulator %= SPEED_DEN;

    return pixels;
}

/*
 * Initialize BPM scheduler values.
 * Uses fixed-point frame math so timing stays stable on 50/60 Hz systems.
 */
static void resetSongScheduler(void)
{
    u32 fps = FIXED_FPS;
    u32 distancePixels = (u32)(HIT_LINE_Y - NOTE_START_Y);
    u32 speedNumerator = speedByDifficulty[currentDifficulty];
    u32 leadStepsFromTravel;

    framesPerStepFP = ((fps * 60UL) << TIME_FP_SHIFT) / (activeSong->bpm * CHART_STEPS_PER_BEAT);
    travelFramesFP = ((distancePixels * SPEED_DEN) << TIME_FP_SHIFT) / speedNumerator;
    leadStepsFromTravel = (travelFramesFP + framesPerStepFP - 1) / framesPerStepFP;
    schedulerLeadSteps = (u16)(leadStepsFromTravel + activeSong->introSteps);

    songFrameFP = 0;
    nextEventIndex = 0;
    loopCount = 0;
}

/*
 * Spawn one note in the requested lane.
 * Returns TRUE if a free note slot was found.
 */
static bool spawnNote(u16 lane, u16 durationSteps, u16 rootHz, u16 fifthHz)
{
    u16 i;

    for (i = 0; i < MAX_NOTES; i++)
    {
        if (!notes[i].active)
        {
            notes[i].lane = lane;
            notes[i].durationSteps = durationSteps;
            notes[i].rootHz = rootHz;
            notes[i].fifthHz = fifthHz;
            notes[i].x = noteLinesX[lane];
            notes[i].y = NOTE_START_Y;
            notes[i].active = TRUE;
            notes[i].hit = FALSE;
            return TRUE;
        }
    }

    return FALSE;
}

/* Spawn notes from BPM-synchronized chart events (loops forever). */
static void updateSpawner(void)
{
    while (TRUE)
    {
        const ChartEvent* event = &activeSong->events[nextEventIndex];
        u32 eventStepAbsolute = schedulerLeadSteps + event->step + (loopCount * activeSong->loopSteps);
        u32 hitFrameFP = eventStepAbsolute * framesPerStepFP;
        s32 spawnFrameFP = (s32)hitFrameFP - (s32)travelFramesFP;

        if ((s32)songFrameFP < spawnFrameFP)
        {
            break;
        }

            if (!spawnNote(event->lane, event->durationSteps, event->rootHz, event->fifthHz))
        {
            break;
        }

        nextEventIndex++;
        if (nextEventIndex >= activeSong->eventCount)
        {
            nextEventIndex = 0;
            loopCount++;
        }
    }
}

/* Move all active notes downward each frame. */
static void updateNotes(void)
{
    u16 i;
    s16 step = getNoteStepPixels();
    u16 hitWindow = getHitWindow();

    for (i = 0; i < MAX_NOTES; i++)
    {
        if (!notes[i].active)
        {
            continue;
        }

        notes[i].y += step;

        /* If a note goes past the hit window without being hit, count a miss. */
        if (notes[i].y > (HIT_LINE_Y + hitWindow))
        {
            u16 lane = notes[i].lane;
            notes[i].active = FALSE;
            misses++;
            triggerLaneFeedback(lane, FALSE);
            playUiSfx(MISS_SFX_FREQ, 8, MISS_SFX_FRAMES);
        }
    }
}

static void updateSongClock(void)
{
    songFrameFP += TIME_FP_ONE;
}

/*
 * Handle one lane button press.
 * If a note in that lane is inside the hit window, score a hit.
 * Otherwise, the press is treated as a miss.
 */
static void tryHitLane(u16 lane)
{
    u16 i;
    u16 hitWindow = getHitWindow();

    for (i = 0; i < MAX_NOTES; i++)
    {
        s16 distance;

        if (!notes[i].active || notes[i].lane != lane)
        {
            continue;
        }

        distance = notes[i].y - HIT_LINE_Y;
        if (distance < 0)
        {
            distance = -distance;
        }

        if (distance <= hitWindow)
        {
            notes[i].active = FALSE;
            notes[i].hit = TRUE;
            score++;
            triggerLaneFeedback(lane, TRUE);
            playGuitarNote(notes[i].rootHz, notes[i].fifthHz, notes[i].durationSteps);
            return;
        }
    }

    misses++;
    triggerLaneFeedback(lane, FALSE);
    playUiSfx(MISS_SFX_FREQ, 8, MISS_SFX_FRAMES);
}

/* React only to newly pressed buttons, not held buttons. */
static void handleInput(u16 value, u16 changed)
{
    u16 i;

    for (i = 0; i < LANE_COUNT; i++)
    {
        if ((changed & laneButtons[i]) && (value & laneButtons[i]))
        {
            tryHitLane(i);
        }
    }
}

/* Draw the lane guides and the hit line. */
static void drawPlayfield(void)
{
    u16 lane;
    u16 row;
    s16 x;

    for (lane = 0; lane < LANE_COUNT; lane++)
    {
        x = noteLinesX[lane];
        setLaneTextColor(lane);

        for (row = PLAYFIELD_TOP_ROW; row < SCREEN_ROWS - 2; row++)
        {
            VDP_drawText("|", x, row);
        }
    }

    setDefaultTextColor();
}

/* Draw score, misses, and button labels. */
static void drawUIStatic(void)
{
    u16 lane;
    char labelText[2];
    u16 titleX;
    u16 titleLen;

    titleLen = strlen(activeSong->title);
    titleX = (titleLen >= 40) ? 0 : (20 - (titleLen >> 1));
    VDP_drawText(activeSong->title, titleX, 0);

    for (lane = 0; lane < LANE_COUNT; lane++)
    {
        labelText[0] = laneLabels[lane];
        labelText[1] = 0;
        VDP_drawText(labelText, noteLinesX[lane], SCREEN_ROWS - 1);
    }
    setDefaultTextColor();

    VDP_drawText("SCORE:", 1, 1);
    VDP_drawText("MISS:", 1, 2);
    VDP_drawText("BPM:", 1, 3);
}

/* Draw static playfield/UI once (no per-frame clear). */
static void drawStaticScene(void)
{
    VDP_clearPlane(BG_B, TRUE);
    VDP_drawImage(BG_B, &gameplayBg, 0, 0);
    setupLaneColors();
    VDP_clearTextArea(0, 0, 40, SCREEN_ROWS);
    drawPlayfield();
    drawUIStatic();
}

static void updateNoteSprites(void)
{
    u16 i;
    s16 row;

    for (i = 0; i < MAX_NOTES; i++)
    {
        if (!notes[i].active)
        {
            SPR_setVisibility(noteSprites[i], HIDDEN);
            continue;
        }

        row = notes[i].y >> 3;
        if ((row >= PLAYFIELD_TOP_ROW) && (row < SCREEN_ROWS))
        {
            SPR_setDefinition(noteSprites[i], noteDefinitions[notes[i].lane]);
            SPR_setPalette(noteSprites[i], lanePalettes[notes[i].lane]);
            SPR_setPosition(noteSprites[i],
                (notes[i].x << 3) - NOTE_SPRITE_OFFSET_X,
                notes[i].y - NOTE_SPRITE_OFFSET_Y);
            SPR_setVisibility(noteSprites[i], VISIBLE);
        }
        else
        {
            SPR_setVisibility(noteSprites[i], HIDDEN);
        }
    }
}

/* Draw only dynamic text data; notes are hardware sprites. */
static void renderDynamic(void)
{
    u16 i;
    char valueText[8];

    VDP_clearTextArea(8, 1, 8, 1);
    intToStr(score, valueText, 1);
    VDP_drawText(valueText, 8, 1);

    VDP_clearTextArea(7, 2, 8, 1);
    intToStr(misses, valueText, 1);
    VDP_drawText(valueText, 7, 2);

    VDP_clearTextArea(6, 3, 8, 1);
    intToStr(activeSong->bpm, valueText, 1);
    VDP_drawText(valueText, 6, 3);

    /* Hit/miss flash directly on each note line hit zone. */
    for (i = 0; i < LANE_COUNT; i++)
    {
        if (laneFeedbackTimer[i] <= 0)
        {
            VDP_clearTextArea(noteLinesX[i] - 1, hitLineRow - 1, 3, 1);
            continue;
        }

        if (laneFeedbackHit[i])
        {
            setHitFeedbackColor();
            VDP_drawText("***", noteLinesX[i] - 1, hitLineRow - 1);
        }
        else
        {
            setMissFeedbackColor();
            VDP_drawText("xxx", noteLinesX[i] - 1, hitLineRow - 1);
        }
    }

    setDefaultTextColor();
}

int main(bool hard)
{
    u16 value;
    u16 changed;
    u16 previousValue = 0;
    u16 i;

    JOY_init();
    PSG_reset();
    PSG_setEnvelope(0, PSG_ENVELOPE_MIN);
    PSG_setEnvelope(1, PSG_ENVELOPE_MIN);
    PSG_setEnvelope(2, PSG_ENVELOPE_MIN);
    PSG_setEnvelope(3, PSG_ENVELOPE_MIN);
    setDefaultTextColor();
    VDP_setScreenWidth320();
    VDP_clearPlane(BG_A, TRUE);
    VDP_clearTextArea(0, 0, 40, SCREEN_ROWS);
    initSprites();
    drawStaticScene();
    setupLaneColors();
    for (i = 0; i < LANE_COUNT; i++)
    {
        laneFeedbackTimer[i] = 0;
        laneFeedbackHit[i] = FALSE;
    }

    /* Initialize BPM-based scheduler for the active song chart. */
    resetSongScheduler();
    updateNoteSprites();
    renderDynamic();
    SPR_update();
    SYS_doVBlankProcess();

    while (TRUE)
    {
        /* 1. Read input */
        JOY_update();
        value = JOY_readJoypad(JOY_1);
        changed = value & ~previousValue;
        handleInput(value, changed);
        previousValue = value;

        /* 2. Update note positions */
        updateNotes();
        updateSongClock();
        updateSpawner();
        updateSfx();
        updateLaneFeedback();

        /* 3. Hit / miss logic is handled in handleInput() and updateNotes() */
        updateNoteSprites();

        /* 4. Render dynamic elements */
        renderDynamic();
        SPR_update();

        /* 5. Wait for VBlank */
        SYS_doVBlankProcess();
    }

    return 0;
}
