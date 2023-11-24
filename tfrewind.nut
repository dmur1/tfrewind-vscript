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

const NUM_FRAMES_TO_CONSUME_ON_REWIND = 75;
const NUM_FRAMES_TO_BUFFER = 425;

const REWIND_POSITION = true;
const REWIND_ANGLE = false;
const REWIND_VELOCITY = true;

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

    r_bufferIndex = bufferIndex;

    r_numValidFramesBuffered -= 1;
}

function CaptureState() {
    local bufferIndex = r_bufferIndex;

    r_position[bufferIndex] = self.GetOrigin();

    r_angle[bufferIndex] = self.GetAbsAngles();

    r_velocity[bufferIndex] = self.GetAbsVelocity();

    r_bufferIndex = (bufferIndex + 1) % NUM_FRAMES_TO_BUFFER;

    if (r_numValidFramesBuffered < NUM_FRAMES_TO_BUFFER) {
        r_numValidFramesBuffered += 1;
    }

    if (r_numValidFramesBuffered == NUM_FRAMES_TO_BUFFER) {
        // ready to rewind!
    }
}

function PlayerThink() {
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

    printf("player spawned!");

    player.ValidateScriptScope();

    player.GetScriptScope().r_isRewinding <- 0

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

    player.GetScriptScope().r_velocity <- []
    for (local i = 0; i < NUM_FRAMES_TO_BUFFER; i++) {
        player.GetScriptScope().r_velocity.append(Vector(0, 0, 0));
    }

    AddThinkToEnt(player, "PlayerThink");
}

__CollectGameEventCallbacks(this);

