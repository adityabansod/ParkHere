

var asdf = function() { console.log('in asdf'); }

function doSomething(callback) {
    callback();
    asdf();
}


doSomething(asdf)

console.log(asdf);

console.log(doSomething)