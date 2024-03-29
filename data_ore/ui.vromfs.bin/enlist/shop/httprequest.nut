from "%enlSqGlob/ui/ui_library.nut" import *

let { parse_json } = require("json")
let { HTTP_SUCCESS, httpRequest } = require("dagor.http")
let userInfo = require("%enlSqGlob/userInfo.nut")

let hasLog = {}
function logByUrlOnce(url, text) {
  if (url in hasLog)
    return
  hasLog[url] <- true
  log(text)
}

function requestData(url, params, onSuccess, onFailure=null) {
  httpRequest({
    method = "POST"
    url
    data = params
    callback = function(response) {
      if (response.status != HTTP_SUCCESS || !response?.body) {
        onFailure?()
        return
      }

      try {
        let str = response.body.as_string()
        if (str.len() > 6 && str.slice(0, 6) == "<html>") { //error 404 and other html pages
          logByUrlOnce(url, $"ShopState: Request result is html page instead of data {url}\n{str}")
          onFailure?()
          return
        }
        let data = parse_json(str)
        if (data?.status == "OK")
          onSuccess(data)
        else
          onFailure?()
      }
      catch(e) {
        logByUrlOnce(url, $"ShopState: Request result error {url}")
        onFailure?()
      }
    }
  })
}

function createGuidsRequestParams(guids) {
  local res = guids.reduce(@(acc, guid) $"{acc}guids[]={guid}&", "")
  res = $"{res}jwt={userInfo.value?.token ?? ""}&special=1"
  return res
}

return {
  requestData
  createGuidsRequestParams
}