.pragma library

function mode(value) {
    var parsed = Number(value)
    return isFinite(parsed) && parsed >= 0 && parsed <= 3 && parsed === Math.floor(parsed) ? parsed : 2
}

function allowed(value, systemLevel) {
    return mode(value) !== 0 && Number(systemLevel) > 0
}

function pulseDuration(value) {
    switch (mode(value)) {
    case 1: return 30
    case 3: return 65
    default: return 0
    }
}

function platformEffect(value, normal, off) {
    return mode(value) === 2 ? normal : off
}

function updatePlatformEffect(target, state, active, enabled, silenced, selected, off) {
    if (!target) return
    if (active) {
        if (!state.applied) {
            state.original = target.effect
            state.applied = true
        }
        target.effect = !enabled || silenced ? off : selected
    } else if (state.applied) {
        target.effect = state.original
        state.applied = false
    }
}
