/*
 * Copyright (c) 2023, Daniel Murray ( smiley )
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// tfrewind.nut
const VERSION = "0.0.1";

// based on https://github.com/dmur1/tfrewind/blob/main/tfrewind.sm

::MaxPlayers <- MaxClients().tointeger();

const NUM_FRAMES_TO_CONSUME_ON_REWIND = 75;
const NUM_FRAMES_TO_BUFFER = 425;

const REWIND_POSITION = true;
const REWIND_ANGLE = false;
const REWIND_VELOCITY = true;

const SOUND_UI_READY_TO_REWIND_1 = "player/recharged.wav";
const SOUND_UI_READY_TO_REWIND_2 = "ui/cyoa_map_open.wav";
const SOUND_UI_START_REWIND = "ui/buttonclick.wav";
const SOUND_WORLD_START_REWIND_1 = "weapons/bumper_car_decelerate.wav";
const SOUND_WORLD_START_REWIND_2 = "weapons/loch_n_load_dud.wav";

PrecacheScriptSound(SOUND_UI_READY_TO_REWIND_1);
PrecacheScriptSound(SOUND_UI_READY_TO_REWIND_2);
PrecacheScriptSound(SOUND_UI_START_REWIND);
PrecacheScriptSound(SOUND_WORLD_START_REWIND_1);
PrecacheScriptSound(SOUND_WORLD_START_REWIND_2);

function PlaySound2D(sound) {
    EmitSoundEx({
        sound_name = sound,
        entity = self,
        filter_type = Constants.EScriptRecipientFilter.RECIPIENT_FILTER_SINGLE_PLAYER
    });
}

function PlaySound3D(sound) {
    for (local i = 1; i <= MaxPlayers; i++) {
       local player = PlayerInstanceFromIndex(i);
       if (player == null)
          continue;

       EmitSoundEx({
            sound_name = sound,
            entity = self,
            origin = player.GetOrigin(),
            filter_type = Constants.EScriptRecipientFilter.RECIPIENT_FILTER_GLOBAL
        });
    }
}

function StartRewindFX() {
    PlaySound2D(SOUND_UI_START_REWIND);
    PlaySound3D(SOUND_WORLD_START_REWIND_1);
    PlaySound3D(SOUND_WORLD_START_REWIND_2);

    self.AddCondEx(Constants.ETFCond.TF_COND_TELEPORTED, 1, null);
}

function UpdateHealth() {
    local health = self.GetHealth();
    local healthDelta = health - r_currentHealth;
    r_currentHealth = health;
    r_healthDelta = healthDelta;
}

function ShouldRewind() {
    local buttons = NetProps.GetPropInt(self, "m_nButtons");
    if (!(buttons & Constants.FButtons.IN_RELOAD)) {
        r_isRewinding = 0;
        return;
    }

    if (r_numValidFramesBuffered == 0) {
        r_isRewinding = 0;
        return;
    }

    if (r_isRewinding == 0) {
        if (r_numValidFramesBuffered != NUM_FRAMES_TO_BUFFER) {
            return;
        }

        r_isRewinding = 1
        r_numValidFramesBuffered -= NUM_FRAMES_TO_CONSUME_ON_REWIND;

        StartRewindFX();
    }
}

function Rewind() {
    local bufferIndex = r_bufferIndex - 1;
    if (bufferIndex < 0) {
        bufferIndex += NUM_FRAMES_TO_BUFFER;
    }

    local newOrigin = r_position[bufferIndex];

    local newAngle = r_angle[bufferIndex];

    local newVelocity = r_velocity[bufferIndex];

    self.Teleport(
        REWIND_POSITION, newOrigin,
        REWIND_ANGLE, newAngle,
        REWIND_VELOCITY, newVelocity);

    local oldHealthChange = r_healthChange[bufferIndex];
    if (oldHealthChange < 0) {
        self.SetHealth(self.GetHealth() + -oldHealthChange);
    }

    r_bufferIndex = bufferIndex;

    r_numValidFramesBuffered -= 1;

    self.SetCondDuration(Constants.ETFCond.TF_COND_TELEPORTED, 1);
}

function ReadyToRewindFX() {
    ClientPrint(self, 3, "READY TO REWIND");

    PlaySound2D(SOUND_UI_READY_TO_REWIND_1);
    PlaySound2D(SOUND_UI_READY_TO_REWIND_2);
}

function CaptureState() {
    local bufferIndex = r_bufferIndex;

    r_position[bufferIndex] = self.GetOrigin();

    r_angle[bufferIndex] = self.GetAbsAngles();

    r_velocity[bufferIndex] = self.GetAbsVelocity();

    r_healthChange[bufferIndex] = r_healthDelta;

    r_bufferIndex = (bufferIndex + 1) % NUM_FRAMES_TO_BUFFER;

    if (r_numValidFramesBuffered < NUM_FRAMES_TO_BUFFER) {
        r_numValidFramesBuffered += 1;

        if (r_numValidFramesBuffered == NUM_FRAMES_TO_BUFFER) {
            ReadyToRewindFX();
        }
    }
}

function PlayerThink() {
    UpdateHealth();

    ShouldRewind();

    if (r_isRewinding == 1) {
        Rewind();
    } else {
        CaptureState();
    }

    return -1;
}

function OnGameEvent_player_spawn(params) {
    local player = GetPlayerFromUserID(params.userid);
    if (!player)
        return;

    player.ValidateScriptScope();

    player.GetScriptScope().r_isRewinding <- 0;

    player.GetScriptScope().r_numValidFramesBuffered <- 0

    player.GetScriptScope().r_bufferIndex <- 0;

    player.GetScriptScope().r_position <- [];
    for (local i = 0; i < NUM_FRAMES_TO_BUFFER; i++) {
        player.GetScriptScope().r_position.append(Vector(0, 0, 0));
    }

    player.GetScriptScope().r_angle <- [];
    for (local i = 0; i < NUM_FRAMES_TO_BUFFER; i++) {
        player.GetScriptScope().r_angle.append(QAngle(0, 0, 0));
    }

    player.GetScriptScope().r_velocity <- [];
    for (local i = 0; i < NUM_FRAMES_TO_BUFFER; i++) {
        player.GetScriptScope().r_velocity.append(Vector(0, 0, 0));
    }

    player.GetScriptScope().r_currentHealth <- player.GetHealth();

    player.GetScriptScope().r_healthDelta <- 0;

    player.GetScriptScope().r_healthChange <- [];
    for (local i = 0; i < NUM_FRAMES_TO_BUFFER; i++) {
        player.GetScriptScope().r_healthChange.append(0);
    }

    AddThinkToEnt(player, "PlayerThink");
}

__CollectGameEventCallbacks(this);

