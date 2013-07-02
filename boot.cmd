setenv bootargs console=${console} root=${root} loglevel=${loglevel} ${panicarg} ${extraargs}
ext2load mmc 0 0x43000000 script.bin
ext2load mmc 0 0x48000000 ${kernel}
bootm 0x48000000
