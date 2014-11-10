var dbUrl = process.env.MONGOLAB_URI || "sfstreets",
    coll = ["streets"],
    db = require("mongojs").connect(dbUrl, coll),
    moment = require('moment');
exports.nearby = function(lat, lon, maxDistance, callbackFn) {
    if (maxDistance > 1000) maxDistance = 1000;
    console.log('Issuing query for ' + lat + ', ' + lon + ' at ' + maxDistance + 'm')
    db.streets.find({
        geometry: {
            $near: { 
                $geometry : {
                    type: "Point",
                    coordinates: [lon, lat]
                },
                $minDistance: 1,
                $maxDistance: maxDistance
            }
        }
    },
    function(err, res) {
        var today = new Date();
        var todayOfWeek = today.getDay();
        var resultset = []

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
                    ' is swept ' +
                    prettyPrintWeeksOfMonth(sweep) +
                    ' on ' + 
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
        callbackFn(resultset);
    });
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
        return "every week including holidays";
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
