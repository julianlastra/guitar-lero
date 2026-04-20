#include "smoke_on_the_water.h"

#define SONG_SYNC_OFFSET_STEPS 0

/*
 * Faster, tighter main riff only.
 *
 * Riff shape:
 * G - Bb - C / G - Bb - Db - C / G - Bb - C / Bb - G
 *
 * lane = gameplay lane only
 * pitch = defined here, not by lane
 *
 * G3  = 196 Hz
 * Bb3 = 233 Hz
 * C4  = 262 Hz
 * Db4 = 277 Hz
 *
 * Fifths:
 * D4  = 294 Hz
 * F4  = 349 Hz
 * G4  = 392 Hz
 * Ab4 = 415 Hz
 */
static const ChartEvent smokeOnTheWaterEvents[] =
{
/* Bar 1 */
{0,  0, 4, 196, 294}, /* G  */
{1,  4, 3, 233, 349}, /* Bb */
{2,  7, 3, 262, 392}, /* C  */
{0, 12, 4, 196, 294}, /* G  */

/* Bar 2 */
{1, 16, 3, 233, 349}, /* Bb */
{2, 19, 3, 277, 415}, /* Db */
{1, 22, 4, 262, 392}, /* C  */

/* Bar 3 */
{0, 28, 4, 196, 294}, /* G  */
{1, 32, 3, 233, 349}, /* Bb */
{2, 35, 3, 262, 392}, /* C  */

/* Bar 4 */
{1, 40, 3, 233, 349}, /* Bb */
{0, 43, 6, 196, 294}  /* G  */
};

const SongChart songSmokeOnTheWater =
{
    "Smoke on the Water",
    114,
    SONG_SYNC_OFFSET_STEPS,
    48,
    smokeOnTheWaterEvents,
    sizeof(smokeOnTheWaterEvents) / sizeof(smokeOnTheWaterEvents[0])
};