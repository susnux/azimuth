/*=============================================================================
| Copyright 2012 Matthew D. Steele <mdsteele@alum.mit.edu>                    |
|                                                                             |
| This file is part of Azimuth.                                               |
|                                                                             |
| Azimuth is free software: you can redistribute it and/or modify it under    |
| the terms of the GNU General Public License as published by the Free        |
| Software Foundation, either version 3 of the License, or (at your option)   |
| any later version.                                                          |
|                                                                             |
| Azimuth is distributed in the hope that it will be useful, but WITHOUT      |
| ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or       |
| FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for   |
| more details.                                                               |
|                                                                             |
| You should have received a copy of the GNU General Public License along     |
| with Azimuth.  If not, see <http://www.gnu.org/licenses/>.                  |
=============================================================================*/

#include "azimuth/view/victory.h"

#include <math.h>
#include <stdbool.h>

#include <GL/gl.h>

#include "azimuth/constants.h"
#include "azimuth/state/save.h"
#include "azimuth/util/audio.h"
#include "azimuth/util/color.h"
#include "azimuth/util/clock.h"
#include "azimuth/util/misc.h"
#include "azimuth/view/baddie.h"
#include "azimuth/view/cutscene.h"
#include "azimuth/view/particle.h"
#include "azimuth/view/projectile.h"
#include "azimuth/view/string.h"
#include "azimuth/view/util.h"

/*===========================================================================*/

static const struct {
  int step, x, y;
  const char *title, *name;
} TITLES[] = {
  {.step = AZ_VS_SNAPDRAGON, .x = 250, .y = 100,
   .title = "Extradimensional Fingers", .name = "OTH SNAPDRAGON"},
  {.step = AZ_VS_ROCKWYRM, .x = 390, .y = 350,
   .title = "Colossal Armored Annelid", .name = "ROCKWYRM"},
  {.step = AZ_VS_GUNSHIP, .x = 250, .y = 310,
   .title = "Extradimensional Mimic", .name = "OTH GUNSHIP"},
  {.step = AZ_VS_FORCEFIEND, .x = 390, .y = 100,
   .title = "Hydrokinetic Leviathan", .name = "FORCEFIEND"},
  {.step = AZ_VS_KILOFUGE, .x = 250, .y = 100,
   .title = "Behemoth Arachnid", .name = "KILOFUGE"},
  {.step = AZ_VS_NOCTURNE, .x = 390, .y = 340,
   .title = "Invisible Brood Lord", .name = "NOCTURNE"},
  {.step = AZ_VS_MAGBEEST, .x = 250, .y = 310,
   .title = "Electromagnetic Harvester", .name = "MAGBEEST"},
  {.step = AZ_VS_SUPERGUNSHIP, .x = 390, .y = 100,
   .title = "Extradimensional Nemesis", .name = "OTH SUPERGUNSHIP"},
  {.step = AZ_VS_CORE, .x = 320, .y = 380,
   .title = "Heart of the Planet", .name = "ZENITH CORE"},
};

static const struct {
  int step, x, y;
  const char *heading, *name1, *name2;
} CREDITS[] = {
  {.step = AZ_VS_SNAPDRAGON, .x = 150, .y = 360,
   .heading = "BETA TESTERS", .name1 = "Lorem Ipsum", .name2 = "Jane Doe"},
  {.step = AZ_VS_ROCKWYRM, .x = 180, .y = 120,
   .heading = "BETA TESTERS", .name1 = "Alan Smithee", .name2 = "Anony Moose"},
  {.step = AZ_VS_GUNSHIP, .x = 150, .y = 130,
   .heading = "BETA TESTERS", .name1 = "Some One", .name2 = "Know Body"},
  {.step = AZ_VS_FORCEFIEND, .x = 120, .y = 380,
   .heading = "BETA TESTERS", .name1 = "Set Us", .name2 = "Up The Bomb"},
  {.step = AZ_VS_KILOFUGE, .x = 150, .y = 380,
   .heading = "BETA TESTERS", .name1 = "Dolor Sit Amet", .name2 = "Whatever"},
  {.step = AZ_VS_NOCTURNE, .x = 480, .y = 80,
   .heading = "BETA TESTERS", .name1 = "Temporary", .name2 = "Fake Names"},
  {.step = AZ_VS_MAGBEEST, .x = 550, .y = 315,
   .heading = "BETA TESTERS", .name1 = "Put Something", .name2 = "Real Here"},
  {.step = AZ_VS_SUPERGUNSHIP, .x = 450, .y = 380,
   .heading = "BETA TESTERS", .name1 = "Eventually", .name2 = "Anyway"},
  {.step = AZ_VS_CORE, .x = 320, .y = 60,
   .heading = "SPECIAL THANKS", .name1 = "Someone Special", .name2 = ""},
};

static void tint_screen(az_color_t color) {
  glBegin(GL_TRIANGLE_FAN); {
    az_gl_color(color);
    glVertex2i(0, 0);
    glVertex2i(AZ_SCREEN_WIDTH, 0);
    glVertex2i(AZ_SCREEN_WIDTH, AZ_SCREEN_HEIGHT);
    glVertex2i(0, AZ_SCREEN_HEIGHT);
  } glEnd();
}

static void draw_baddies(const az_victory_state_t *state, bool background) {
  AZ_ARRAY_LOOP(baddie, state->baddies) {
    if (baddie->kind == AZ_BAD_NOTHING) continue;
    if (az_baddie_has_flag(baddie, AZ_BADF_DRAW_BG) != background) continue;
    glPushMatrix(); {
      az_draw_baddie(baddie, state->clock);
    } glPopMatrix();
  }
}

static void draw_particles(const az_victory_state_t *state) {
  AZ_ARRAY_LOOP(particle, state->particles) {
    if (particle->kind == AZ_PAR_NOTHING) continue;
    glPushMatrix(); {
      az_gl_translated(particle->position);
      az_gl_rotated(particle->angle);
      az_draw_particle(particle, state->clock);
    } glPopMatrix();
  }
}

static void draw_projectiles(const az_victory_state_t *state) {
  AZ_ARRAY_LOOP(proj, state->projectiles) {
    if (proj->kind == AZ_PROJ_NOTHING) continue;
    glPushMatrix(); {
      az_gl_translated(proj->position);
      az_gl_rotated(proj->angle);
      az_draw_projectile(proj, state->clock);
    } glPopMatrix();
  }
}

static void draw_fade_text(const az_victory_state_t *state, int height,
                           int x, int y, double begin_at, const char *text) {
  const double fade_time = 0.5;
  const double end_at = begin_at + 4.0;
  if (state->step_timer <= begin_at || state->step_timer >= end_at) return;
  glColor4f(0.5f, 1.0f, (height == 8 ? 0.5f : 1.0f), fmin(1,
      fmin((state->step_timer - begin_at),
           (end_at - state->step_timer)) / fade_time));
  az_draw_string(height, AZ_ALIGN_CENTER, x, y, text);
}

void az_victory_draw_screen(const az_victory_state_t *state) {
  az_draw_planet_starfield(state->clock);

  glPushMatrix(); {
    // Make positive Y be up instead of down.
    glScaled(1, -1, 1);
    // Center the screen on position (0, 0).
    glTranslated(AZ_SCREEN_WIDTH/2, -AZ_SCREEN_HEIGHT/2, 0);
    // Draw objects:
    draw_baddies(state, true); // background
    draw_projectiles(state);
    draw_baddies(state, false); // foreground
    draw_particles(state);
  } glPopMatrix();

  if ((state->step == AZ_VS_CORE || state->step == AZ_VS_CORE + 1) &&
      state->step_timer <= 0.75) {
    tint_screen((az_color_t){255, 255, 255,
                             255 * (1 - state->step_timer / 0.75)});
  }

  AZ_ARRAY_LOOP(title, TITLES) {
    if (state->step != title->step) continue;
    draw_fade_text(state, 16, title->x, title->y, 0.0, title->title);
    draw_fade_text(state, 24, title->x, title->y + 40, 0.5, title->name);
  }

  AZ_ARRAY_LOOP(credit, CREDITS) {
    if (state->step != credit->step) continue;
    draw_fade_text(state, 8, credit->x, credit->y, 1.25, credit->heading);
    draw_fade_text(state, 8, credit->x, credit->y + 20, 1.5, credit->name1);
    draw_fade_text(state, 8, credit->x, credit->y + 40, 1.75, credit->name2);
  }

  if (state->step == AZ_VS_DONE) {
    glColor3f(0.5, 1, 1);
    const int total_seconds = (int)state->clear_time;
    const int hours = total_seconds / 3600;
    const int minutes = (total_seconds % 3600) / 60;
    const int seconds = total_seconds % 60;
    az_draw_printf(16, AZ_ALIGN_CENTER, AZ_SCREEN_WIDTH/2, 190,
                   "Clear time: %d:%02d:%02d", hours, minutes, seconds);
    az_draw_printf(16, AZ_ALIGN_CENTER, AZ_SCREEN_WIDTH/2, 290,
                   "Items collected: %d%%", state->percent_completion);
  }
}

/*===========================================================================*/