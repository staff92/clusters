# REQUIREMENTS

  - VM : scaleway
  - S3 : cloudfare R2

# WORKAROUND

### Create VM / S3 / VAULT

### Hardening VM with ansible

### Create cluster K0s with podman

### Set-up secrets manager and reflector

### Set-up Storage Drivers

### Set-up Authentification + IAM 

### Set up Load-Balancer

### Set up Mail + Alert

### Set-up Applications

# HARDENING LINUX 

ansible-playbook -i hosts ./provisioning/play.yaml --ask-pass

```yaml
#! ROLES
  roles:
    - name: singleplatform-eng.users
    - name: linux-system-roles.sudo
    - name: devsec.hardening.ssh_hardening
    #! delete user like root
    # - name: devsec.hardening.os_hardening
    # - name: geerlingguy.firewall
```

# K0S PODMAN

Launch single node 

```bash
sudo -i

alias docker=podman

mkdir /var/lib/k0s && mkdir /var/lib/juicefs && mkdir /var/openebs

docker run -d --name k0s-controller --hostname k0s-controller \
  --privileged \
  -v /var/openebs/:/var/openebs \
  -v /var/lib/k0s:/var/lib/k0s \
  -v /var/lib/juicefs/:/var/lib/juicefs/:rshared \
  --tmpfs /run \
  --tmpfs /tmp \
  --network host \
  --pids-limit -1 \
  -p 6443:6443  \
  docker.io/k0sproject/k0s:v1.35.2-rc.0-k0s.0 \
  k0s controller --enable-worker --single=true --ignore-pre-flight-checks

# debug pod
kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot
```

# K0S STANDALONE


***https://blog.${LDAP_USER1_FIRSTNAME}-robert.info/docs/conteneurs/orchestrateurs/kubernetes/k0s/***

spec.hosts[*].role <string> (required)

  - controller - a controller host
  - controller+worker - a controller host that will also run workloads
  - single - a single-node cluster host, the configuration can only contain one host
  - worker - a worker hos

Apply config 

```
k0sctl apply --config cluster.yaml
k0sctl kubeconfig --config cluster.yaml > kubeconfig
k0sctl backup --config cluster.yaml
```

# FLUX

When bootstrap done, you can add postBuild with secrets to use template values (infrastructure.yaml)

```bash
export GITHUB_TOKEN=<gh-token>

flux bootstrap github \
  --token-auth \
  --owner=staff92 \
  --repository=clusters \
  --branch=main \
  --path=clusters/my-cluster \
  --personal


## GITEA
flux bootstrap git \
  --url=https://gitea.${CLUSTER_DOMAIN}:443/${LDAP_USER1_ID}/k0s.git \
  --branch=main \
  --path=clusters/my-cluster \
  --password=TOKEN_GITEA


#! Add the public key on repo with rw access

flux get kustomizations
flux get sources git     
flux get sources all 

flux debug kustomization infrastructure --show-status #--show-status --show-vars --show-history

flux reconcile source git flux-system

flux reconcile kustomization infrastructure

flux reconcile -n homepage helmrelease homepage

flux reconcile kustomization infrastructure --with-source

#### FORCE SYNC

flux reconcile -n media helmrelease servarr --force

#! resync mirroring secrets all over namespaces

kubectl annotate secret bw-auth-token reflector-reload=$(date +%s) --overwrite

kubectl annotate helmrelease my-app -n default \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

# Reconcile the HelmRelease and refresh its chart source
flux reconcile hr my-app -n default --with-source

```

# SECRETS 

**reflector** : Share secrets between namespaces

**sm-operator-system** : Bitwarden Secrets Manager - sm-operator 

```bash
#! secret client oidc
docker run --rm authelia/authelia:latest authelia crypto hash generate pbkdf2 --password "XXXXX"

openssl rand -hex 64   

openssl genrsa 4096

pwgen -y


#! don't forget reflector annotations on secret to share it
kubectl create -n sm-operator-system secret generic bw-auth-token \
  --from-literal=token=XXXX 
```

Add the namespace you want to share the secret (on the root secret in namespace sm-operator-system)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: bw-auth-token
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
    reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
    reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "kube-system,authelia,vault,lldap,maildev,gitea,media,wg-portal,gatus,flux-system"
```

Don't forget to apply bitwarden secrets (clusters/perso/secrets.yaml) use in infra as code config (domain name, username, IP)

Reset sync between bitwarden and k0s cluster 

```bash
kubectl annotate bitwardensecrets.k8s.bitwarden.com bitwardensecret-sample force-sync=$(date +%s) --overwrite
```

# STORAGE

## openebs-hostpath

Default local path in /var/openebs

## CSI driver juicefs 

label on namespace to use juice fs

```bash
# in namespace 
metadata:
  labels:
    juicefs.com/enable-injection: "true"
```

Connect to a S3 manually 


```bash

#! NEVER FORMAT IF YOU WANT TO RESTORE => format = reset 

juicefs format \
  --storage s3 \
  --bucket https://s3.eu-west-2.wasabisys.com/contabo-media \
  --access-key ACCESS_KEY \
  --secret-key SECRET_KEY \
  redis://redis.kube-system.svc.cluster.local:6379/1 \
  test2


juicefs format --storage s3 --bucket https://s3.eu-west-2.wasabisys.com/contabo-media --access-key XXXX --secret-key XXXXX --force redis://redis.kube-system.svc.cluster.local:6379/1 test2

```

Use this to transfer redis metadata inside a container to load it  

```bash
cat << EOF > toto.json
{
  "Setting": {
    "Name": "test",
    "UUID": "df357eae-cbc8-41b0-81c1-bab489844b89",
    "Storage": "s3",
EOF
```


Restore with metada for redis => Juicefs always (every 1h) backup automatically redis metadata

```bash
# WORKAROUND 
#! https://juicefs.com/docs/community/metadata_dump_load/

#! FLUSH be carefull

kubectl exec -it -n kube-system redis-0 -- redis-cli -n 1 FLUSHDB

#! LOAD 

juicefs load redis://redis.kube-system.svc.cluster.local:6379/1 meta-dump.json 
juicefs config redis://redis.kube-system.svc.cluster.local:6379/1 --secret-key XXXX

# TEST with juicefs-plugin pod

juicefs status redis://redis.kube-system.svc.cluster.local:6379/1
juicefs mount redis://redis.kube-system.svc.cluster.local:6379/1 /tmp/test => check pvc/pv 

# Check

juicefs summary ./pvc-6a6c8859-7c66-4b86-8c30-0e3722102a14
juicefs quota list redis://redis.kube-system.svc.cluster.local:6379/1
```

To bind old data (old helm chart delete) to new helm chart (more simple to just copy / paste inside the new pvc)

```bash
#! delete new empty pvc / pv 
kubectl delete pvc servarr-jellyfin-media -n media
kubectl delete pv pvc-807edeed-7558-45c8-8076-5dc04c4ad463

#! Remove claim for old pv 
kubectl patch pv pvc-3d3bc17f-5004-47b9-8d4a-7257abd4c20a -p '{"spec":{"claimRef":null}}'

#! Should be available now
pvc-3d3bc17f-5004-47b9-8d4a-7257abd4c20a   1Ti        RWX            Retain           Available                                       juicefs-sc         <unset>                          23h

#! Apply new pvc with the old patched pv 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: servarr-jellyfin-media
  namespace: media
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: juicefs-sc
  volumeName: pvc-3d3bc17f-5004-47b9-8d4a-7257abd4c20a
  resources:
    requests:
      storage: 1Ti

#! pv
pvc-3d3bc17f-5004-47b9-8d4a-7257abd4c20a   1Ti        RWX            Retain           Bound    media/servarr-jellyfin-media        juicefs-sc         <unset>                          23h

# pvc
servarr-jellyfin-media    Bound    pvc-3d3bc17f-5004-47b9-8d4a-7257abd4c20a   1Ti        RWX            juicefs-sc         <unset>                 7m51s

# Restart all pod link with old pv
kubectl rollout restart deployment servarr-jellyfin servarr-qbittorrent servarr-radarr servarr-bazarr servarr-cleanuparr

# Clean old juicefs-k0s-controller-pvc => delete + edit (finalizer)
juicefs-k0s-controller-pvc-3d3bc17f-5004-47b9-8d4a-7257abd4c20a-owkslw   1/1     Running   0          13m
juicefs-k0s-controller-pvc-5a3998ae-5a13-46a9-b69c-330314b2f57a-dlxjzq   1/1     Running   0          16m
juicefs-k0s-controller-pvc-807edeed-7558-45c8-8076-5dc04c4ad463-txubsi   1/1     Running   0          26m

# should only have pvc-3d3bc17f-5004-47b9-8d4a-7257abd4c20a
juicefs-k0s-controller-pvc-3d3bc17f-5004-47b9-8d4a-7257abd4c20a-owkslw   1/1     Running   0            15m
```


We only need one pvc with R/W pods access

**servarr-jellyfin-media**:
  - servarr-radarr
  - servarr-sonarr
  - servarr-bazarr
  - servarr-lidarr
  - servarr-cleanuparr
  - servarr-qbittorrent
  - servarr-jellyfin
  - sftp-sftpgo


You have one pod by pvc mounted

```
juicefs-k0s-controller-pvc-d135f4a0-5822-46fd-a19e-08899dae4642-dtojdv

pvc-d135f4a0-5822-46fd-a19e-08899dae4642   

1Ti        
RWX        
media/servarr-jellyfin-media        
juicefs-sc   

Media
.
├── downloads (qittorrent)
│
├── movies  (others)
├── music   (others)
├── tv      (others)
│ 
└── sftp_users  (sftp)
[...]
```

Clean up metadata (⚠️ Need to fsk / compact / gc often)

```
# Mount
juicefs mount redis://redis.kube-system.svc.cluster.local:6379/1 /tmp/test

# Check metadata
juicefs fsck redis://redis.kube-system.svc.cluster.local:6379/1 

# Compact (be carefull can crash the pod - Never on the pvc controller)
juicefs compact /tmp/test --threads 8

# Live check
juicefs stats /tmp/test

# Clean
juicefs gc --delete --compact redis://redis.kube-system.svc.cluster.local:6379/1 

# Check
juicefs summary /tmp/test
```

# LOAD BALANCER + ANALYTICS 

Opensource analytics => Umami
plugin traefik => https://plugins.traefik.io/plugins/6710d226573cd7803d65cb15/traefik-umami-feeder

```
  plugins:
    umami:
      moduleName: github.com/astappiev/traefik-umami-feeder
      version: v1.4.1
```

You need to keep the default login [admin/umami] to use the plugin !

# MAIL 

## forwarder 

maildev in auto relay mode. Will be used as smtp server for all other apps ! 

```bash
curl smtp://localhost:1025 --mail-from test@maildev.com --mail-rcpt ${LDAP_USER1_EMAIL} --upload-file ./mail.txt
```

Script for welcome mail => Need LDAP and SMTP connection (port forwarding) 

```bash
bash mail/welcome_mail.sh ${LDAP_USER2_EMAIL} [...] toto@gmail.com
```

## local

Full stack mail (postfix + dovecot + roundcube)

**Find the DKIM key in pod logs** 

| Sub domain | Type | Value |
|-----|-----|--------|
| mail._domainkey | TXT | "v=DKIM1; h=sha256; k=rsa; s=email; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsmOPUcSoMxDPenX0pPvRhVOyWCygbm1aA0QZxVLZ9gmd1zeqbAJp7SyX59oFAvHngepX9j5NB9KPhyKClRQZu53QEP+IZYykVbFp1ijkO76HOlC+1ODLn0wdcZYfMY05ok+GhPHKH7mwMTjuiZOyAUqxWjWoBoKt2dgoRf3XzQOKG6hqnILrMP5O9xsyU5SgC/HfHyetCxnzQDp0a0HFyOQJS6IBdGPQd4E8pIOcki6smPIcEHKINRBntdty1R2kP6zcMZSxvnUi3IXZ7ZWl1AdmLTx6UfbzTnZsFqig243hl1mdBuIBTC270XzbHhP+yTb281WgQ9CNZg3YTfKx2wIDAQAB" |
| @ | MX | mail.${CLUSTER_DOMAIN}. |
| @ | MX | "v=spf1 ip4: 1.1.1.1 -all" |
| mail | A | 1.1.1.1 |
| _dmarc | jwtSecret | "v=DMARC1; p=none;"|


Dovecot : https://gitlab.mareo.fr/services/charts/dovecot/-/tree/main ( LDAP, LTMP, QUOTA, IMAP)
Webmail : https://github.com/encircle360-oss/helm-charts/tree/main/charts/roundcube
helm webmail : https://artifacthub.io/packages/helm/encircle360-oss/roundcube

https://github.com/docker-mailserver/docker-mailserver-helm/blob/master/charts/docker-mailserver/values.yaml


setup dovecot-master add admin@${CLUSTER_DOMAIN}

doveadm mailbox list -u admin@${CLUSTER_DOMAIN}
doveadm mailbox status -u admin@${CLUSTER_DOMAIN} all Sent

rspamadm pw
supervisorctl status rspamd

/tmp for cert 

#### 25/TCP,465/TCP,587/TCP,143/TCP,993/TCP,11334/TCP

| Port Interne | Port Externe | Protocole | Service | Explication |
|---|---|---|---|---|
| 25 | 30025 | TCP | SMTP | Port standard pour l'envoi d'emails entre serveurs (non sécurisé) |
| 465 | 30465 | TCP | SMTPS | Port SMTP sécurisé (SSL/TLS) pour les clients email |
| 587 | 30587 | TCP | Submission | Port SMTP avec authentification pour les clients email |
| 143 | 30143 | TCP | IMAP | Port standard pour la réception d'emails (non sécurisé) |
| 993 | 30993 | TCP | IMAPS | Port IMAP sécurisé (SSL/TLS) pour les clients email |
| 11334 | 31176 | TCP | Rspamd | Interface web de Rspamd (filtre anti-spam) |

# ALERT

## Cluster

github : https://github.com/caronc/apprise/wiki/Notify_email
doc : https://docs.robusta.dev/master/configuration/sinks/mail.html
helm: https://github.com/robusta-dev/robusta/blob/master/helm/robusta/values.yaml

## Probe (https,dns...)

Gatus

# AUTHENTIFICATION

  - LDAP for user registration  
  - AUTHELIA for proxy auth & apps with SSO

To use forward auth, just add annotation on ingress / ingressroute / httproute

```yaml
    annotations:
      traefik.ingress.kubernetes.io/router.middlewares: authelia-forwardauth-authelia@kubernetescrd
```

# SERVARR [MANUAL]

```markdown
⚠️ only jellyfin and seerr are directly exposed on internet (with SSO)
⚠️ Don't forget user groups
⚠️ S3 bucket for media categories (movies / tv / music)
```


```file
  - Bazarr: Subtitle manager
  - Flaresolverr: Cloudflare bypass tool
  - Jellyfin: Media streaming
  - Prowlarr: Indexers manager
  - qBittorrent: Download client
  - Radarr: Movies manager
  - cleanuparr : Clean up 
  - Seer: Media requester / Jellyseerr
  - Sonarr: TV shows manager
```


## JELLYFIN

Need first Connection to create admin user and create movies / tv / music libraries  => check juicefs

```
⚠️ Need Authelia setup 
SSO Authlia plugin 
repo url : https://raw.githubusercontent.com/nikarh/jellyfin-plugin-authelia/main/manifest.json
authelia :  https://auth.${CLUSTER_DOMAIN}
groups : jelly_admin
redirect : https://jelly.${CLUSTER_DOMAIN}

⚠️ Need bazarr setup 
Bazarr Subtitles plugin 
repo url: https://raw.githubusercontent.com/enoch85/bazarr-jellyfin/main/manifest.json

⚠️ Need mail relay setup 
repo url : https://raw.githubusercontent.com/Sanidhya30/Jellyfin-Newsletter/master/manifest.json
maildev-smtp.maildev 
1025
test
test
noreply@jellyfin.org
${LDAP_USER2_EMAIL},${LDAP_USER1_EMAIL}
add radarr/sonarr for upcoming
```

Custom Login UI (Dashboad > Slogan)

***CSS***

```
.btnForgotPassword {
    display: none !important;
}

.custom-reset-link {
    display: block;
    text-align: center;
    margin-top: 15px;
    color: #00a4dc;
    font-size: 0.9em;
    text-decoration: none;
    padding: 10px;
}

.custom-reset-link:hover {
    color: #0088cc;
    text-decoration: underline;
}
```

***HTML*** 

```
<a href="https://ldap.${CLUSTER_DOMAIN}/reset-password/step1" target="_blank" rel="noopener noreferrer" class="custom-reset-link">Mot de passe oublié ?</a>
```

Desktop application alaytics : **https://github.com/fredrikburmester/streamystats**


podman generate kube -s -f streamstats.yaml containerID 9fa072a94603 e503f6b29eb6


## QBITTORRENT

```markdown
⚠️ check in pod logs to have the tempory admin password for qbit

⚠️ Disable auth => Tools > Options > WebUI > Bypass authentication for clients in whitelisted IP subnets checked : add 0.0.0.0/0 (all) > SAVE

⚠️ Change default download path => Tools > Options > Downloads > Change default download path => /media/downloads
```

***CUSTOM UI***

```
add env vars
DOCKER_MODS=ghcr.io/vuetorrent/vuetorrent-lsio-mod:latest

Edit your qBittorrent configuration to use alternative WebUI

 Tools > Options > WebUI > Use alternative WebUI: checked
 Tools > Options > WebUI > Files location: /vuetorrent
```

## PROWLARR

```markdown
⚠️ Settings > Downloads Client > Qbittorrent : 
      - servarr-qbittorrent-web 
      - port 8080

#! Check port service 
⚠️ Settings > Apps > Radarr :
      - servarr-radarr
      - servarr-prowlarr
      - radarr API KEY 
⚠️ Settings > Apps > Sonarr :
      - servarr-sonarr (port 80)
      - servarr-prowlarr
      - sonarr API KEY 
⚠️ Settings > Apps > Lidarr :
      - servarr-lidarr (port 8686)
      - servarr-prowlarr (port 9696)
      - lidarr API KEY 

⚠️ Settings > Indexers > FLareSolverr : 
      - servarr-flaresolverr
      - tag flare
```

***Indexers***

```bash
The Pirate Bay:

Torrent9

TorrentDownload

NorTorrent

ZkTOrrent

World-torrent

cpasbien clone

Uindex

C411

Internet Archive

yggreborn.org 

Indexers → Add Indexer → Generic Torznab

Name : YggReborn
URL : https://www.yggreborn.org
API Path : /api
API Key : XXXXXX
```

Example of Movies / TV for testing : 
  - The Swedish Connection (2026) 1080p H264 iTA EnG Sve MIRCrew - 2G
  - Live Free or Die Hard (2007) - 2,7G
  - Shrek 2 - 6G
  - Mulan (1998) 1080p - 1,3G
  - Tarzan (1999) 1080p - 1,2G
  - The Dinner Game - 3,46G
  - aristocats - 4,4G
  - Empereur kuzco - 1,3G
  - Lady and the tramp - 1,2
  - Peter pan - 1,3
  - The Simpsons - 5,5
  - Bernard et bianca - 4,69

## RADARR

  - ⚠️ Settings > Downloads Client > Qbittorrent : servarr-qbittorrent-web port 8080 

  - ⚠️ Settings > Media Management > Root Folders > Add root folders : /media/movies => Check juicefs

  - (Optionnal) Connect > Email > add all email when movies is grabbed

  - (Max size grabbed) Settings > Indexers > Options > Maximum Size (15G)

  - (Languages) Settings > Custom Formats > Add multi-language EN/FR > Custom needed OK > Then go on Profiles and add scores for each languages

  - Change Language Original to Any in profile **Any** + Add custom score for prefered language 

## SONARR



  - ⚠️ Settings > Downloads Client > Qbittorrent : servarr-qbittorrent-web port 8080

  - ⚠️ Settings > Media Management > Root Folders > Add root folders : /media/tv => Check juicefs


## SEERR

```markdown
# JELLY
⚠️ servarr-jellyfin
⚠️ admin@${CLUSTER_DOMAIN}
⚠️ admin
⚠️ pass

Click on test then save 

# RADARR
⚠️ default server checked
⚠️ server name radarr
⚠️ servarr-radarr
⚠️ api key

Click on test

⚠️ Quality Profile any
⚠️ Root Folder /media/downloads
⚠️ check scan 

Click on save

# SONARR
⚠️ default server checked
⚠️ server name sonarr
⚠️ servarr-sonarr
⚠️ port 80
⚠️ api key

Click on test

⚠️ Quality Profile any
⚠️ Root Folder /media/tv
⚠️ check scan 

Click on save


Settings > Notifications > Email

maildev-smtp.maildev 
1025
test
test
```

Need to add manually all users mail adress because jellyfin doesn't support mail (need first connection to jellyfin to create the user then import it in seerr)

```
Settings > Notification > Email
Enable Agent => enable notification for all users
Embed Poster
maildev-smtp.maildev 
1025
test
test

To change notif Users > {{ name.user }} > Edit Settings > Notifications
```

## CLEANUPARR


```markdown
⚠️ Root account 

⚠️ skip > complete setup 

Connection with root user

⚠️ Settings > General > Authentication > Disable check > SAVE

# RADARR
# SONARR
# QBITTORRENT
```

## BAZARR

```markdown
⚠️ Settings > General > Authentication > Disable check > SAVE

providers

BetaSeries
OpenSubtitles.com => username/password

# RADARR
# SONARR
# QBITTORRENT
```


## MUSICSEERR

```
Jellyfin
Lidarr
Brainzmusic (discovery)
```

# VPN

wg-portal Settings to create the Tunnel

```

# Mode serveur | backend: Local WireGuard Backend

172.20.0.1/24 0.0.0.0/0

Point de teminaison vpn.${CLUSTER_DOMAIN}:51820

Port 51820

MTU 1420

Adress IP 10.11.12.1/24 fdfd:d3ad:c0de:1234::1/64

DNS 8.8.8.8 1.1.1.1

Reseau IP 10.11.12.0/24

IP autorisées 0.0.0.0/0 (important)

# allow traffic wgX => eth0 (VM) for internet access 
iptables -t nat -A POSTROUTING -o eno1 -j MASQUERADE
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT
iptables -A FORWARD -i wg0 -o eno1 -j ACCEPT
iptables -A FORWARD -i eno1 -o wg0 -j ACCEPT
```

# SFTP

Connect to webadmin UI with admin credentials then add the group **jelly_admin**

Need first connection to create the user, then in admin panel Users > Actions > Edit then add : 
 - Public keys
 - /srv/sftpgo/sftpgo/data (to access full disk)

Can now download or upload huge files with sftp/scp command port 30022 ( see nodePort of sftp)

```
scp -P 30022 -i ~/.ssh/key fichier.txt user@<IP>:/path/

sftp -P 30022 -i ~/.ssh/key user@<IP>

put fichier.txt /chemin/
get /chemin/fichier.txt .
ls
cd /dossier
```

# BITWARDEN SECRETS 

| app | Secret Key | Bitwarden Secret name | command |
|-----|-----|--------|---------|
| ldap | jwtSecret | ldap-jwt | `openssl rand -base64 32` |
|  | keySeed | ldap-key-seed | `openssl rand -base64 32` |
|  | ldapUserPass | ldap-admin-password | `openssl rand -base64 24` |
|  | user1Password | ldap-${LDAP_USER1_ID}-password | `openssl rand -base64 24` |
|  | userpasswordtemp | ldap-user-password-temp | `openssl rand -base64 24` |
|  | smtpPassword | ldap-smtp-password-maildev | `openssl rand -base64 24` |
| authelia | authentication.ldap.password.txt | ldap-admin-password | *(reprise mdp ldap)* |
|  | identity_validation.reset_password.jwt.hmac.key | authelia-jwt-hmac-key | `openssl rand -hex 32` |
|  | storage.encryption.key | anthelia-storage-key | `openssl rand -hex 32` |
|  | session.encryption.key | authelia-session-key | `openssl rand -hex 32` |
|  | identity_providers.oidc.hmac.key | authelia-oidc-hmac-key | `openssl rand -hex 32` |
|  | oidc.jwk.RS256.pem | authelia-oidc-jwk | `openssl genrsa 4096` |
| wg-portal | bind_password | ldap-admin-password | `openssl rand -base64 24` |
| gitea | bindPassword | ldap-admin-password | *(reprise mdp ldap)* |
|  | bindDn | ldap-binddn | *(DN manuel)* |
| juicefs | name | s3-name | *(manuel)* |
|  | metaurl | s3-metaurl | *(URL manuel)* |
|  | storage | s3-storage | *(manuel)* |
|  | provider | s3-provider | *(manuel)* |
|  | bucket | s3-bucket | *(manuel)* |
|  | access-key | s3-access-key | `openssl rand -hex 16` |
|  | secret-key | s3-secret-key | `openssl rand -hex 32` |
| vaultwarden | admin-token | vault-admin-token | `openssl rand -base64 48` |
|  | sso-client-secret | vaultwarden-sso-client-secret | `openssl rand -base64 32` |
|  | sso-authoriy | vaultwarden-sso-authority | *(URL manuel)* |
|  | sso-client-id | vaultwarden-sso-client-id | *(manuel)* |
| maildev | smtp-outgoing-password | mail-smtp-password | `openssl rand -base64 24` |
| sftp | sftp-admin-password | sftp-admin-password | `openssl rand -base64 16` |
| helm values | sftp-admin-password | sftp-admin-password | `openssl rand -base64 16` |

To create new authelia OIDC secrets 

```
docker run --rm authelia/authelia:latest authelia crypto hash generate pbkdf2 --password "XXXXXX"
```


# REAL HARDENING 

***https://github.com/duggytuxy/syswarden***
***https://blog.${LDAP_USER1_FIRSTNAME}-robert.info/docs/securiser/reseaux/syswarden/***

# TIPS 

Image distroless terminal

```bash
kubectl debug -it jellysweep-5d748dd864-cbr6t --image=busybox --target=jellysweep -n media
cd /proc/1/root
```

Copy from local to pods

```
tar cf - musics | kubectl exec -i servarr-jellyfin-6667f7bd8-qql5h -- tar xf - -C /media/music 

kubectl cp ./musics servarr-jellyfin-6667f7bd8-qql5h:/media/music 
```

Remove all not running pods

```
kubectl delete pods -A --field-selector=status.phase!=Running
```

Clean unused image on k0s podman 

```
podman exec -it XX sh

k0s ctr images ls
k0s ctr images prune --all
```

Clean juicefs cache

```
podman exec -it XX sh

du -hs /var/jfsCache
rm -rf /var/jfsCache/df357eae-cbc8-41b0-81c1-bab489844b89/raw/chunks/*
```

# SED

```
# replace mac os cli
LC_ALL=C find clusters -type f -exec sed -i '' 's|test|${LDAP_USER1_LASTNAME}|g' {} + 
```