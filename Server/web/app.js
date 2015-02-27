require('newrelic');

var express = require('express'),
    geodata = require('./geodata.js'),
    geo2 = require('./geo2.js'),
    settings = require('./settings.js');

    app = express(),
    port = process.env.PORT || 5000;
app.use(express.compress());

app.get('/nearby/:lat/:lon', function(req, res) {
    var started = new Date();
    console.log(req.method + ' request: ' + req.url);

    var lat = parseFloat(req.params.lat),
        lon = parseFloat(req.params.lon);
    if(req.query.maxDistance)
        maxDistance = parseInt(req.query.maxDistance);
    else
    	maxDistance = settings().maxDistance;

    if(req.query.geoOne) {
        geodata.nearby(lat, lon, maxDistance, function(docs) {
         console.log('GEOONE: answered ' + req.url + ' in ' + ((new Date()).getTime() - started.getTime()) + 'ms');
            res.send(docs);
        });
    } else {
        geo2.nearby(lat, lon, maxDistance, function(docs) {
            console.log('GEOTWO: answered ' + req.url + ' in ' + ((new Date()).getTime() - started.getTime()) + 'ms');
            res.send(docs);
        });
    }

});
app.get('/settings', function(req, res) {
    res.send(settings());
});
app.listen(port);
console.log('Listening on port ' + port + '...');
