/*
Usage:

  local handlers  = {}
  local executors = {}
  local client    = CharClientEvent({handlers, executors, ...})

  client.request("action1")                // send action
  client.request("action1", {foo = bar})   // send action with parameters
  handlers["action1"] <- function(result)  // accept result

Multiple handlers for one action:

  client.request("action2:foo")
  handlers["action2:foo"] <- function(result)
  handlers["action2:bar"] <- function(result)

Handler parameters in context:

  client.request("action3", {...}, {foo = bar})
  handlers["action3"] <- function(result, context) { local foo = context?.foo }

External custom executors:
  client.request("action4", {...}, {executeBefore="foo", executeAfter="bar"})
  handlers["action4"] <- function(result)
  executors["foo"] <- function(result)

Handler and executor behavior should depend only on result from server and context.
Script reload can occur between request and handler.
*/

let {get_app_id} = require("app")
let {debug}      = require("dagor.debug")
let { eventbus_subscribe }     = require("eventbus")
let userInfo     = require("%enlSqGlob/userInfo.nut")
let utils        = require("charClientUtils.nut")
//#strict


function CharClientEvent(settings) {

  let name         = settings?.name
  let event        = settings?.event ?? $"charclient.{name}"
  local mode         = settings?.mode  ?? "eventbus"
  let client       = settings?.client     // native client module
  let handlers     = settings?.handlers   // action callbacks
  let executors    = settings?.executors  // external callbacks
  local doRequest    = null

  assert(typeof name == "string")
  assert(client != null)
  assert(typeof handlers == "table")
  assert(executors == null || typeof executors == "table")


  function request(handler, params = {}, context = null) {
    let func = $"{name}.{handler} request"
    assert(handler in handlers, @()$"{func}: Unknown handler '{handler}'")
    debug($"{func} {utils.shortValue(params)}{utils.shortValue(context)}")

    let pair = handler.split(":")  // "action:extra"
    params.action <- pair[0]
    if (pair.len() > 1) {
      if (context == null)
        context = {}
      context["$extra"] <- pair[1]
    }

    if ("headers" not in params)
      params.headers <- {}
    let headers = params.headers

    if ("appid" not in headers)
      headers.appid <- get_app_id()

    if ("token" not in headers && "userid" not in headers)
      headers.token <- userInfo.value?.token

    doRequest(params, context)
  }


  function call(table, key, result, context, label, msg) {
    let callback = table?[key]
    assert(typeof callback == "function", @()$"{label} call({key}): type={typeof callback}")

    let nargs = callback.getfuncinfos().parameters.len() - 1
    assert(nargs == 1 || nargs == 2, @()$"{label} call({key}): nargs={nargs}")

    if (executors != null)
      callback.bindenv(executors)
    let output = (nargs == 1) ? callback(result) : callback(result, context)

    if (output == null)
      debug($"{label} {msg}")
    else
      debug($"{label} {msg}: {utils.shortKeyValue(output)}")
  }


  function process(result) {
    // This function has already corrupted 'this', but we don't need to restore it,
    // we just don't use 'this', we use free variables.
    assert("$action" in result, @()$"{name} process: No '$action' in result")
    let action  = result.$rawdelete("$action")
    let context = result?.$rawdelete("$context")
    let extra   = context?.$rawdelete("$extra")
    let handler = (extra == null) ? action : $"{action}:{extra}"
    let label   = $"{name}.{handler}"
    assert(handler in handlers, @()$"{label} process: No handler '{handler}'")

    // check any error answer from server
    let response = result?.response
    let success  = response?.success ?? true

    if (!success || "error" in result) {
      if (!success && "error" in response) {
        result = response  // {success = false, error = ..., ...}
      }
      else {
        local err = "unknown error"
        if ("error" in result)
          err = result.error
        else if ("error" in response)
          err = response.error
        result = {success = false, error = err}
      }

      debug($"{label} error: {utils.shortKeyValue(result?.error)}")
    }

    let executeBefore = context?.executeBefore
    if (executeBefore != null) {
      call(executors, executeBefore, result, context, label, $"executeBefore({executeBefore})")
    }

    call(handlers, handler, result, context, label, "completed")

    let executeAfter = context?.executeAfter
    if (executeAfter != null) {
      call(executors, executeAfter, result, context, label, $"executeAfter({executeAfter})")
    }
  }


  function requestEventBus(params, context) {
    client.requestEventBus(params, event, context)
  }


  function requestLegacy(params, context) {
    client.request(params, function(result) {
      result["$action"] <- params.action
      if (context != null)
        result["$context"] <- context
      process(result)
    })
  }


  function init() {
    // compatibility: 'requestEventBus' submitted at 24 feb 2021
    if (mode == "eventbus" && "requestEventBus" not in client)
      mode = "legacy"

    debug($"CharClientEvent({name}): {mode}")
    if (mode == "eventbus") {
      doRequest = requestEventBus
      eventbus_subscribe(event, @(data) process(clone data))
    }
    else if (mode == "legacy") {
      doRequest = requestLegacy
    }
  }


  init()
  return {
    request
  }
}


return CharClientEvent

