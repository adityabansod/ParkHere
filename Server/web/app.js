var express = require('express'),
    geodata = require('./geodata.js'),
    settings = require('./settings.js');

    app = express(),
    port = process.env.PORT || 5000;
app.use(express.compress());

app.get('/nearby/:lat/:lon', function(req, res) {
    var started = new Date();
    console.log(req.method + ' request: ' + req.url);

    var lat = parseFloat(req.params.lat),
        lon = parseFloat(req.params.lon);
    if(req.query.maxDistance != null)
        maxDistance = parseInt(req.query.maxDistance);
    else
    	maxDistance = settings().maxDistance;
    geodata.nearby(lat, lon, maxDistance, function(docs) {
    	console.log('answered ' + req.url + ' in ' + ((new Date()).getTime() - started.getTime()) + 'ms');
        res.send(docs);
    });
});
app.get('/settings', function(req, res) {
    res.send(settings());
});
app.listen(port);
console.log('Listening on port ' + port + '...');
