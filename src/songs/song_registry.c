#include "song_registry.h"
#include "smoke_on_the_water.h"
#include "seven_nation_army.h"
#include "neon_iron_chase.h"

const SongChart* const songList[] =
{
    &songSmokeOnTheWater,
    &songSevenNationArmy,
    &songNeonIronChase
};

const u16 songCount = sizeof(songList) / sizeof(songList[0]);