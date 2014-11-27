var dbUrl = process.env.MONGOLAB_URI || "sfstreets",
    coll = ["parking"],
    db = require("mongojs").connect(dbUrl),
    moment = require('moment'),
    async = require('async');
    console.log('db url = ' + dbUrl + ' ' + coll);
exports.nearby = function(lat, lon, maxDistance, callbackFn) {
    if (maxDistance > 250) maxDistance = 250;
    console.log('Issuing query for ' + lat + ', ' + lon + ' at ' + maxDistance + 'm');
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
        queryForStreetSweeping(res, callbackFn);
    });
}

function queryForStreetSweeping(blockfaceResult, callbackFn) {
    console.log('querying for street sweeping against ' + blockfaceResult.length + ' faces');
    // build up the list of queries
    var queries = [];
    for (var i = 0; i < blockfaceResult.length; i++) {
        var query = (function(callback) {
            var blockface = this;
            var lat = blockface.geometry.coordinates[0][1];
            var lon = blockface.geometry.coordinates[0][0];
            console.log('quering for blockface id ' + blockface._id);

            db.collection('streets').find({
                    geometry: {
                        $near: { "type": "Point", "coordinates": [lon, lat] },
                        $minDistance: 0,
                        $maxDistance: 10
                    }
                }
            ,
            (function(err, res) {
                this.sweepings = res;
                console.log('found ' + res.length + ' sweeping results for ' + this._id);
                callback(err, this);
            }).bind(blockface));
        }).bind(blockfaceResult[i]);

        queries.push(query);
    };

    console.log('running ' + queries.length + ' in parallel');
    async.parallel(queries, function(err, results) {
        if(err) throw err;
        callbackFn(results);
    });
}

function prettyPrintSweepingRules() {

    var today = new Date();
    var todayOfWeek = today.getDay();
    var resultset = [];

    for (var i = 0; i < res.length; i++) {
        var sweep = res[i].properties;

        // isSweepInNext24Hours(sweep)

        var sweepingDay = convertWeekdayStringToNumber(sweep.WEEKDAY);
        if( todayOfWeek == sweepingDay ||
            addOneDayOfWeek(todayOfWeek) == sweepingDay ||
            sweepingDay == 7) {
            
            var desc = sweep.LF_FADD + 
                '-' + sweep.LF_TOADD +
                ' ' + 
                sweep.STREETNAME +
                ' will be swept on ' +
                sweep.WEEKDAY +
                ' from ' +
                sweep.FROMHOUR +
                ' to ' +
                sweep.TOHOUR +
                ' on the ' +
                sweep.BLOCKSIDE +
                ' side';


            resultset.push({"description": desc, "datapoint": res[i]});
        }
    };
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
            console.log(blah.toString())

            console.log(thisMoment.toString() + ' ' + todayFromDate.toString() + ' ' + todayToDate.toString())
        } else if (tomorrow == sweepingDay) {
            todayFromDate.add('1', 'days');
            todayToDate.add('1', 'days');

        }
        console.log('from ' + from + ' to ' + to + ' nowHour ' + nowHour)
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
