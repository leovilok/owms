#!/bin/sh
# Basic openweathermap scrapper
# Dependencies : curl, grep, sed, cut, tr, jq

#set -x

# Config:

BASE_URL="https://openweathermap.org"

# Set APPID there or it will be scrapped from main page
#APPID=

# old method

# get_app_id () {
#     WIDGET_SCRIPT_PREFIX="/themes/openweathermap/assets/vendor/owm/js/weather-widget-new"
#     WIDGET_SCRIPT_URL="${BASE_URL}$(curl -s "$BASE_URL" | grep -o "$WIDGET_SCRIPT_PREFIX"'\.[^.]*\.js')"
# 
#     curl -s "$WIDGET_SCRIPT_URL" | grep -o 'appidWeatherLayer:"[^"]*' | sed 's/.*:"//''
# }

get_app_id () {
    curl -s "${BASE_URL}/find" | grep -o 'appid=[^"]*' | cut -d= -f2
}

usage () {
    echo "Usage: $0 COMMAND CITY"
    echo "COMMAND=now|hour|hours|week"
}

find_data () {
    curl -s "${BASE_URL}/data/2.5/find?q=$1&appid=${APPID}"
}

first_match_id () {
    find_data "$1" | jq -r '.list[0].id'
}

first_match_coord () {
    find_data "$1" | jq '.list[0].coord | .lat, .lon' | tr '\n' '\t'
}

find () {
    find_data "$1" | jq -r '.list[]|.name+", ID="+(.id|tostring)+" coords:"+([.coord.lat, .coord.lon]|tostring)'
}

onecall () {
    curl -s "${BASE_URL}/data/2.5/onecall?lat=$1&lon=$2&lang=${LANG:0:2}&units=metric&appid=${APPID}"
}

now () {
    #    COORDS="$(first_match_coord "$1")"
    #    LAT="$(echo $COORDS | cut -f1)"
    #    LON="$(echo $COORDS | cut -f2)"
    onecall $(first_match_coord "$1") |\
    jq -rj '.current | .temp, "°C (ressenti : ", .feels_like, "°C) ",'\
'   .pressure, "hPa ", .humidity, "% d'\''humidité, ",'\
'   .clouds, "% de couverture nuageuse, vent :", .wind_speed, "m/s, ", .weather[0].description'
    echo # add missing newline
}

hour () {
    onecall $(first_match_coord "$1") |\
    jq -r ".minutely[].precipitation" |\
    awk -v 'ORS=' '{if($1 == 0)print" ";else if($1<0.2)print".";else if($1<1)print"1";else if($1<2)print"2";else print"x"}'
    echo
    echo "|'''''''''''''^''''''''''''''|''''''''''''''^''''''''''''''|"
}

hours () {
    onecall $(first_match_coord "$1") |\
    jq -r '.hourly[]|(.dt | localtime | strftime("%HH: "))+(.temp|tostring)+"°C, "'\
'   +(.pop|tostring)+" proba. de précipitations, "+(.clouds|tostring)+"% de couverture, "+.weather[0].description'
}

week () {
    onecall $(first_match_coord "$1") |\
    jq -r '.daily[]|(.dt | localtime | strflocaltime("%a %e %b: "))+(.temp.min|tostring)+" à "+(.temp.max|tostring)+"°C, "'\
'   +(.pop|tostring)+" proba. de précipitations, "+.weather[0].description'
}

if [[ $# -le 0 ]] ; then
    usage
    exit 1
fi

APPID=${APPID:-$(get_app_id)}

#echo "$APPID"

COMMAND=$1
shift

case "$COMMAND" in
    find)
        find "$@"
        ;;
    now)
        now "$@"
        ;;
    hour)
        hour "$@"
        ;;
    hours)
        hours "$@"
        ;;
    week)
        week "$@"
        ;;
    *)
        echo "Unknown command" >&2
        usage
        ;;
esac

