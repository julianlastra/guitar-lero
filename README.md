# Guitar Lero

**Guitar Lero** es un prototipo de juego de ritmo retro para **Sega Mega Drive / Genesis** hecho en **C con SGDK**.

La idea del proyecto es capturar una sensación tipo arcade rock con estética 16-bit, usando:
- carriles visuales simples
- notas que caen por pista
- hit zones por color
- selección de canciones desde menú
- charts definidos por código
- reproducción de riffs usando PSG con aproximación de power chord

---

## Estado actual del proyecto

Actualmente el juego ya incluye:

- **3 carriles jugables**
- **menú principal**
- **selector de canciones**
- **retorno al menú con botón X**
- **notas con duración**
- **pitch independiente del color/carril**
- **charts definidos por canción**
- **sprites y fondo retro estilo Genesis**
- **feedback visual de hit/miss**
- **sistema básico de reproducción tipo guitarra arcade**

---

## Filosofía de diseño

Este proyecto sigue estas reglas:

### 1. El carril no define el sonido
Antes el color del carril estaba atado a grave/medio/agudo.  
Eso se corrigió.

Ahora:
- **el carril solo define por dónde cae la nota**
- **la frecuencia real de la nota depende del archivo de la canción**

Eso permite que:
- una nota en carril rojo pueda sonar como **RE**
- otra nota también en rojo pueda sonar como **FA**
- el gameplay visual y el sonido musical estén separados correctamente

---

### 2. Cada nota tiene duración
Cada evento musical ya no es solo un golpe instantáneo.

Ahora cada nota define:
- cuándo aparece
- en qué carril cae
- cuánto dura
- qué frecuencia base usa
- qué quinta usa para el power chord

---

### 3. El motor usa charts data-driven
Las canciones no están hardcodeadas dentro del loop del juego.  
Cada canción vive en su propio archivo `.c/.h`.

Eso hace más fácil:
- agregar canciones nuevas
- ajustar BPM
- modificar riffs
- testear prototipos rápidamente

---

## Estructura general esperada

Una estructura recomendada del proyecto es esta:

```text
src/
  main.c
  songs/
    song.h
    song_registry.h
    song_registry.c
    smoke_on_the_water.h
    smoke_on_the_water.c
    seven_nation_army.h
    seven_nation_army.c
    neon_iron_chase.h
    neon_iron_chase.c

res/
  resources.res
  ...
Controles
Menú principal
UP / DOWN: mover selección
START o A: iniciar canción
Durante gameplay
A / B / C: inputs musicales o lanes jugables
X: volver al menú principal

Nota: X se usa para volver al menú porque B ya forma parte del input de juego y no conviene mezclar una acción de navegación con una acción rítmica.

Canciones actuales
Smoke on the Water

Riff principal ajustado para testear timing, pitch independiente por nota y duración.

Seven Nation Army

Riff principal basado en la figura típica reconocible del tema.

Neon Iron Chase

Canción original creada para testeo, sin depender de material comercial.

Cómo funciona una canción

Cada canción está representada por un SongChart.

La estructura base está en song.h.

song.h
#ifndef SONG_H
#define SONG_H

#include <genesis.h>

typedef struct
{
    u16 lane;
    u16 step;
    u16 durationSteps;
    u16 rootHz;
    u16 fifthHz;
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
Significado de cada campo
lane

Indica por qué carril cae la nota.

Ejemplo:

0 = rojo
1 = amarillo
2 = verde

Importante:
lane no define el pitch.

step

Es la posición rítmica del evento dentro del loop de la canción.

Mientras más chico el espacio entre steps:

más rápida se siente la frase
menos aire hay entre notas

Mientras más grande:

más lenta o espaciada se siente
durationSteps

Cuánto dura la nota.

No cambia el momento en que empieza la nota.
Cambia cuánto tiempo “suena” o se sostiene.

rootHz

Frecuencia principal de la nota.

Ejemplos:

196 ≈ G
233 ≈ Bb
262 ≈ C
147 ≈ D
165 ≈ E
fifthHz

Frecuencia de la quinta justa usada para formar el power chord.

Ejemplo:

root: 196
fifth: 294

Eso genera un sonido más rockero que una sola frecuencia aislada.

Cómo crear una canción nueva

Cada canción necesita dos archivos:

un .h
un .c
Paso 1: crear el header

Ejemplo: my_song.h

#ifndef MY_SONG_H
#define MY_SONG_H

#include "song.h"

extern const SongChart songMySong;

#endif
Paso 2: crear el archivo .c

Ejemplo: my_song.c

#include "my_song.h"

#define SONG_SYNC_OFFSET_STEPS 0

static const ChartEvent mySongEvents[] =
{
/* Bar 1 */
{0,  0, 4, 196, 294},
{1,  4, 4, 233, 349},
{2,  8, 4, 262, 392},
{1, 12, 4, 233, 349},

/* Bar 2 */
{0, 16, 4, 196, 294},
{1, 20, 4, 220, 330},
{2, 24, 4, 262, 392},
{0, 28, 6, 196, 294}
};

const SongChart songMySong =
{
    "My Song",
    120,
    SONG_SYNC_OFFSET_STEPS,
    32,
    mySongEvents,
    sizeof(mySongEvents) / sizeof(mySongEvents[0])
};
Paso 3: registrarla en el selector de canciones

Archivo: song_registry.c

#include "song_registry.h"
#include "smoke_on_the_water.h"
#include "seven_nation_army.h"
#include "neon_iron_chase.h"
#include "my_song.h"

const SongChart* const songList[] =
{
    &songSmokeOnTheWater,
    &songSevenNationArmy,
    &songNeonIronChase,
    &songMySong
};

const u16 songCount = sizeof(songList) / sizeof(songList[0]);
Cómo pensar una canción para este engine

La mejor forma es separar mentalmente 4 cosas:

1. Figura musical

La secuencia de notas.

Ejemplo:

G - Bb - C - G
2. Ritmo

En qué steps cae cada nota.

Ejemplo:

0, 4, 7, 12
3. Duración

Cuánto sostiene cada una.

Ejemplo:

4, 3, 3, 4
4. Distribución visual

En qué carril cae cada nota para que se vea legible.

Ejemplo:

0, 1, 2, 0
Regla importante de charting

No armes el chart pensando:

rojo = grave
amarillo = medio
verde = agudo

Eso está mal para este motor.

Pensalo así:

el carril es solo visual
la frecuencia real va en rootHz y fifthHz

Recomendación para migrar riffs

Si querés migrar riffs de guitarra al juego, conviene este proceso:

escribir la secuencia de notas del riff
elegir un BPM aproximado
definir los steps
definir las duraciones
asignar lanes por legibilidad visual
testear y ajustar a oído
Frecuencias útiles para riffs rock

Estas combinaciones sirven bien para testeo:

/* B2  */ 123, 185
/* C3  */ 131, 196
/* D3  */ 147, 220
/* E3  */ 165, 247
/* F3  */ 175, 262
/* G3  */ 196, 294
/* A3  */ 220, 330
/* Bb3 */ 233, 349
/* C4  */ 262, 392
/* D4  */ 294, 440

Formato:

rootHz, fifthHz
Cómo ajustar el “feel” de una canción

Si una canción suena lenta, no siempre hay que subir solo el BPM.

Hay tres variables importantes:

BPM

Sube o baja la velocidad global.

Steps

Si hay mucho espacio entre eventos, la frase se siente lenta aunque el BPM suba.

Duración

Si las notas sostienen demasiado, el riff puede sentirse pesado o embarrado.

Ejemplo de corrección típica
Caso: suena muy lento

Probar:

subir BPM
acercar los steps
acortar la duración de cierre
Caso: suena apurado

Probar:

bajar BPM
abrir espacios entre steps
dejar más sustain en notas fuertes
Caso: suena feo pero no lento

Probablemente el problema no sea tempo, sino:

pitches mal elegidos
figura musical incorrecta
lane mal distribuido visualmente
demasiado sustain
Ejemplo real: Smoke on the Water

Una versión que quedó bastante bien para testeo fue esta:

#include "smoke_on_the_water.h"

#define SONG_SYNC_OFFSET_STEPS 0

static const ChartEvent smokeOnTheWaterEvents[] =
{
/* Bar 1 */
{0,  0, 4, 196, 294},
{1,  4, 3, 233, 349},
{2,  7, 3, 262, 392},
{0, 12, 4, 196, 294},

/* Bar 2 */
{1, 16, 3, 233, 349},
{2, 19, 3, 277, 415},
{1, 22, 4, 262, 392},

/* Bar 3 */
{0, 28, 4, 196, 294},
{1, 32, 3, 233, 349},
{2, 35, 3, 262, 392},

/* Bar 4 */
{1, 40, 3, 233, 349},
{0, 43, 6, 196, 294}
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
Ejemplo real: canción original de test

Neon Iron Chase se creó como canción original para probar:

estructura de tema más larga
loop más grande
selector de canciones
charting completo sin depender de canciones comerciales

Header correspondiente:

#ifndef NEON_IRON_CHASE_H
#define NEON_IRON_CHASE_H

#include "song.h"

extern const SongChart songNeonIronChase;

#endif
Limitaciones actuales del motor

Hoy el audio funciona como una aproximación retro rock, pero hay límites técnicos.

Lo que sí hace bien
riffs simples
power chords básicos
feedback arcade
testeo de timing
identidad retro tipo prototipo Genesis
Lo que todavía no hace perfecto
guitarra distorsionada convincente
palm mute realista
ataque de púa creíble
timbre FM complejo
sonido tipo producción final
Próximas mejoras posibles
Audio
migrar de PSG básico a algo más parecido a guitarra FM
explorar YM2612 o PCM/XGM
Gameplay
agregar más canciones
agregar dificultad
reinicio rápido de canción
pantalla de resultados
combo / streak
timing ratings (Perfect, Good, Miss)
UI
portada por canción
mejor menú principal
preview visual de selección
iconos por canción
fondo diferente por stage
Buenas prácticas al agregar canciones
no atar el pitch al color
mantener riffs legibles en movimiento
no saturar los tres carriles todo el tiempo
usar duraciones cortas para riffs rápidos
usar duraciones un poco más largas en cierres
testear siempre a oído, no solo mirando números
Regla de oro del proyecto

El chart manda.
No el carril, no el sprite, no el color.

Si el chart está bien armado:

el riff se reconoce
el gameplay se entiende
el sistema escala

Si el chart está mal:

el BPM no lo salva
el timbre no lo salva
el arte no lo salva
Objetivo del proyecto

Construir un juego de ritmo retro estilo Genesis con:

estética arcade rock
charts sencillos pero musicales
arquitectura extensible
soporte para múltiples canciones
base sólida para evolucionar a algo más serio en audio y presentación
Créditos técnicos
Lenguaje: C
SDK: SGDK
Plataforma objetivo: Sega Mega Drive / Genesis
Enfoque visual: pixel art 16-bit
Enfoque musical: riff-driven rhythm gameplay