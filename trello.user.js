// ==UserScript==
// @name         Hide Trello Activity
// @namespace    https://trello.com/
// @description Hide activity in trello
// @include http://trello.com/*
// @include https://trello.com/*
// @run-at document-end
// @version 1.0.2
// @author Anton De Martini 
// @grant  none
// @downloadURL https://raw.githubusercontent.com/anton-dema/myusefulconfigs/master/trello.user.js
// @updateURL https://raw.githubusercontent.com/anton-dema/myusefulconfigs/master/trello.user.js
// ==/UserScript==

var style = document.createElement('style');
style.setAttribute('type', 'text/css');
style.appendChild(document.createTextNode('.phenom-other{ display: none; }'));
style.appendChild(document.createTextNode('.phenom-move-from-list-to-list{ display: none; }'));
style.appendChild(document.createTextNode('.window-module-title-no-divider { display: none; }'));
style.appendChild(document.createTextNode('.card-detail-badge { display: none; }'));
style.appendChild(document.createTextNode('.card-detail-item-header { display: none; }'));
style.appendChild(document.createTextNode('.quiet-button-icon { display: none; }'));
style.appendChild(document.createTextNode('.quiet-button mod-with-image hide-on-edit js-edit-desc js-hide-with-desc { left: -40px; position: relative; top: -1px;}'));
style.appendChild(document.createTextNode('.quiet-button.mod-with-image { left: -60px; position: relative; }'));
style.appendChild(document.createTextNode('.card-detail-item { margin: -14px 28px 16px 0px; }'));
style.appendChild(document.createTextNode('.current.markeddown.hide-on-edit.js-card-desc.js-show-with-desc { padding-top: 7px; }'));
style.appendChild(document.createTextNode('.card-detail-item-header-edit { position: relative; left: -33px; }'));
style.appendChild(document.createTextNode('.current.markeddown.hide-on-edit.js-card-desc.js-show-with-desc { position: relative; left: -33px; padding-top: 10px; }'));
document.head.appendChild(style);
