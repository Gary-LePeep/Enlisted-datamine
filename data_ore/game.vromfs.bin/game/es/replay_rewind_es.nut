import "%dngscripts/ecs.nut" as ecs
let { CmdReplayRewind } = require("dasevents")
let { replay_play, replay_get_play_file } = require("app")
let { currentReplayInfo } = require("%enlSqGlob/replay_state.nut")
let logRPL = require("%enlSqGlob/library_logs.nut").with_prefix("[Replay] ")

ecs.register_es("replay_on_rewind_es",
  {
    [CmdReplayRewind] = function (evt, _eid, comp) {
      if (comp.replay__isRewinding)
        return
      comp.replay__isRewinding = true
      comp.replay__isKeyFrameRewind = true
      let rewindToTime = evt.time / 1000.0
      // Synthesize scene path from mission_name for early unitedVdata limits preload
      let mission_name = currentReplayInfo.value?["mission_name"]
      let synthesizedScene = (mission_name != null) ? $"gamedata/scenes/{mission_name}.blk" : ""
      logRPL($"Rewinding replay to {rewindToTime}")
      try {
        replay_play(currentReplayInfo.value?["path"] ?? replay_get_play_file(), rewindToTime, currentReplayInfo.value?["mod_info"], synthesizedScene)
      } catch (e) { // Note: bw-compat
        replay_play(currentReplayInfo.value?["path"] ?? replay_get_play_file(), rewindToTime, currentReplayInfo.value?["mod_info"])
      }
    },
  },
  {
    comps_rw = [
      ["replay__isRewinding", ecs.TYPE_BOOL],
      ["replay__isKeyFrameRewind", ecs.TYPE_BOOL]
    ],
  }, { tags = "playingReplay" }
)
