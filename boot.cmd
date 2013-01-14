setenv bootargs console=${console} root=${root} loglevel=${loglevel} ${panicarg} ${extraargs}
fatload mmc 0 0x43000000 script.bin
fatload mmc 0 0x48000000 ${kernel}
watchdog 0
bootm 0x48000000
