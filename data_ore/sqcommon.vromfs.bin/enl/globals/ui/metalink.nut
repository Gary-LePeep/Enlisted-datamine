from "%enlSqGlob/ui/ui_library.nut" import *

function addLink(obj, link, link_type) {
  obj.links[link] <- link_type
}

function delLink(obj, link) {
  obj.links.$rawdelete(link)
}

function delLinkByType(obj, link_type) {
  let keysToDelete = []
  foreach (k, v in obj.links)
    if (v == link_type)
      keysToDelete.append(k)

  foreach (key in keysToDelete)
    obj.links.$rawdelete(key)
}

let hasLinkByType = @(obj, link_type)
  obj.links.findindex(@(v) v == link_type) != null

function getLinkedObjects(where, linked) {
  let res = []
  foreach (k,v in where) {
    let linkType = v.links?[linked]
    if (linkType) {
      res.append({
        key = k
        value = v
        type = linkType
      })
    }
  }

  return res
}


function getLinkedObjectsValues(where, linked) {
  let res = []
  foreach (v in where)
    if (v.links?[linked])
      res.append(v)

  return res
}


let isObjectLinkedToAny = @(obj, linkedList)
  linkedList.findvalue(@(linked) obj.links?[linked] != null) != null

let isObjectHaveLinkTypeToAny = @(obj, typesList)
  (obj.links ?? {}).findvalue(@(t) t in typesList) != null

function getObjectsByLink(where, linked, link_type) {
  let res = []
  foreach (v in where)
    if (v.links?[linked] == link_type)
      res.append(v)

  return res
}


function getObjectsByLinkType(where, link_type) {
  let res = []
  foreach (k,v in where) {
    foreach (linkType in v) {
      if (linkType == link_type) {
        res.append({
          key = k
          value = v
        })
        break
      }
    }
  }

  return res
}

function getObjectsTableByLinkType(where, link_type) {
  let res = {}
  foreach (v in where)
    foreach (to,linkType in v.links)
      if (linkType == link_type) {
        if (to not in res)
          res[to] <- []
        res[to].append(v)
        break
      }
  return res
}


let getFirstLinkByType = @(obj, link_type)
  obj.links.findindex(@(v) v == link_type)

let getItemIndex = @(obj) (getFirstLinkByType(obj, "index")?.tointeger()) ?? -1

function changeIndex(obj, newIndex) {
  delLinkByType(obj, "index")
  if (newIndex >= 0)
    addLink(obj, newIndex.tostring(), "index")
}

let getObjectsByLinkSorted = @(objects, squadGuid, linkType)
  getObjectsByLink(objects, squadGuid, linkType)
    .sort(@(a,b) getItemIndex(a) <=> getItemIndex(b))

function isObjLinkedToAnyOfObjects(obj, objects) {
  foreach (k, _ in obj?.links ?? {})
    if (k in objects)
      return true
  return false
}

function getFirstLinkedObjectGuid(obj, objects) {
  foreach (k, _ in obj?.links ?? {})
    if (k in objects)
      return k
  return ""
}

function getLinkedSlotData(obj) {
  foreach (linkVal, linkType in obj.links)
    if (linkType != "index" && linkType != "army")
      return { linkTgt = linkVal, linkSlot = linkType }
  return null
}

let isLinkedTo = @(obj, owner) owner in (obj?.links ?? {})

return {
  addLink
  delLink
  hasLinkByType
  delLinkByType
  getLinkedObjects
  getLinkedObjectsValues
  isObjectLinkedToAny
  getObjectsByLink
  getObjectsByLinkType
  getObjectsTableByLinkType
  getFirstLinkByType
  getItemIndex
  changeIndex
  getObjectsByLinkSorted
  isObjLinkedToAnyOfObjects
  isObjectHaveLinkTypeToAny
  getFirstLinkedObjectGuid
  getLinkedSlotData
  isLinkedTo
  getLinkedArmyName = @(o) getFirstLinkByType(o, "army")
  getLinkedSquadGuid = @(o) getFirstLinkByType(o, "squad")
}
