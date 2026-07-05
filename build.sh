#!/bin/bash

exec \
zig build-exe \
    check-bootc-and-reboot.zig \
    -O ReleaseSmall \
    -dead_strip \
    -fstrip \
    -fsingle-threaded \
    -fno-unwind-tables \
    --stack 0 \
    -target x86_64-linux
