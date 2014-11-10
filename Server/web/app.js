var express = require('express'),
    geodata = require('./geodata.js'),
    app = express(),
    port = process.env.PORT || 5000;

app.get('/nearby/:lat/:lon', function(req, res) {
    console.log(req.method + ' request: ' + req.url);
    var lat = parseFloat(req.params.lat),
        lon = parseFloat(req.params.lon);
    if(req.query.maxDistance != null)
        maxDistance = parseInt(req.query.maxDistance);
    else
    	maxDistance = 150;
    geodata.nearby(lat, lon, maxDistance, function(docs) {
    	res.send(docs);
    });
});
app.listen(port);
console.log('Listening on port ' + port + '...');
