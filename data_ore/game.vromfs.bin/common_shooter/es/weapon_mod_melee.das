require ecs

[es(tag=server, on_appear, REQUIRE=weaponMeleeMod, after=melee_item_created_es)]
def melee_mod_attached(evt : Event;
                       slot_attach__attachedTo : EntityId;
                       melee_weapon__propsId : int;
                       melee_weapon__attackAt : float const?;
                       melee_weapon__attackTime : float const?;
                       meleeSoundType : das_string const?)
  let modMeleeProps = melee_weapon__propsId
  let modeAttackAt = melee_weapon__attackAt
  let modeAttackTime = melee_weapon__attackTime
  let modSoundType = meleeSoundType
  query(slot_attach__attachedTo) <| $ [es] (var melee_weapon__propsId : int&;
                                            var melee_weapon__attackAt : float&;
                                            var melee_weapon__attackTime : float&;
                                            var meleeSoundType : das_string&)
    melee_weapon__propsId = modMeleeProps
    melee_weapon__attackAt = modeAttackAt ?? melee_weapon__attackAt
    melee_weapon__attackTime = modeAttackTime ?? melee_weapon__attackTime
    if modSoundType != null
      meleeSoundType := *modSoundType

[es(tag=server, on_disappear, REQUIRE=weaponMeleeMod)]
def melee_mod_destroyed(evt : Event; slot_attach__attachedTo : EntityId)
  query(slot_attach__attachedTo) <| $ [es] (melee_weapon__basePropsId : int;
                                            melee_weapon__baseAttackAt : float;
                                            melee_weapon__baseAttackTime : float;
                                            melee_weapon__baseSoundType : das_string;
                                            var melee_weapon__propsId : int&;
                                            var melee_weapon__attackAt : float&;
                                            var melee_weapon__attackTime : float&;
                                            var meleeSoundType : das_string&)
    melee_weapon__propsId = melee_weapon__basePropsId
    melee_weapon__attackAt = melee_weapon__baseAttackAt
    melee_weapon__attackTime = melee_weapon__baseAttackTime
    meleeSoundType := melee_weapon__baseSoundType

[es(on_appear, REQUIRE=meleeChargeMod, after=melee_item_created_es, track=slot_attach__attachedTo)]
def melee_charge_mod_attached(evt : Event; slot_attach__attachedTo : EntityId)
  if !!slot_attach__attachedTo && !has(slot_attach__attachedTo, "meleeChargeWeapon")
    addSubTemplate(slot_attach__attachedTo, "melee_charge_mod")

[es(on_disappear, REQUIRE=meleeChargeMod)]
def melee_charge_mod_destroyed(evt : Event; slot_attach__attachedTo : EntityId)
  if !!slot_attach__attachedTo && has(slot_attach__attachedTo, "meleeChargeWeapon")
    removeSubTemplate(slot_attach__attachedTo, "melee_charge_mod")

[es(tag=server, on_appear)]
def melee_init_base_props(evt : Event;
                          melee_weapon__propsId : int;
                          var melee_weapon__basePropsId : int&)
  melee_weapon__basePropsId = melee_weapon__propsId

[es(tag=server, on_appear)]
def melee_init_base_time(evt : Event;
                         melee_weapon__attackAt : float;
                         melee_weapon__attackTime : float;
                         var melee_weapon__baseAttackAt : float&;
                         var melee_weapon__baseAttackTime : float&)
  melee_weapon__baseAttackAt = melee_weapon__attackAt
  melee_weapon__baseAttackTime = melee_weapon__attackTime

[es(tag=server, on_appear)]
def melee_init_base_sound(evt : Event;
                          meleeSoundType : das_string;
                          var melee_weapon__baseSoundType : das_string)
  melee_weapon__baseSoundType := meleeSoundType
