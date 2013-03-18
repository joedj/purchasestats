(function() {
    'use strict';
    var links = document.getElementsByTagName('a');
    return {
        productURL: document.location.href,
        totalSales: links[1].getElementsByTagName('label')[1].textContent.trim(),
        pendingEarnings: links[2].getElementsByTagName('label')[1].textContent.trim()
    };
})()
