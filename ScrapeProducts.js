(function() {
    'use strict';
    var boxes = document.getElementsByTagName('fieldset'),
        summary = {},
        products = [],
        icon = new Image(),
        iconURL,
        canvas,
        i,
        first,
        last,
        box,
        product;

    for (i = 0; i < boxes.length; i++) {
        box = boxes[i];

        first = (i === 0);
        last = (i === (boxes.length - 1));

        if (first || last) {
            product = summary;
        } else {
            product = {};
            products.push(product);
        }

        if (!last) {
            product.name = document.evaluate('.//label', box, null, XPathResult.STRING_TYPE, null).stringValue.trim();
        }

        if (first) {
            iconURL = document.evaluate('.//div', box, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue.style['background-image'];
            if (iconURL) {
                product.iconDataURL = iconURL.substring(4, iconURL.length - 1);
            }
        } else if (!last) {
            iconURL = document.evaluate('.//img', box, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue.src;
            icon.src = iconURL;
            canvas = document.createElement('canvas');
            canvas.width = icon.width;
            canvas.height = icon.height;
            canvas.getContext('2d').drawImage(icon, 0, 0);
            product.iconDataURL = canvas.toDataURL('image/png');
            product.productURL = document.evaluate('./a', box, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue.href;
            if (product.productURL.indexOf('https://cydia.saurik.com/connect/products/') !== 0) {
                products.pop();
                continue;
            }
        }

        if (!first) {
            if (last) {
                box = document.evaluate('.//div', box, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
            }
            product.incomeRate = document.evaluate('.//div//div', box, null, XPathResult.STRING_TYPE, null).stringValue.trim();
            product.delta = document.evaluate('.//div//div//span[2]', box, null, XPathResult.STRING_TYPE, null).stringValue.trim();
            product.direction = (document.evaluate('.//div//div[last()]', box, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue.style.color === 'red') ? '-' : '+';
        }
    }

    return {
        summary : summary,
        products : products
    };
})()
