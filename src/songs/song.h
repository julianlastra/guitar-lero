#ifndef SONG_H
#define SONG_H

#include <genesis.h>

typedef struct
{
    u16 lane;
    u16 step;
} ChartEvent;

typedef struct
{
    const char* title;
    u16 bpm;
    u16 introSteps;
    u16 loopSteps;
    const ChartEvent* events;
    u16 eventCount;
} SongChart;

#endif
