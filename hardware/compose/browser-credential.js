/* Native-browser form adapter. No clipboard, synthetic paste or form submit. */
(function (request) {
    "use strict";
    function unavailable() { return JSON.stringify({ available: false, reason: "form" }); }
    function origin(win) {
        return String(win.location.protocol).toLowerCase() + "//"
            + String(win.location.host).toLowerCase();
    }
    var win = window;
    var input = win.document.activeElement;
    for (var depth = 0; input && /^(iframe|frame)$/i.test(input.tagName) && depth < 8; ++depth) {
        try {
            if (origin(input.contentWindow) !== origin(window)) return unavailable();
            win = input.contentWindow;
            input = win.document.activeElement;
        } catch (_) { return unavailable(); }
    }
    var site = origin(win);
    if (!/^https?:\/\//.test(site)) return unavailable();
    // WeakMap keys do not add attributes or secrets to the site's DOM.
    var state = win.__futoCredentialFields;
    if (!state) {
        state = { ids: new WeakMap(), next: 1 };
        Object.defineProperty(win, "__futoCredentialFields", { value: state });
    }
    function fieldId(field) {
        if (!state.ids.has(field)) state.ids.set(field, String(state.next++));
        return state.ids.get(field);
    }
    function usable(field) {
        return field && field.tagName === "INPUT" && !field.disabled && !field.readOnly
            && field.getClientRects().length > 0;
    }
    function completion(field) {
        // Older Gecko versions normalize unsupported tokens out of the IDL
        // property on a revealed (type=text) password. Read the declared HTML
        // attribute as well; neither source contains the password value.
        return String((field.getAttribute && field.getAttribute("autocomplete"))
            || field.autocomplete || "").toLowerCase();
    }
    function passwordField(field) {
        return usable(field) && (field.type === "password"
            || (field.type === "text"
                && /(^|\s)current-password(\s|$)/.test(completion(field))));
    }
    function textField(field) {
        return usable(field) && !passwordField(field) && /^(text|email|tel)$/.test(field.type)
            && !/one-time-code|otp|verification/i.test(completion(field) + " " + field.name);
    }
    // Device authorization can blur the originating editor. Restore only the
    // exact field captured for this page, never guess a different form.
    if (request.operation !== "context" && !usable(input) && state.last
            && String(request.field) === state.last.id
            && state.last.input.isConnected
            && state.last.input.ownerDocument === win.document) input = state.last.input;
    if (!usable(input)) return unavailable();
    var form = input.form;
    // No form owner: use the nearest containing element that actually has a
    // password field, rather than all fields elsewhere on the page.
    if (!form) {
        form = input.parentElement;
        while (form && form !== win.document.body
                && !form.querySelector('input[type="password"]')) form = form.parentElement;
        if (!form || form === win.document.body) return unavailable();
    }
    var fields = Array.prototype.slice.call(form.querySelectorAll("input"));
    var passwords = fields.filter(function (field) {
        return passwordField(field)
            && !/(^|\s)new-password(\s|$)/.test(completion(field));
    });
    if (passwords.length !== 1) return unavailable();
    var password = passwords[0];
    var candidates = fields.filter(textField);
    var username = textField(input) ? input : null;
    if (!username) {
        var marked = candidates.filter(function (field) {
            return /username|email/i.test(completion(field) + " " + field.name + " " + field.id);
        });
        if (marked.length === 1) username = marked[0];
        else if (candidates.length === 1) username = candidates[0];
    }
    if (!username && candidates.length > 0) return unavailable();
    if (input !== password && input !== username) return unavailable();
    var identity = fieldId(input);
    var result = { available: true, origin: site, field: identity,
        password: input === password, revealed: input === password && password.type === "text",
        username: username ? username.value : "" };
    if (request.operation === "context") {
        state.last = { id: identity, input: input };
        return JSON.stringify(result);
    }
    if (String(request.origin).toLowerCase() !== site || String(request.field) !== identity)
        return unavailable();
    if (request.operation === "restore") {
        input.blur();
        input.focus();
        result.restored = win.document.activeElement === input;
    } else if (request.operation === "fill") {
        function setValue(field, value) {
            var setter = Object.getOwnPropertyDescriptor(win.HTMLInputElement.prototype, "value").set;
            setter.call(field, String(value));
            field.dispatchEvent(new win.Event("input", { bubbles: true }));
            field.dispatchEvent(new win.Event("change", { bubbles: true }));
        }
        if (username) setValue(username, request.username || "");
        // An input listener can navigate or replace the form. Recheck before
        // releasing the password to a stale or detached editor.
        if (origin(win) !== site || !password.isConnected || password.form !== input.form)
            return unavailable();
        setValue(password, request.secret || "");
        password.focus();
        result.filled = (!username || username.value === String(request.username || ""))
            && password.value === String(request.secret || "");
    }
    return JSON.stringify(result);
})
