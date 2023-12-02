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

const REWIND_CONDITION_ON_FIRE = 1;          // 1 << 0
const REWIND_CONDITION_SOAKED_IN_JARATE = 2; // 1 << 1
const REWIND_COND_COVERED_IN_MILK = 4;       // 1 << 2
const REWIND_COND_UBERED = 8;                // 1 << 3
const REWIND_COND_KRITZED = 16;              // 1 << 4
const REWIND_COND_DUCKING = 131072;          // 1 << 17

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

// TODO(dan.murray): 3D sound is bugged and stacks up
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
    newVelocity.x *= -1.0;
    newVelocity.y *= -1.0;
    newVelocity.z *= -1.0;

    self.Teleport(
        REWIND_POSITION, newOrigin,
        REWIND_ANGLE, newAngle,
        REWIND_VELOCITY, newVelocity);

    local oldHealthChange = r_healthChange[bufferIndex];
    if (oldHealthChange < 0) {
        self.SetHealth(self.GetHealth() + -oldHealthChange);
    }

    if (self.GetCondDuration(Constants.ETFCond.TF_COND_BURNING) != 0) {
        if ((r_conditions[bufferIndex] & REWIND_CONDITION_ON_FIRE) == 0) {
            self.SetCondDuration(Constants.ETFCond.TF_COND_BURNING, 0);
        }
    }

    if (self.GetCondDuration(Constants.ETFCond.TF_COND_URINE) != 0) {
        if ((r_conditions[bufferIndex] & REWIND_CONDITION_SOAKED_IN_JARATE) == 0) {
            self.SetCondDuration(Constants.ETFCond.TF_COND_URINE, 0);
        }
    }

    if (self.GetCondDuration(Constants.ETFCond.TF_COND_MAD_MILK) != 0) {
        if ((r_conditions[bufferIndex] & REWIND_COND_COVERED_IN_MILK) == 0) {
            self.SetCondDuration(Constants.ETFCond.TF_COND_MAD_MILK, 0);
        }
    }

    if (self.GetCondDuration(Constants.ETFCond.TF_COND_INVULNERABLE) == 0) {
        if (r_conditions[bufferIndex] & REWIND_COND_UBERED) {
            self.AddCondEx(Constants.ETFCond.TF_COND_INVULNERABLE, 1, null);
        }
    }

    // TODO(smiley): test this as it doesn't seem to work
    if (self.GetCondDuration(Constants.ETFCond.TF_COND_CRITBOOSTED) == 0) {
        if (r_conditions[bufferIndex] & REWIND_COND_KRITZED) {
            self.AddCondEx(Constants.ETFCond.TF_COND_CRITBOOSTED, 1, null);
        }
    }

    if (r_conditions[bufferIndex] & REWIND_COND_DUCKING) {
        self.AddFlag(Constants.FPlayer.FL_DUCKING);
        NetProps.SetPropBool(self, "m_bDucked", true);
        NetProps.SetPropBool(self, "m_bDucking", true);
    } else {
        self.RemoveFlag(Constants.FPlayer.FL_DUCKING);
        NetProps.SetPropBool(self, "m_bDucked", false);
        NetProps.SetPropBool(self, "m_bDucking", false);
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

    r_conditions[bufferIndex] = 0;

    if (self.GetCondDuration(Constants.ETFCond.TF_COND_BURNING) != 0) {
        r_conditions[bufferIndex] = r_conditions[bufferIndex] | REWIND_CONDITION_ON_FIRE;
    }

    if (self.GetCondDuration(Constants.ETFCond.TF_COND_URINE) != 0) {
        r_conditions[bufferIndex] = r_conditions[bufferIndex] | REWIND_CONDITION_SOAKED_IN_JARATE;
    }

    if (self.GetCondDuration(Constants.ETFCond.TF_COND_MAD_MILK) != 0) {
        r_conditions[bufferIndex] = r_conditions[bufferIndex] | REWIND_COND_COVERED_IN_MILK;
    }

    if (self.GetCondDuration(Constants.ETFCond.TF_COND_INVULNERABLE) != 0) {
        r_conditions[bufferIndex] = r_conditions[bufferIndex] | REWIND_COND_UBERED;
    }

    // TODO(smiley): test this as it doesn't seem to work
    if (self.GetCondDuration(Constants.ETFCond.TF_COND_CRITBOOSTED) != 0) {
        r_conditions[bufferIndex] = r_conditions[bufferIndex] | REWIND_COND_KRITZED;
    }

    if (self.GetFlags() & Constants.FPlayer.FL_DUCKING) {
        r_conditions[bufferIndex] = r_conditions[bufferIndex] | REWIND_COND_DUCKING;
    }

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

    local playerScriptScope = player.GetScriptScope();

    playerScriptScope.r_isRewinding <- 0;

    playerScriptScope.r_numValidFramesBuffered <- 0

    playerScriptScope.r_bufferIndex <- 0;

    playerScriptScope.r_position <- [];
    for (local i = 0; i < NUM_FRAMES_TO_BUFFER; i++) {
        playerScriptScope.r_position.append(Vector(0, 0, 0));
    }

    playerScriptScope.r_angle <- [];
    for (local i = 0; i < NUM_FRAMES_TO_BUFFER; i++) {
        playerScriptScope.r_angle.append(QAngle(0, 0, 0));
    }

    playerScriptScope.r_velocity <- [];
    for (local i = 0; i < NUM_FRAMES_TO_BUFFER; i++) {
        playerScriptScope.r_velocity.append(Vector(0, 0, 0));
    }

    playerScriptScope.r_currentHealth <- player.GetHealth();

    playerScriptScope.r_healthDelta <- 0;

    playerScriptScope.r_healthChange <- [];
    for (local i = 0; i < NUM_FRAMES_TO_BUFFER; i++) {
        playerScriptScope.r_healthChange.append(0);
    }

    playerScriptScope.r_conditions <- [];
    for (local i = 0; i < NUM_FRAMES_TO_BUFFER; i++) {
        playerScriptScope.r_conditions.append(0);
    }

    AddThinkToEnt(player, "PlayerThink");
}

__CollectGameEventCallbacks(this);

