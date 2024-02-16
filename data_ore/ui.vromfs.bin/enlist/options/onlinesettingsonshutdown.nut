let eventbus = require("eventbus")
let { save, sendToServer } = require("%enlist/options/onlineSettings.nut")

eventbus.subscribe("app.shutdown", function(_) {
    save()
    sendToServer(true)
})
