var express = require('express'),
    geodata = require('./geodata.js'),
    app = express(),
    port = process.env.PORT || 5000;
app.use(express.compress());

app.get('/nearby/:lat/:lon', function(req, res) {
    var started = new Date();
    console.log(req.method + ' request: ' + req.url);
            console.log((new Date()).getTime() + 'ms')

    var lat = parseFloat(req.params.lat),
        lon = parseFloat(req.params.lon);
    if(req.query.maxDistance != null)
        maxDistance = parseInt(req.query.maxDistance);
    else
    	maxDistance = 150;
    geodata.nearby(lat, lon, maxDistance, function(docs) {
    	console.log('answered ' + req.url + ' in ' + ((new Date()).getTime() - started.getTime()) + 'ms');
        res.send(docs);
    });
});
app.listen(port);
console.log('Listening on port ' + port + '...');
