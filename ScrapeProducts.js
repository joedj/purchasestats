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

    function stringAtPath(path) {
        return document.evaluate(path, box, null, XPathResult.STRING_TYPE, null).stringValue.trim();
    }

    function nodeAtPath(path) {
        return document.evaluate(path, box, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
    }

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
            product.name = stringAtPath('.//label');
        }

        if (first) {
            iconURL = nodeAtPath('.//div').style['background-image'];
            if (iconURL) {
                product.iconDataURL = iconURL.substring(4, iconURL.length - 1);
            }
        } else if (!last) {
            iconURL = nodeAtPath('.//img').src;
            icon.src = iconURL;
            canvas = document.createElement('canvas');
            canvas.width = icon.width;
            canvas.height = icon.height;
            canvas.getContext('2d').drawImage(icon, 0, 0);
            product.iconDataURL = canvas.toDataURL('image/png');
            product.productURL = nodeAtPath('./a').href;
            if (product.productURL.indexOf('https://cydia.saurik.com/connect/products/') !== 0) {
                products.pop();
                continue;
            }
        }

        if (!first) {
            if (last) {
                box = nodeAtPath('.//div');
            }
            product.incomeRate = stringAtPath('.//div//div');
            product.delta = stringAtPath('.//div//div//span[2]');
            product.direction = (nodeAtPath('.//div//div[last()]').style.color === 'red') ? '-' : '+';
        }
    }

    return {
        summary : summary,
        products : products
    };
})()
