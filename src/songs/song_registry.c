#include "song_registry.h"
#include "smoke_on_the_water.h"
#include "seven_nation_army.h"

const SongChart* const songList[] =
{
    &songSmokeOnTheWater,
    &songSevenNationArmy
};

const u16 songCount = sizeof(songList) / sizeof(songList[0]);