require ecs
require soundEvent


[es(tag=sound, track=sound_banks_state__isPresetLoaded, after=sound_effect_init)]
def occluded_sound_effect_init(evt : Event;
                               sound_banks_state__isPresetLoaded : bool;
                               sound_control__range : float;
                               occluded_sound__rangeMul : float;
                               occluded_sound__nearFarAttenuation : float2;
                               var occluded_sound__nearFarRange : float2&)
  if sound_banks_state__isPresetLoaded
    occluded_sound__nearFarRange = occluded_sound__nearFarAttenuation * (sound_control__range * occluded_sound__rangeMul)


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=(sound_occlusion_update, sound_begin_update_es), before=sound_end_update_es)]
def occluded_sound_effect_update(evt : Event;
                                 sound_effect__event : SoundEvent;
                                 occluded_sound__volume : float)
  set_volume(sound_effect__event.handle, occluded_sound__volume)
