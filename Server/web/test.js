var geodata = require('./geodata.js')

//37.776222, -122.430389
//37.77908, -122.42075
// cynthia 37.7985548,-122.4208524
var lat = parseFloat('37.776222'),
    lon = parseFloat('-122.430389');

geodata.nearby(lat, lon, function(docs) {
    var today = new Date();
    var todayOfWeek = today.getDay();

    for (var i = 0; i < docs.length; i++) {
        // console.log(docs[i].properties.STREETNAME)
        // console.log(docs[i].properties.WEEKDAY)
        var sweep = docs[i].properties;

        var sweepingDay = convertWeekdayStringToNumber(sweep.WEEKDAY);
        if( todayOfWeek == sweepingDay ||
            addOneDayOfWeek(todayOfWeek) == sweepingDay ||
            sweepingDay == 7) {

            console.log(sweep.STREETNAME +
                ' is swept ' +
                prettyPrintWeeksOfMonth(sweep) +
                ' on ' + 
                sweep.WEEKDAY +
                ' from ' +
                sweep.FROMHOUR +
                ' to '
                + sweep.TOHOUR);
            console.log('block ' + sweep.BLOCKSIDE)
            console.log('left ' + sweep.LF_FADD + ' ' + sweep.LF_TOADD)
            console.log('right ' + sweep.RT_FADD + ' ' + sweep.RT_TOADD)
        }
    };

    process.exit();
});

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