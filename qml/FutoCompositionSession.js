.pragma library

// Serialize conversion requests and tie every reply to an editor lifetime.
// The UI never sends candidate indices: native candidate IDs remain opaque.
function Session(transport, changed, failed) {
    this.transport = transport
    this.changed = changed
    this.failed = failed
    this.epoch = 0
    this.token = ""
    this.revision = 0
    this.language = ""
    this.layout = ""
    this.configuration = ""
    this.privateMode = true
    this.busy = false
    this.starting = false
    this.queue = []
    this.state = { preedit: "", candidates: [] }
}

Session.prototype.endToken = function(token) {
    if (token !== "")
        this.transport("EndComposition", [{type: "s", value: token}],
                       function() {}, function() {})
}

Session.prototype.invalidate = function() {
    this.epoch++
    this.endToken(this.token)
    this.token = ""
    this.revision = 0
    this.busy = false
    this.starting = false
    this.queue = []
    this.state = { preedit: "", candidates: [] }
    this.language = ""
    this.layout = ""
}

Session.prototype.accept = function(reply, request, epoch) {
    if (epoch !== this.epoch)
        return false
    var state
    try {
        state = JSON.parse(String(reply))
        if (!state.session || !Array.isArray(state.candidates)
                || typeof state.preedit !== "string"
                || typeof state.commit !== "string"
                || state.revision < 0)
            throw new Error("invalid conversion state")
    } catch (error) {
        this.fail(epoch)
        return false
    }
    this.token = String(state.session)
    this.revision = Number(state.revision)
    this.state = state
    this.changed(state, request)
    return true
}

Session.prototype.fail = function(epoch) {
    if (epoch !== this.epoch)
        return
    this.invalidate()
    this.failed()
}

Session.prototype.begin = function(language, layout, privateMode, options) {
    var configured = options !== undefined
    var configuration = configured ? JSON.stringify(options) : ""
    privateMode = privateMode === undefined ? true : !!privateMode
    if (this.language === language && this.layout === layout
            && this.configuration === configuration
            && this.privateMode === privateMode
            && (this.token !== "" || this.starting))
        return
    this.invalidate()
    this.language = language
    this.layout = layout
    this.configuration = configuration
    this.privateMode = privateMode
    this.starting = true
    this.busy = true
    var self = this, epoch = this.epoch
    var args = [
        {type: "s", value: language}, {type: "s", value: layout},
        {type: "b", value: privateMode}
    ]
    if (configured) args.push({type: "s", value: configuration})
    var attempt = 0
    function start() {
        var currentAttempt = ++attempt
        self.transport(configured ? "StartCompositionWithOptions" : "StartComposition", args, function(reply) {
            if (epoch !== self.epoch || currentAttempt !== attempt) {
                try { self.endToken(String(JSON.parse(String(reply)).session || "")) }
                catch (error) {}
                return
            }
            self.busy = false
            self.starting = false
            if (self.accept(reply, null, epoch))
                self.pump()
        }, function(name) {
            if (epoch !== self.epoch || currentAttempt !== attempt) return
            // Cold dictionary preparation can outlast the D-Bus call. No
            // text has been sent yet, so one retry keeps the queued keys safe.
            if (attempt === 1 && String(name) === "org.freedesktop.DBus.Error.NoReply") start()
            else self.fail(epoch)
        })
    }
    start()
}

Session.prototype.enqueue = function(operation, value, after) {
    if (this.language === "" || this.queue.length >= 256)
        return false
    this.queue.push({operation: operation, value: value === undefined || value === null ? "" : String(value),
                     after: after || null})
    this.pump()
    return true
}

Session.prototype.select = function(id, revision) {
    // A candidate tapped while another key is in flight is no longer the
    // candidate list the worker will see. Never select a new word by accident.
    if (this.busy || this.queue.length > 0 || revision !== this.revision)
        return false
    for (var i = 0; i < this.state.candidates.length; ++i) {
        if (String(this.state.candidates[i].id) === String(id))
            return this.enqueue("select", id)
    }
    return false
}

Session.prototype.pump = function() {
    if (this.busy || this.token === "" || this.queue.length === 0)
        return
    var self = this, epoch = this.epoch, request = this.queue.shift()
    this.busy = true
    this.transport("UpdateComposition", [
        {type: "s", value: this.token}, {type: "u", value: this.revision},
        {type: "s", value: request.operation}, {type: "s", value: request.value}
    ], function(reply) {
        if (epoch !== self.epoch)
            return
        self.busy = false
        if (!self.accept(reply, request, epoch))
            return
        if (request.after)
            request.after()
        self.pump()
    }, function() { self.fail(epoch) })
}
