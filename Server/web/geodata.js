var dbUrl = process.env.MONGOLAB_URI || "sfstreets",
    db = require("mongojs").connect(dbUrl),
    moment = require('moment'),
    async = require('async'),
    settings = require('./settings.js');
exports.nearby = function(lat, lon, maxDistance, callbackFn) {
    if (maxDistance > 250) maxDistance = settings().maxDistance;
    console.log('Issuing query for blockfaces at ' + lat + ', ' + lon + ' at ' + maxDistance + 'm');
    queryForBlockface(lat, lon, maxDistance, callbackFn);
}

function queryForBlockface(lat, lon, maxDistance, callbackFn) {
    db.collection('parking').find({
        $and:
        [
            {
                geometry: {
                    $near: { 
                        $geometry: { "type": "Point",  "coordinates": [ lon, lat ] },
                        $minDistance: 0,
                        $maxDistance: maxDistance
                    }
                }
            },
            {
                "properties.Regulation": { $ne: null }
            }
        ]
    },
    function(err, res) {
        console.log('found ' + res.length + ' matching blockfaces, now querying street sweeping')
        queryForStreetSweeping(res, callbackFn);
    });
}

function queryForStreetSweeping(blockfaceResult, callbackFn) {
    // console.log('querying for street sweeping against ' + blockfaceResult.length + ' faces');
    // build up the list of queries
    var queries = [];
    for (var i = 0; i < blockfaceResult.length; i++) {
        var query = (function(callback) {
            var blockface = this;
            var lat = 0;
            var lon = 0;

            // 1. find midpoint for this blockface
            var coordinateSet = blockface.geometry.coordinates;
            for (var j = 0; j < coordinateSet.length; j++) {
                lat += coordinateSet[j][1];
                lon += coordinateSet[j][0];
            };
            lat = lat/coordinateSet.length;
            lon = lon/coordinateSet.length;
            blockface.centerpoint = [lat, lon];

            // 2. search the streets collection for locations
            // near that center point
            db.collection('streets').find({
                    geometry: {
                        $near: { "type": "Point", "coordinates": [lon, lat] },
                        $minDistance: 0,
                        $maxDistance: 25
                    }
                }
            ,
            (function(err, res) {
                var sweepings =  res;

                // console.log('filtered ' + sweepings.length + ' of ' + res.length + ' sweeping results for ' + this._id);
                if(sweepings.length > 0) {
                    /*
                       3. hokay. since we searched for sweeping locations based on
                       the centerpoint of the LineString in the parking data, this
                       can lead to us finding midblock lanes instead of the acutal
                       street we're on.

                       thus, we'll look through all the resulting sweeping results
                       and find the first one (the nearest since we query with $near)
                       that has a slope within some percent of this LineString's slope                   
                    */ 
                    var slope = calculateLineSlope(this.geometry.coordinates).slope;
                    var delta = 100; // pick an arbitrarly high delta to start
                    for (var i = 0; i < sweepings.length; i++) {
                        var sweep = sweepings[i],
                            sweepSlope = calculateLineSlope(sweep.geometry.coordinates,
                                                            sweep.properties.STREETNAME).slope,
                            sweepDelta = (slope - sweepSlope);
                            if((Math.min(delta, sweepDelta)) == sweepDelta &&  (slope/sweepSlope) > settings().slopeTolerance) {
                                this.street = sweep.properties.STREETNAME;
                                delta = sweepDelta;
                            }
                    };
                    this.streetSlopeAndDirection = calculateLineSlope(this.geometry.coordinates, this.street);
                }
                this.sweepings = sweepings;
                callback(err, this);
            }).bind(blockface));
        }).bind(blockfaceResult[i]);

        queries.push(query);
    };

    // console.log('running ' + queries.length + ' in parallel');
    async.parallel(queries, function(err, results) {
        if(err) throw err;

        /* 4. now that we have sweeping data and all the blockfaces with names
           we now attempt to find parallel streets so we can later deduce which is
           the north vs south side, east vs west side, etc to match that to the 
           street sweeping data 
        */ 
        for (var i = 0; i < results.length; i++) {
            // console.log('angle ' + results[i].streetSlopeAndDirection.angle);
            var minDistance = 1000;
            var pairStreet;
            for (var j = 0; j < results.length; j++) {
                var cord1 = results[i].centerpoint;
                var cord2 = results[j].centerpoint;
                var distance = wgs84distance(cord1[0], cord1[1], cord2[0], cord1[1]);
                var cord1Slope = calculateLineSlope(results[i].geometry.coordinates).slope;
                var cord2Slope = calculateLineSlope(results[j].geometry.coordinates).slope;

                if(Math.min(distance, minDistance) == distance && distance != 0) {
                    if(cord1Slope / cord2Slope > settings().slopeTolerance) {
                        if(results[i].street == results[j].street) {
                            minDistance = distance;
                            pairStreet = results[j];
                        }
                    }
                }
            };
            if(pairStreet != null) {
                results[i].pairStreet = {"_id": pairStreet._id, "name": pairStreet.street};            
            } else {
                results[i].pairStreet = {"_id": results[i]._id, "name": results[i].street, "match": false};
            }
        }

        for (var i = 0; i < results.length; i++) {
            // 5. create printable strings for each sweeping
            var street = results[i];

            // 6. find the street directions
            var pair = findStreetById(results, street.pairStreet._id);


            var directionOneSide;
            var directionOtherSide;
            street.sweepings.some(function(item) {
                if(street.street == item.properties.STREETNAME) {
                   directionOneSide = item.properties.BLOCKSIDE;
                   return true; 
                }
            });
            directionOtherSide = calculateOpposingBlockside(directionOneSide);

            if(street.sweepings.length == 0) continue;

            if(directionOneSide == null) {
                street.sweepings = createDescriptionForSweepings(street.sweepings);
                continue;
            }
            
            if(directionOneSide.indexOf("North") > -1 || directionOtherSide.indexOf("North") > -1) {
                if(Math.min(street.centerpoint[1],pair.centerpoint[1]) == street.centerpoint[1]) {
                    // street is more northern
                    street.sweepings = street.sweepings.filter(function(item) {
                        if(item.properties.BLOCKSIDE == null) return false;
                        if(item.properties.BLOCKSIDE.indexOf("North") > -1)
                            return true;
                    });
                    street.streetSlopeAndDirection.dir = "ns-street-northern";
                } else {
                    // street is more southern
                    street.sweepings = street.sweepings.filter(function(item) {
                        if(item.properties.BLOCKSIDE == null) return false;
                        if(item.properties.BLOCKSIDE.indexOf("South") > -1)
                            return true;
                    });
                    street.streetSlopeAndDirection.dir = "ns-street-southern";
                }
            } else if(directionOneSide.indexOf("West") > -1 || directionOtherSide.indexOf("West") > -1){
                if(Math.min(street.centerpoint[0],pair.centerpoint[0]) == street.centerpoint[0]) {
                    // street is more western
                    street.sweepings = street.sweepings.filter(function(item) {
                        if(item.properties.BLOCKSIDE == null) return false;
                        if(item.properties.BLOCKSIDE.indexOf("West") > -1)
                            return true;
                    });
                    street.streetSlopeAndDirection.dir = "ew-street-western";
                } else {
                    // street is more eastern
                    street.sweepings = street.sweepings.filter(function(item) {
                        if(item.properties.BLOCKSIDE == null) return false;
                        if(item.properties.BLOCKSIDE.indexOf("East") > -1)
                            return true;
                    });
                    street.streetSlopeAndDirection.dir = "ew-street-eastern";
                }
            } else {
                console.log("huh?");
            }

            street.sweepings = createDescriptionForSweepings(street.sweepings);
        };

        callbackFn(slimDataSet(results));
    });
}

function slimDataSet(results) {
    for (var i = 0; i < results.length; i++) {
        var thisResult = results[i];
        delete thisResult.type;
        delete thisResult.streetSlopeAndDirection;
        delete thisResult.pairStreet;
        for (var j = 0; j < thisResult.sweepings.length; j++) {
            // delete thisResult.sweepings[j].type;
            delete thisResult.sweepings[j].datapoint;
        };
    };
    return results;

}

function calculateOpposingBlockside(directionOneSide) {
    var directionOtherSide;

    switch(directionOneSide) {
        case "NorthWest":
            directionOtherSide = "SouthEast";
            break;
        case "SouthEast":
            directionOtherSide = "NorthWest";
            break;
        case "NorthEast":
            directionOtherSide = "SouthWest";
            break; 
        case "SouthWest":
            directionOtherSide = "NorthEast";
            break;
        case "North":
            directionOtherSide = "South";
            break;
        case "South":
            directionOtherSide = "North";
            break;
        case "East":
            directionOtherSide = "West";
            break;
        case "West":
            directionOtherSide = "East";
            break;
        default:
            directionOtherSide = "Both";
            break;
    }

    return directionOtherSide;
}

function findStreetById(set, id) {
    for (var i = 0; i < set.length; i++) {
        if(set[i]._id == id) {
            return set[i];
        };
    }
}

function calculateLineSlope(coordinateSet, streetname) {
    if(coordinateSet.length <= 1) return;

    // calculate the slope from first and last 
    var p1y_lat = coordinateSet[0][1],
        p1x_lon = coordinateSet[0][0],
        p2y_lat = coordinateSet[coordinateSet.length-1][1],
        p2x_lon = coordinateSet[coordinateSet.length-1][0];

    var slope = (p2y_lat - p1y_lat) / (p2x_lon - p1x_lon);
    var slopeAngle = 90-Math.atan(slope)*(180/Math.PI);

    // console.log ('slope is ' + slope + ' dir ' + direction + ' for ' + streetname);
    return {"slope": slope, "angle": slopeAngle};

}

function createDescriptionForSweepings(sweepings) {

    var today = new Date();
    var todayOfWeek = today.getDay();
    var resultset = [];

    for (var i = 0; i < sweepings.length; i++) {
        var sweep = sweepings[i].properties;

        // isSweepInNext24Hours(sweep)
        var sweepingDay = convertWeekdayStringToNumber(sweep.WEEKDAY);
        if( todayOfWeek == sweepingDay ||
            addOneDayOfWeek(todayOfWeek) == sweepingDay ||
            sweepingDay == 7 || true) {

            var addrStart, addrEnd;

            if(sweep.LF_FADD == 0 || sweep.LF_TOADD == 0) {
                addrStart = sweep.RT_FADD;
                addrEnd = sweep.RT_TOADD;
            } else {
                addrStart = sweep.LF_FADD;
                addrEnd = sweep.LF_TOADD;
            }

            var desc = addrStart + 
                '-' + addrEnd +
                ' ' + 
                sweep.STREETNAME +
                ' will be swept on ' +
                sweep.WEEKDAY +
                ' from ' +
                sweep.FROMHOUR +
                ' to ' +
                sweep.TOHOUR;

            if(sweep.BLOCKSIDE != null) {
                desc += ' on the ' +
                sweep.BLOCKSIDE +
                ' side.';
            } else {
                desc += ' on both sides.'
            }
                

            resultset.push({"description": desc, "datapoint": sweepings[i]});
        }
    }

    return resultset;
}

function isSweepInNext24Hours(properties) {
    var now = new Date(),
        today = now.getDay(),
        tomorrow = addOneDayOfWeek(today),
        from = getHoursFromUnformattedDateString(properties.FROMHOUR),
        to = getHoursFromUnformattedDateString(properties.TOHOUR),
        sweepingDay = convertWeekdayStringToNumber(properties.WEEKDAY),
        nowHour = now.getHours();
    // console.log(moment([2010, 1, 14, 15, 25, 50, 125]).toString());


    if(today == sweepingDay || tomorrow == sweepingDay) {
            var thisMoment = moment();
            var todayFromDate = moment([   now.getFullYear(),
                                now.getMonth(),
                                now.getDate(),
                                from]);
            var todayToDate = moment([   now.getFullYear(),
                                now.getMonth(),
                                now.getDate(),
                                to]);

        if(today == sweepingDay) {
            var blah = todayToDate.diff(todayFromDate);
            // console.log(blah.toString())

            // console.log(thisMoment.toString() + ' ' + todayFromDate.toString() + ' ' + todayToDate.toString())
        } else if (tomorrow == sweepingDay) {
            todayFromDate.add('1', 'days');
            todayToDate.add('1', 'days');

        }
        // console.log('from ' + from + ' to ' + to + ' nowHour ' + nowHour)
    }

}

function getHoursFromUnformattedDateString(dateString) {
    return dateString.substring(0, dateString.search(':'));
}

function prettyPrintWeeksOfMonth(properties) {
    var holidays = properties.HOLIDAYS,
        week1 = properties.WEEK1OFMON,
        week2 = properties.WEEK2OFMON,
        week3 = properties.WEEK3OFMON,
        week4 = properties.WEEK4OFMON,
        week5 = properties.WEEK5OFMON;

    if (holidays && week1 && week2 && week3 && week4 && week5) {
        return "every week";
    } else if (week1 && week2 && week3 && week4 && week5) {
        return "every week";
    } else if (week1) {
        return "first week";
    } else if (week2) {
        return "second week";
    } else if (week3) {
        return "third week";
    } else if (week4) {
        return "fourth week";
    } else if (week5) {
        return "fifth week";
    } else if (week1 & week3) {
        return "first and third week";
    } else if (week2 & week4) {
        return "second and fourth week";
    } else {
        return "odd combo";
    }
}

function addOneDayOfWeek(day) {
    day++;
    if (day == 7)
        return 0;
    else
        return day;
}

function convertWeekdayStringToNumber(weekday) {
    switch (weekday) {
        case 'Sun': 
            return 0;
        case 'Mon':
            return 1;
        case 'Tues':
            return 2;
        case 'Wed':
            return 3;
        case 'Thu':
            return 4;
        case 'Fri':
            return 5;
        case 'Sat':
            return 6;
        case 'Holiday':
            return 7;
        default: 
            console.log('Unknown weekday ' + weekday);
    }
}

function wgs84distance(lat1, lon1, lat2, lon2) {
    var radlat1 = Math.PI * lat1/180;
    var radlat2 = Math.PI * lat2/180;
    var radlon1 = Math.PI * lon1/180;
    var radlon2 = Math.PI * lon2/180;
    var theta = lon1-lon2;
    var radtheta = Math.PI * theta/180;
    var dist = Math.sin(radlat1) * Math.sin(radlat2) + Math.cos(radlat1) * Math.cos(radlat2) * Math.cos(radtheta);
    dist = Math.acos(dist);
    dist = dist * 180/Math.PI;
    dist = dist * 60 * 1.1515;
    return dist * 1.609344 * 1000;
}