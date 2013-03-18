(function() {
    'use strict';
    var buttons = document.getElementsByTagName('button'), i, button;
    for (i = 0; i < buttons.length; i++) {
        button = buttons[i];
        if (button.value === __PLACEHOLDER__) {
            button.click();
            return true;
        }
    }
    return;
})()
