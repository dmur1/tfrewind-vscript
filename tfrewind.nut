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

function Rewind() {
    local bufferIndex = rewindBufferIndex - 1;
    if (bufferIndex < 0) {
        bufferIndex += NUM_FRAMES_TO_BUFFER;
    }

    local newOrigin = rewindPositions[bufferIndex];

    self.Teleport(true, newOrigin, false, QAngle(0, 0, 0), false, Vector(0, 0, 0));

    rewindBufferIndex = bufferIndex;
}

function CaptureState() {
    local bufferIndex = rewindBufferIndex;

    rewindPositions[bufferIndex] = self.GetOrigin();

    rewindBufferIndex = (bufferIndex + 1) % NUM_FRAMES_TO_BUFFER;
}

function PlayerThink() {
    rewindIsRewinding = 0;

    local buttons = NetProps.GetPropInt(self, "m_nButtons");
    if (buttons & Constants.FButtons.IN_RELOAD) {
        rewindIsRewinding = 1
    }

    if (rewindIsRewinding == 1) {
        Rewind();
    } else {
        CaptureState();
    }
}

function OnGameEvent_player_spawn(params) {
    local player = GetPlayerFromUserID(params.userid);
    if (!player)
        return;

    printf("player spawned!");

    player.ValidateScriptScope();

    player.GetScriptScope().rewindIsRewinding <- 0

    player.GetScriptScope().rewindBufferIndex <- 0;

    player.GetScriptScope().rewindPositions <- [];
    for (local i = 0; i < NUM_FRAMES_TO_BUFFER; i++) {
        player.GetScriptScope().rewindPositions.append(Vector(0, 0, 0));
    }

    AddThinkToEnt(player, "PlayerThink");
}

__CollectGameEventCallbacks(this);

