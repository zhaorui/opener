# opener

A simple packet capture & redirect app. Network traffic is captured on primary netowrk interface, such as en0.
Then it woruld be redirected to utun, so we can manipulate theses packets. In this project, I just simply write
packets back to en0 via the NDRV raw socket. It also capture packet passed in, and duplicate that to utun.

## PF rules
set skip on utun6
pass out on en1 route-to utun6 inet all no state
pass in  on en1 dup-to utun6 inet all no state
