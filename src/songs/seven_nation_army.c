#include "seven_nation_army.h"

#define SONG_SYNC_OFFSET_STEPS 0

/*
 * Seven Nation Army - main riff only
 *
 * Tab shape reference:
 * 7 - 7 - 10 - 7 - 5 - 3 - 2
 *
 * Interpreted as pitches around:
 * E3 = 165 Hz
 * G3 = 196 Hz
 * D3 = 147 Hz
 * C3 = 131 Hz
 * B2 = 123 Hz
 *
 * Fifths:
 * B3  = 247 Hz
 * D4  = 294 Hz
 * A3  = 220 Hz
 * G3  = 196 Hz
 * F#3 = 185 Hz
 *
 * lane = gameplay lane only
 * pitch = defined here
 */
static const ChartEvent sevenNationArmyEvents[] =
{
/* Phrase 1: 7 - 7 - 10 - 7 */
{0,  0, 4, 165, 247}, /* E */
{0,  4, 4, 165, 247}, /* E */
{2,  8, 4, 196, 294}, /* G */
{1, 12, 4, 165, 247}, /* E */

/* Phrase 2: 5 - 3 - 2 */
{1, 16, 4, 147, 220}, /* D */
{0, 20, 4, 131, 196}, /* C */
{0, 24, 6, 123, 185}, /* B */

/* Phrase 3: repeat 7 - 7 - 10 - 7 */
{0, 32, 4, 165, 247}, /* E */
{0, 36, 4, 165, 247}, /* E */
{2, 40, 4, 196, 294}, /* G */
{1, 44, 4, 165, 247}, /* E */

/* Phrase 4: 5 - 3 - 2 */
{1, 48, 4, 147, 220}, /* D */
{0, 52, 4, 131, 196}, /* C */
{0, 56, 8, 123, 185}  /* B */
};

const SongChart songSevenNationArmy =
{
    "Seven Nation Army",
    124,
    SONG_SYNC_OFFSET_STEPS,
    64,
    sevenNationArmyEvents,
    sizeof(sevenNationArmyEvents) / sizeof(sevenNationArmyEvents[0])
};