#!/bin/bash

CHIP_PATH="/sys/class/pwm/pwmchip1"
PERIOD=40000 # =25kHz period, 40000ns, typical for fans
PWM_MIN=8000 # ~20% — adjust if fan won't start this low
PWM_MAX=40000 # Must be <= PERIOD
TEMP_MIN=48
TEMP_MAX=65
POLL_INTERVAL=1 # seconds between each update

# Wait for the correct pwmchip to appear (the one from rk3576-pwm2-ch7-m2)
echo "Waiting for $CHIP_PATH..."
while [ ! -e "$CHIP_PATH" ]; do
    sleep 1
done

# Initialize
echo 0 > $CHIP_PATH/export 2>/dev/null || true
echo "Waiting for PWM channel export..."
while [ ! -e "$CHIP_PATH/pwm0" ]; do
    sleep 0.5  # give sysfs time to create pwm0 entries
done

echo $PERIOD > $CHIP_PATH/pwm0/period
echo normal > $CHIP_PATH/pwm0/polarity
echo 0 > $CHIP_PATH/pwm0/duty_cycle
echo 1 > $CHIP_PATH/pwm0/enable

set_speed() {
    local temp=$1
    local duty

    if [ $temp -le $TEMP_MIN ]; then
        duty=0
    elif [ $temp -ge $TEMP_MAX ]; then
        duty=$PWM_MAX
    else
        # Linear interpolation: duty = m*temp + b
        duty=$(( ( (temp - TEMP_MIN) * (PWM_MAX - PWM_MIN) / (TEMP_MAX - TEMP_MIN) ) + PWM_MIN ))
    fi

    echo $duty > $CHIP_PATH/pwm0/duty_cycle
}

echo "Fan control running."

FAN_STATE=0
THRESHOLD_START_TIME=0

while true; do
    TEMP=$(( $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 50000) / 1000 ))

    if [ $TEMP -ge $TEMP_MIN ]; then
        if [ $FAN_STATE -eq 0 ]; then
            # Start timer if fan is off and threshold is reached
            if [ $THRESHOLD_START_TIME -eq 0 ]; then
                THRESHOLD_START_TIME=$(date +%s)
            elif [ $(($(date +%s) - THRESHOLD_START_TIME)) -ge 3 ]; then
                # 3-second delay passed, turn fan on
                FAN_STATE=1
                THRESHOLD_START_TIME=0
            fi
        else
            set_speed $TEMP
        fi
    elif [ $TEMP -lt $TEMP_MIN ]; then
        # Temp below threshold — turn fan off immediately and reset timer
        if [ $FAN_STATE -eq 1 ]; then
            FAN_STATE=0
            set_speed $TEMP
        fi
        THRESHOLD_START_TIME=0
    fi

    sleep $POLL_INTERVAL
done