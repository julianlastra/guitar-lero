#include "smoke_on_the_water.h"

#define SONG_SYNC_OFFSET_STEPS 0

static const ChartEvent smokeOnTheWaterEvents[] =
{
/* Bar 1 */
{0, 0},
{1, 4},
{2, 8},
{0, 12},

/* Bar 2 */
{1, 16},
{2, 20},
{1, 24},
{0, 28},

/* Bar 3 */
{0, 32},
{1, 36},
{2, 40},
{1, 44},

/* Bar 4 */
{0, 48},
{1, 52},
{0, 56},

/* Bar 5 */
{0, 64},
{1, 68},
{2, 72},
{0, 76},

/* Bar 6 */
{1, 80},
{2, 84},
{1, 88},
{0, 92},

/* Bar 7 */
{0, 96},
{1,100},
{2,104},
{1,108},

/* Bar 8 */
{0,112},
{1,116},
{0,120}

};

const SongChart songSmokeOnTheWater =
{
"Smoke Water",
112,
SONG_SYNC_OFFSET_STEPS,
128,
smokeOnTheWaterEvents,
sizeof(smokeOnTheWaterEvents) / sizeof(smokeOnTheWaterEvents[0])
};