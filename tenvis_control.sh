#!/bin/bash
source config.sh

flags='d:g:hi:kl:m:r:s:u:v'
tenvis_show_help () { cat << EOF
	
    Usages:
        ${0##*/} -[$flags]

    Movement:
        -l [X]    pan X% left (-1 to pan forever, 0 to stop)
        -r [X]    pan X% right (-1 to pan forever, 0 to stop)
        -u [X]    tilt X% up (-1 to tilt forever, 0 to stop)
        -d [X]    tilt X% down (-1 to tilt forever, 0 to stop)
        -s X      save current position to X
        -g X      go to position X
        -k        use keyboard arrows
        
    Features:
        -m 0-2    movement detection monitoring
                  0=Off  2=On
        -i 0-2    control the built-in LED
                  0=Off  1=On  2=Blink
    Other:
        -h        display this help
        -v        verbose

EOF
}

tenvis_settings () {
    local type=$1 # Misc / Alarm
    local data=$2
    wget -${verbose}O /dev/null "http://$tenvis_ip:$tenvis_port/goform/formSet${type}Cfg" --post-data "$data" --user=$tenvis_user --password=$tenvis_password --auth-no-challenge
}
tenvis_settings_led () {
    tenvis_settings Misc "chkled=$1"
}
tenvis_settings_alarm () {
    local mvdet_levels=(494 490 486 480 471 468 456)
    local mvdet_level=${mvdet_levels[tenvis_sensibility-1]}
    tenvis_settings Alarm "chkmove_det=$1&mvdet_level=$mvdet_level&osd_show=on&alm_voice=on&alm_email=on&almptz_pos=0&alm_interval=$tenvis_interval&sch_value="
}

tenvis_action () { # action $code $value
    wget -${verbose}O /dev/null "http://$tenvis_ip:$tenvis_port/media/?action=cmd&code=$1&value=$2" --user=$tenvis_user --password=$tenvis_password --auth-no-challenge
}
tenvis_start() { # start $value
    tenvis_action 2 $1
}
tenvis_stop () { # stop $value
    tenvis_action 3 $1
}
tenvis_move () { # move [x|y] $value $percentage
    if [ $3 -eq -1 ]; then
        tenvis_start $2
    elif [ $3 -eq 0 ]; then
        tenvis_stop $2
    else
        tenvis_start $2
        duration="tenvis_${1}_duration"
        sleep `awk "BEGIN {printf \"%.1f\",$3*${!tenvis_duration}/100}"`
        tenvis_stop $2
    fi
}

keyboard=false
verbose='q'
while getopts ":$flags" o; do
    case "${o}" in
        d) tenvis_move y 2 ${OPTARG};;
        g) tenvis_action 13 ${OPTARG};;
        h) tenvis_show_help;;
        i) tenvis_settings_led ${OPTARG};;
        k) keyboard=true;;
        l) tenvis_move x 4 ${OPTARG};;
		m) tenvis_settings_alarm ${OPTARG};;
        r) tenvis_move x 3 ${OPTARG};;
        s) tenvis_action 11 ${OPTARG};;
		u) tenvis_move y 1 ${OPTARG};;
		v) verbose='';;
        *) tenvis_show_help; exit 1;;
    esac
done

if [ $keyboard = true ]; then
    #printf '\e[?8l' # disable key auto-repeat
    old=false
    while true; do
        read -rsn1 -t 0.1;
        case "$REPLY" in
            $'\x1b')    # Handle ESC sequence.
                # Flush read. We account for sequences for Fx keys as
                # well. 6 should suffice far more then enough.
                read -rsn1 -t 0.1 tmp
                if [[ "$tmp" == "[" ]]; then
                    read -rsn1 -t 0.1 tmp
                    case "$tmp" in
                        "A") new=1;;
                        "B") new=2;;
                        "C") new=3;;
                        "D") new=4;;
                    esac
                    if [ "$new" != "$old" ]; then
                        old=$new
                        echo $old
                        start $old
                    fi
                fi
                # Flush "stdin" with 0.1  sec timeout.
                read -rsn5 -t 0.1
                ;;
            # timeout
            '') if [ "$old" != false ]; then 
                    echo "stop"
                    stop $old
                    old=false
                fi
        esac
    done
    #printf '\e[?8h' # re-enable key auto-repeat
fi
