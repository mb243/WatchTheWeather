#!/bin/bash
# requires fold, wget, xmlstarlet, find, tr, awk
# RPi 320x240 LCD is 53x20 at 6x12 font

zip="12345"								# Set to your zipcode
apikey=yourapikeyhere			# Set to your wunderground API key. See http://www.wunderground.com/weather/api/
apiurl=http://api.wunderground.com/api	# Do not change
refetch=10								# API data refetch time, in minutes (15 recommended, <4 will exceed free API limit)
refresh=30								# time (in seconds) to wait between screen refreshes # not yet implemented

# main loop

# check age of cache files. If allowable, delete it to refetch data
# 1 second pauses to allow for disk writes to settle and help prevent errors
find ./ -mmin +$refetch -name wx_forecast.xml -delete
if [ ! -f wx_forecast.xml ]; then
  sleep 1
  wget $apiurl/$apikey/forecast/q/$zip.xml -qO wx_forecast.xml
  sleep 1
fi

find ./ -mmin +$refetch -name wx_conditions.xml -delete 
if [ ! -f wx_conditions.xml ]; then
  sleep 1
  wget $apiurl/$apikey/conditions/q/$zip.xml -qO wx_conditions.xml
  sleep 1
fi

#Reference the wunderground API documentation and the downloaded xml format for data
#use 'xmlstarlet el filename.xml' to see the xml tree elements
#
#xmlstarlet command and xml tree reference variables
xmlcmd="xmlstarlet sel -t -v"
XMLSF="$xmlcmd //response/forecast/simpleforecast/forecastdays"
XMLTF="$xmlcmd //response/forecast/txt_forecast/forecastdays"
XMLCC="$xmlcmd //response/current_observation"
#
# set variables from xml
# there's probably a better way to do this, but this is plenty fast
display_location=`$XMLCC/display_location/full wx_conditions.xml`
temp=`$XMLCC/temp_f wx_conditions.xml`
temperature_string=`$XMLCC/temperature_string wx_conditions.xml`
feelslike=`$XMLCC/feelslike_f wx_conditions.xml`
heat_index=`$XMLCC/heat_index_f wx_conditions.xml`
windchill=`$XMLCC/windchill_f wx_conditions.xml`
relative_humidity=`$XMLCC/relative_humidity wx_conditions.xml`
weather=`$XMLCC/weather wx_conditions.xml`
pressure=`$XMLCC/pressure_in wx_conditions.xml`
pressure_trend=`$XMLCC/pressure_trend wx_conditions.xml`
if [[ "$pressure_trend" == "0" ]]; then pressure_trend="="; fi
UV=`$XMLCC/UV wx_conditions.xml | awk -F. '{print $1}'`
precip_1hr=`$XMLCC/precip_1hr_in wx_conditions.xml`
precip_today=`$XMLCC/precip_today_in wx_conditions.xml`

high=`$XMLSF/forecastday[1]/high/fahrenheit wx_forecast.xml`
low=`$XMLSF/forecastday[1]/low/fahrenheit wx_forecast.xml`
DAY=`$XMLSF/forecastday[1]/date/weekday wx_forecast.xml`
DATE=`$XMLSF/forecastday[1]/date/pretty_short wx_forecast.xml`
maxwind=`$XMLSF/forecastday[1]/maxwind/mph wx_forecast.xml`
maxwind_dir=`$XMLSF/forecastday[1]/maxwind/dir wx_forecast.xml`
avewind=`$XMLSF/forecastday[1]/avewind/mph wx_forecast.xml`
avewind_dir=`$XMLSF/forecastday[1]/avewind/dir wx_forecast.xml`
snow_day=`$XMLSF/forecastday[1]/snow_day/in wx_forecast.xml`
snow_night=`$XMLSF/forecastday[1]/snow_night/in wx_forecast.xml`
snow_allday=`$XMLSF/forecastday[1]/snow_allday/in wx_forecast.xml`
qpf_day=`$XMLSF/forecastday[1]/qpf_day/in wx_forecast.xml`
qpf_night=`$XMLSF/forecastday[1]/qpf_night/in wx_forecast.xml`
qpf_allday=`$XMLSF/forecastday[1]/qpf_allday/in wx_forecast.xml`

title_1=`$XMLTF/forecastday[1]/title wx_forecast.xml | tr '[:lower:]' '[:upper:]'`
fcttext_1=`$XMLTF/forecastday[1]/fcttext wx_forecast.xml`
pop_1=`$XMLTF/forecastday[1]/pop wx_forecast.xml`
title_2=`$XMLTF/forecastday[2]/title wx_forecast.xml | tr '[:lower:]' '[:upper:]'`
fcttext_2=`$XMLTF/forecastday[2]/fcttext wx_forecast.xml`
pop_2=`$XMLTF/forecastday[2]/pop wx_forecast.xml`
title_3=`$XMLTF/forecastday[3]/title wx_forecast.xml | tr '[:lower:]' '[:upper:]'`
fcttext_3=`$XMLTF/forecastday[3]/fcttext wx_forecast.xml`

#display report 
#
#sometimes wunderground omits data from the xml forecast or sends back a malformed
#xml document. You could rotate the xml cache files and use the old ones as a
#fallback if you so desired, but I find the 15 minute update period to be
#just fine, and I don't mind waiting for an update.

echo "Currently at ${display_location}, $zip:"
echo -n "${weather}, ${temp} F" 
if [[ "$windchill" != "NA" ]] 
  then echo ", (Wind Chill ${windchill} F)"
  else if [[ "$heat_index" != "NA" ]]
    then echo ", (Heat Index ${heat_index} F)"
    else if [[ "${feelslike}" != "$temp" ]] 
      then echo ", (Feels like ${feelslike} F)"
      else echo "."  
    fi 
  fi
fi 
echo "Humidity ${relative_humidity}, Pressure ${pressure}\"(${pressure_trend}), UV index $UV/10"  
#echo 
echo "Today: ${low}/${high} F, wind ${avewind_dir:-"NA"} @ ${avewind:-"NA"} mph (Gust ${maxwind_dir:-"NA"} @ ${maxwind:-"NA"} mph)"
if [[ "$qpf_allday" != "0.00" ]]; then echo "RAIN: AM ${qpf_day:-"NA"}in (${pop_1}%), PM ${qpf_night:-"NA"}in (${pop_2}%), Total: ${qpf_allday:-"NA"}in"; fi
if [[ "$snow_allday" != "0.0" ]]; then echo "SNOW: AM ${snow_day:-"NA"}in, PM ${snow_night:-"NA"}in, Tot: ${snow_allday:-"NA"}in"; fi
if [[ "$precip_today" != "0.00" ]]; then echo "Total Precip: ${precip_1hr}in last hour, ${precip_today}in today"; fi
echo
echo "${title_1}: $fcttext_1" | fold -sw $COLUMNS
echo "${title_2}: $fcttext_2" | fold -sw $COLUMNS
echo "${title_3}: $fcttext_3" | fold -sw $COLUMNS
echo "( Data from wunderground.com, every ${refetch} min )"
#sleep $refresh
