# rock-4d-pwm
A half-assed "guide" for PWM control on Radxa ROCK 4D in Armbian, primarily for PWM-controlled fans.

This is NOT for utilizing the built-in 2-pin fan header. That is already handled by Armbian with `pwm-fan`. [Here](https://smarthomecircle.com/armbian-pwm-custom-fan-speed-curve-overlay) is a good guide for that.

## Tested Using
- [Radxa ROCK 4D](https://radxa.com/products/rock4/4d/)
- [Armbian](https://armbian.com/boards/radxa-rock-4d) ([Trixie_vendor_minimal](https://dl.armbian.com/radxa-rock-4d/Trixie_vendor_minimal))
- [GeeekPi PWM 4010 5V Fan](https://www.amazon.com/GeeekPi-Raspberry-Controllable-Adjustment-40x40x10mm/dp/B092YXQMX5)

Will probably work on other Armbian releases as well, but only tested under vendor kernel 6.1.


## Pre-Setup
![ROCK 4D GPIO](https://docs.radxa.com/img/rock4/4d/rock4d-40-pin-gpio.webp)

* Connect the fan to power and the blue PWM wire to GPIO 22. For the ROCK 4D, only GPIO 22 works "out of the box" without much additional effort.

* Install Armbian to whatever medium you use.

## Setup
Refer heavily to the docs, especially for the 4D as the GPIO seems to be a bit unique in places. https://docs.radxa.com/en/rock4/rock4d/hardware-use/pin-gpio#gpio-features

1. When booted into Armbian and after the initial setup:

        ls /boot/dtb/rockchip/overlay/ | grep pwm

    And in that list we see `rk3576-pwm2-ch7-m2`, which is the only available PWM that is exposed in the GPIO as per the docs. So, to add this overlay:

        sudoedit /boot/armbianEnv.txt


    And add this line:

        overlays=rk3576-pwm2-ch7-m2

    Or if overlays already exists:

        overlays=overlay1 overlay2 rk3576-pwm2-ch7-m2

    And reboot.

When logged back in, you'll need to create a script that will run in the background to control the fan speed based on the CPU temperature. First you need to find the correct PWM chip to control, if using the ROCK 4D it is `pwmchip1` and you can skip to step 2, but to find out yours:

    sudo cat /sys/kernel/debug/pwm

Then locate the correct PWM device. If you have `pwm-fan` enabled, make sure you do not select that one, it will show.

    platform/2ade7000.pwm, 1 PWM device
     pwm-0   (sysfs               ): requested enabled period: 40000 ns duty: 0 ns polarity: normal
              ^^^^^^ THIS ONE
    
    platform/2ade5000.pwm, 1 PWM device
     pwm-0   (pwm-fan             ): requested period: 40000 ns duty: 0 ns polarity: normal
              ^^^^^^ NOT THIS ONE

Then run:

    ls -la /sys/class/pwm/pwmchip*/device

and match the pwmchip# to the pwm device from the previous command.

2. Now we can actually make the script:

        sudoedit /usr/local/bin/fan-control.sh

    And copy the contents of `fan-control.sh` in this repo, editing the variables at the top as needed. This is the exact script I use and it provides a simple, linear PWM control based on the temperature range.

    Next, we need the systemd service so it actually runs in the background:

        sudoedit /etc/systemd/system/fan-control.service

    And copy the contents of `fan-control.service` as is. Now to enable the service:

        sudo chmod +x /usr/local/bin/fan-control.sh
        sudo systemctl daemon-reload
        sudo systemctl enable --now fan-control.service

    And to verify it's running:

        sudo systemctl status fan-control.service

Congrats! Now you have PWM control on GPIO 22.