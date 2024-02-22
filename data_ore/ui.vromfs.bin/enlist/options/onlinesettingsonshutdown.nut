let { eventbus_subscribe } = require("eventbus")
let { save, sendToServer } = require("%enlist/options/onlineSettings.nut")

eventbus_subscribe("app.shutdown", function(_) {
    save()
    sendToServer(true)
})
