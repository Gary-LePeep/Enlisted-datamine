from "%enlSqGlob/ui/ui_library.nut" import *

let JB = require("%ui/control/gui_buttons.nut")
let canDisplayOffers = require("%enlist/canDisplayOffers.nut")
let getPayItemsData = require("%enlist/soldiers/model/getPayItemsData.nut")

let { curArmy, curCampItems } = require("%enlist/soldiers/model/state.nut")
let { isGamepad } = require("%ui/control/active_controls.nut")
let { airSelectedBgColor } = require("%enlSqGlob/ui/designConst.nut")
let { mkHorizontalSlot } = require("%enlist/soldiers/chooseSquadsSlots.nut")
let { jumpToArmyGrowth } = require("%enlist/mainMenu/sectionsState.nut")
let { isInSquad } = require("%enlist/squad/squadManager.nut")
let { dbgShow } = require("%enlist/debriefing/debriefingDbgState.nut")
let { show } = require("%enlist/debriefing/debriefingStateInMenu.nut")
let { viewCurrencies } = require("%enlist/shop/armyShopState.nut")
let { hasMsgBoxes } = require("%enlist/components/msgbox.nut")
let { hasModalWindows } = require("%ui/components/modalWindows.nut")
let { debounce } = require("%sqstd/timers.nut")

let {
  openChooseSquadsWnd, closeChooseSquadsWnd, applyAndClose, chosenSquads,
  reserveSquads, changeList, moveIndex, selectedSquadId, findLastIndexToTakeSquad
} = require("%enlist/soldiers/model/chooseSquadsState.nut")
let {
  isUnlockSquadSceneVisible, closeUnlockSquadScene, unlockSquadViewData
} = require("%enlist/soldiers/unlockSquadScene.nut")
let {
  setTutorialConfig, finishTutorial, goToStep, isTutorialActive, nextStep
} = require("%enlist/tutorial/tutorialWndState.nut")
let {
  mkSizeTable, mkMessageCtorWithGamepadIcons
} = require("%enlist/tutorial/tutorialWndDefStyle.nut")
let {
  isGrowthVisible, curGrowthState, curGrowthConfig, growthConfig,
  callGrowthPurchase, GrowthStatus
} = require("%enlist/growth/growthState.nut")


const SILVER_ID = "enlisted_silver"
const GROWTH_PROGRESS = "GROWTH"


let growthWithoutTutorial = Computed(function() {
  let res = {}
  foreach(armyCfg in growthConfig.value)
    foreach(cfg in armyCfg)
      if (cfg?.isAutoRewarded ?? false)
        res[cfg.id] <- true
  return res
})

let growthWithSquads = Computed(function() {
  let res = {}
  foreach (armyGrowth in growthConfig.value)
    foreach (growth in armyGrowth) {
      let { id, reward = null } = growth
      let { squadId = "" } = reward
      if (squadId != "")
        res[id] <- squadId
    }
  return res
})

let curGrowthGuidToPurchase = Computed(function() {
  let configs = curGrowthConfig.value
  let squadLinks = growthWithSquads.value
  let excluded = growthWithoutTutorial.value
  let states = curGrowthState.value
  if (states.findvalue(@(g) g.status == GrowthStatus.REWARDED
      && g.guid in squadLinks
      && g.guid not in excluded) != null)
    return null

  let silverHave = viewCurrencies.value?[SILVER_ID] ?? 0
  return states.findindex(function(g) {
    if (g.status != GrowthStatus.PURCHASABLE)
      return false
    let { rewardCost = 0, reward = null } = configs?[g.guid]
    let { squadId = "" } = reward
    return squadId != "" && rewardCost < silverHave
  })
})

let needTutorial = Computed(@()
  isInSquad.value || show.value || dbgShow.value ? false
    : curGrowthGuidToPurchase.value != null)


let canContinueGrowthTutorial = Computed(@() isGrowthVisible.value
  && !hasMsgBoxes.value
  && !hasModalWindows.value)

let showTutorial = keepref(Computed(@()
  needTutorial.value && (canContinueGrowthTutorial.value || canDisplayOffers.value)))

let newReceivedSquadId = Watched(null)

function openSquadManage() {
  if (unlockSquadViewData.value == null)
    return

  let { armyId, squadCfg } = unlockSquadViewData.value
  closeUnlockSquadScene()
  closeChooseSquadsWnd() //only for debug from the middle of tutorial. In the full tutorial it do nothing
  newReceivedSquadId(squadCfg.id)
  openChooseSquadsWnd(armyId, squadCfg.id, true)
}

let getSquadKey = @(squad, idx) squad == null ? $"empty_slot{idx}" : $"slot{squad.guid}{idx}"

function moveReserveSquadToActive(idx) {
  let squadId = newReceivedSquadId.value ?? reserveSquads.value?[0].squadId
  if (chosenSquads.value?[idx] != null) {
    selectedSquadId(chosenSquads.value?[idx].squadId)
    changeList()
  }
  selectedSquadId(squadId)
  changeList()
}

let mkDropSquadSlot = @(box, idx, squad) mkSizeTable(box, {
  rendObj = ROBJ_SOLID,
  color = 0xF0000000
  children = squad == null ? null
    : [
        mkHorizontalSlot(squad.__merge({
          idx
          fixedSlots = chosenSquads.value.len()
          onClick = @() null
          onInfoCb = null
          onDropCb = @(_, __) null
        }), KWARG_NON_STRICT)
        {
          size = flex()
          rendObj = ROBJ_BOX
          borderWidth = hdpx(1)
        }
      ]
})

let mkDropTarget = @(box, onDrop) watchElemState(@(sf) mkSizeTable(box, {
  behavior = Behaviors.DragAndDrop
  onDrop
  rendObj = ROBJ_BOX
  fillColor = sf & S_ACTIVE? airSelectedBgColor : 0
  borderWidth = hdpx(1)
}))


function tryGetReward() {
  let growthGuid = curGrowthGuidToPurchase.value
  if (growthGuid == null)
    return false

  let growthCfg = curGrowthConfig.value?[growthGuid]
  if (growthCfg == null)
    return false

  let { id, rewardCost = 0 } = growthCfg
  if (rewardCost == 0)
    return false

  let buyInfo = getPayItemsData({ [SILVER_ID] = rewardCost }, curCampItems.value)
  if (buyInfo == null)
    return false

  callGrowthPurchase(curArmy.value, id, buyInfo)
  return true
}


function startTutorial() {
  let chosenSquadsKeys = Computed(@() chosenSquads.value.map(getSquadKey))
  let reserveSquadsKeys = Computed(@() reserveSquads.value.map(
    @(s, idx) "guid" in s ? getSquadKey(s, idx + chosenSquads.value.len()) : null ))
  let newReceivedIdxInReserve = Computed(@() reserveSquads.value.findindex(@(s) s.squadId == newReceivedSquadId.value) ?? 0)
  let newReceivedKeyInReserve = Computed(@() reserveSquadsKeys.value?[newReceivedIdxInReserve.value])
  let newSquadIdx = Watched(-1)
  let newSquadKey = Computed(@() newSquadIdx.value < 0 ? null : getSquadKey(chosenSquads.value?[newSquadIdx.value], newSquadIdx.value))

  setTutorialConfig({
    id = "newGrowthSquad"
    onStepStatus = @(_stepId, _status) null
    steps = [
      //********************** Main menu window *********************
      {
        id = "w0s1_check_growth_squad_rewards"
        nextStepAfter = isGrowthVisible
        text = loc("tutorial_open_growth_window")
        objects = [{
          keys = [GROWTH_PROGRESS]
          sizeIncAdd = hdpx(5)
          onClick = @() jumpToArmyGrowth(curGrowthGuidToPurchase.value)
          needArrow = true
          hotkey = $"^{JB.A}"
        }]
      }
      {
        id = "w0s2_wait_growth_opening"
        nextStepAfter = isGrowthVisible
        objects = []
      }
      //******************** Growth window ********************
      {
        id = "w1s1_completed_growth"
        nextKeyDelay = -1
        text = loc("tutorial_growth_reward")
        objects = [{ keys = $"growth_{curGrowthGuidToPurchase.value}", needArrow = true }]
      }
      {
        id = "w1s2_completed_growth"
        text = loc("tutorial_growth_buy_reward")
        function onSkip() {
          if (tryGetReward())
            goToStep("w1s3_wait_for_get_squad")
          return true
        }
        objects = [{
          keys = "growth_action_button"
          needArrow = true
          ctor = @(box) mkSizeTable(box, {
            behavior = Behaviors.Button
            hotkeys = [ ["^J:X", { description = { skip = true }, sound = "click"}] ]
            function onClick() {
              if (tryGetReward())
                goToStep("w1s3_wait_for_get_squad")
              return true
            }
          })
        }]
      }
      {
        id = "w1s3_wait_for_get_squad"
        nextStepAfter = isUnlockSquadSceneVisible
        text = loc("xbox/waitingMessage")
        objects = [{ keys = "squadReadyToUnlock", onClick = @() true }]
      }
      //******************** new squad received window ********************
      {
        id = "w2s1_new_squad_received_window"
        objects = [{
          keys = "unlockSquadScene"
          ctor = @(box) mkSizeTable(box, {
            behavior = Behaviors.Button
            onClick = @() null
          })
        }]
        beforeStart = @() gui_scene.setTimeout(2.5, nextStep)
      }
      {
        id = "w2s2_press_manage_squad_btn"
        text = loc("tutorial_meta_add_new_squad")
        objects = [{
          keys = "SquadManageBtnInSquadPromo"
          onClick = @() openSquadManage()
          hotkey = "^J:X"
          needArrow = true
        }]
      }
      //******************** manage squad window ********************
      {
        id = "w3s1_battle_squads_info"
        text = loc("tutorial_meta_squad_menu_intro_01")
        nextKeyDelay = -1
        objects = [{ keys = chosenSquadsKeys }]
      }
      {
        id = "w3s2_reserve_squads_info"
        text = loc("tutorial_meta_squad_menu_intro_02")
        nextKeyDelay = -1
        objects = [{ keys = reserveSquadsKeys }]
      }
      {
        id = "w3s3_change_squads_info"
        text = Computed(@() loc(isGamepad.value ? "tutorial_meta_squad_menu_how_to_change_gamepad"
          : "tutorial_meta_squad_menu_how_to_change_mouse"))
        textCtor = mkMessageCtorWithGamepadIcons(["J:LB", "J:RB"])
        nextKeyDelay = -1
        objects = [
          { keys = chosenSquadsKeys }
          { keys = Computed(@() ["dropToReserveSquad"].extend(reserveSquadsKeys.value)) }
          { keys = ["manageSquadsBtnUp", "manageSquadsBtnDown", "manageSquadsBtnLeft", "manageSquadsBtnRight"] }
        ]
      }
      {
        id = "w3s4_move_new_squad_to_active"
        text = Computed(@() loc("{0}/{1}".subst(
            isGamepad.value ? "tutorial_meta_squad_menu_choose_squad_by_gamepad" : "tutorial_meta_squad_menu_drag_squad",
            chosenSquads.value.findindex(@(s) s == null) == null ? "last" : "empty")))
        textCtor = mkMessageCtorWithGamepadIcons(["J:LB"])
        beforeStart = @() reserveSquads.value.len() == 0 ? null
          : newSquadIdx(findLastIndexToTakeSquad(reserveSquads.value[newReceivedIdxInReserve.value]))
        arrowLinks = [[0, 2], [1, 2]]
        objects = [
          //gamepad only
          { keys = Computed(@() isGamepad.value ? newReceivedKeyInReserve.value : null)
            hotkey = "^J:LB"
            function onClick() {
              moveReserveSquadToActive(newSquadIdx.value)
              defer(nextStep) //wait for scene update after change.
              return true
            }
          }
          //mouse only
          { keys = Computed(@() isGamepad.value ? null : newReceivedKeyInReserve.value)
            ctor = @(box) mkDropSquadSlot(box, chosenSquads.value.len(), reserveSquads.value?[newReceivedIdxInReserve.value])
          }
          //gamepad and mouse
          { keys = newSquadKey
            ctor = @(box) mkDropTarget(box,
              function onDrop(_) {
                moveReserveSquadToActive(newSquadIdx.value)
                gui_scene.setTimeout(0.1, nextStep) //wait for scene update after change.
              })
          }
        ]
      }
      {
        id = "w3s5_move_squad_to_first"
        text = loc("tutorial_meta_squad_menu_place_squad_1st")
        textCtor = mkMessageCtorWithGamepadIcons(["J:Y"])
        beforeStart = @() newSquadIdx.value > 0 ? null : defer(nextStep)
        arrowLinks = [[1, 2]]
        objects = [
          //gamepad only
          { keys = Computed(@() isGamepad.value ? newSquadKey.value : null)
            hotkey = "^J:Y"
            function onClick() {
              if (newSquadIdx.value > 0) {
                let idx = newSquadIdx.value
                newSquadIdx(idx - 1)
                chosenSquads(moveIndex(chosenSquads.value, idx, idx - 1))
              }
              return newSquadIdx.value > 0
            }
            needArrow = true
          }
          //mouse only
          { keys = Computed(@() isGamepad.value ? null : newSquadKey.value)
            ctor = @(box) mkDropSquadSlot(box, newSquadIdx.value, chosenSquads.value?[newSquadIdx.value])
          }
          {
            keys = Computed(@() isGamepad.value ? null : getSquadKey(chosenSquads.value?[0], 0))
            onClick = @() true
            ctor = @(box) mkDropTarget(box,
              function onDrop(_) {
                chosenSquads(moveIndex(chosenSquads.value, newSquadIdx.value, 0))
                nextStep()
              })
          }
        ]
        function onSkip() {
          if (newSquadIdx.value in chosenSquads.value) {
            chosenSquads(moveIndex(chosenSquads.value, newSquadIdx.value, 0))
            return false
          }
          finishTutorial()
          return true
        }
      }
      {
        id = "w3s6_show_result"
        beforeStart = @() gui_scene.setTimeout(1.0, nextStep)
        onFinish = @() gui_scene.clearTimer(nextStep)
        objects = [{ keys = Computed(@() getSquadKey(chosenSquads.value?[0], 0)) }]
      }
      {
        id = "w3s7_final"
        text = loc("tutorial_meta_squad_menu_leave")
        textCtor = mkMessageCtorWithGamepadIcons([JB.B])
        objects = [{ keys = "closeSquadsManage", hotkey = $"^{JB.B}", needArrow = true }]
        onFinish = applyAndClose
      }
    ]
  })
}


let startTutorialDelayed = debounce(function() {
  if (showTutorial.value && !isTutorialActive.value)
    startTutorial()
}, 0.3)

showTutorial.subscribe(@(v) v ? startTutorialDelayed() : null)
startTutorialDelayed()

console_register_command(startTutorial, "tutorial.startArmyLevel")
