#!/bin/bash

# === CONFIG ===
LDAP_URI="ldap://localhost:3890"
LDAP_BASE_DN="dc=example,dc=com"
LDAP_BIND_DN="cn=admin,ou=people,$LDAP_BASE_DN"
LDAP_GROUP_BASE="ou=groups,$LDAP_BASE_DN"
LDAP_PEOPLE_BASE="ou=people,$LDAP_BASE_DN"

SMTP_SERVER="smtp://localhost:1025"
SMTP_FROM="noreply@homelab.local"
SMTP_USER="test:test"

# === SERVICES: groupe|nom|url|description ===
SERVICES="
jelly_admin|Prowlarr (Admin)|https://prowlarr.${CLUSTER_DOMAIN}|Gestion des indexeurs
jelly_admin|⚠️ Radarr (Admin)|https://radarr.${CLUSTER_DOMAIN}|Gestion des films
jelly_admin|⚠️ Sonarr (Admin)|https://sonarr.${CLUSTER_DOMAIN}|Gestion des séries
jelly_admin|⚠️ Qbittorrent (Admin)|https://qbittorrent.${CLUSTER_DOMAIN}|Téléchargement torrent
jelly_admin|Bazarr (Admin)|https://bazarr.${CLUSTER_DOMAIN}|Gestion des sous-titres
jelly_admin|Cleanuparr (Admin)|https://cleanuparr.${CLUSTER_DOMAIN}|Nettoyage automatique
jelly_admin|JuiceFS |https://juicefs.${CLUSTER_DOMAIN}|Stockage S3
jelly_admin|Mail|https://mail.${CLUSTER_DOMAIN}|Mail
jelly_admin|⚠️ SFTP|https://sftp.${CLUSTER_DOMAIN}|Transfert de Fichier 
analytics|Umami (Admin)|https://umami.${CLUSTER_DOMAIN}|Google analytics
gitea_users|Gitea|https://git.${CLUSTER_DOMAIN}|Hébergement de code
gitea_admin|Gitea (Admin)|https://git.${CLUSTER_DOMAIN}/admin|Administration Gitea
vpn_user|Wireguard |https://vpn.${CLUSTER_DOMAIN}/admin|VPN
vpn_admin|Wireguard (Admin)|https://vpn.${CLUSTER_DOMAIN}/admin|Administration VPN
"

SERVICES_BASE="
|🔐 Jellyfin|https://jelly.${CLUSTER_DOMAIN}|Streaming multimédia
|Seerr|https://seerr.${CLUSTER_DOMAIN}|Demandes de médias
|🔐 Authelia|https://auth.${CLUSTER_DOMAIN}|Gestion de l'authentification
|🔐 LDAP|https://ldap.${CLUSTER_DOMAIN}|Gestion des utilisateurs
|Vaultwarden|https://pwd.${CLUSTER_DOMAIN}|Gestionnaire de mots de passe
|Homepage|https://homepage.${CLUSTER_DOMAIN}|Site vitrine
|Traefik|https://traefik.${CLUSTER_DOMAIN}|Proxy
"

# === LDAP ===
read -s -p "🔐 Mot de passe admin LDAP: " LDAP_BIND_PW
echo

if ! ldapsearch -x -H "$LDAP_URI" -D "$LDAP_BIND_DN" -w "$LDAP_BIND_PW" -b "$LDAP_BASE_DN" -s base "(objectclass=*)" dn >/dev/null 2>&1; then
  echo "❌ Connexion LDAP échouée"
  exit 1
fi
echo "✅ Connexion LDAP OK"
echo

get_uid_by_email() {
  ldapsearch -x -H "$LDAP_URI" -D "$LDAP_BIND_DN" -w "$LDAP_BIND_PW" \
    -b "$LDAP_PEOPLE_BASE" "(mail=$1)" uid 2>/dev/null \
    | grep "^uid:" | head -1 | sed 's/^uid: //'
}

get_groups_by_uid() {
  ldapsearch -x -H "$LDAP_URI" -D "$LDAP_BIND_DN" -w "$LDAP_BIND_PW" \
    -b "$LDAP_GROUP_BASE" "(member=uid=$1,$LDAP_PEOPLE_BASE)" cn 2>/dev/null \
    | grep "^cn:" | sed 's/^cn: //'
}

# === BUILD SERVICE ROWS ===
build_service_rows() {
  local user_groups="$1"
  local rows=""

  # Services de base (toujours affichés)
  while IFS='|' read -r grp nom url desc; do
    [[ -z "$nom" ]] && continue
    rows+="<tr>"
    rows+="<td style='padding:8px;border:1px solid #ddd;'><a href='$url'>$nom</a></td>"
    rows+="<td style='padding:8px;border:1px solid #ddd;'>$desc</td>"
    rows+="</tr>"
  done <<< "$SERVICES_BASE"

  # Services selon les groupes (seulement si l'utilisateur a des groupes)
  if [ -n "$user_groups" ]; then
    while IFS='|' read -r grp nom url desc; do
      [[ -z "$grp" ]] && continue
      if echo "$user_groups" | grep -qw "$grp"; then
        rows+="<tr>"
        rows+="<td style='padding:8px;border:1px solid #ddd;'><a href='$url'>$nom</a></td>"
        rows+="<td style='padding:8px;border:1px solid #ddd;'>$desc</td>"
        rows+="</tr>"
      fi
    done <<< "$SERVICES"
  fi

  echo "$rows"
}

# === SEND MAIL ===
send_mail() {
  local email="$1"
  local uid="$2"
  local groups="$3"

  local rows
  rows=$(build_service_rows "$groups")

  cat <<EOF | curl -s "$SMTP_SERVER" \
    --mail-from "$SMTP_FROM" \
    --mail-rcpt "$email" \
    --user "$SMTP_USER" \
    -T -
From: New HomeLab <$SMTP_FROM>
To: $email
Subject: Bienvenue $uid !
MIME-Version: 1.0
Content-Type: text/html; charset=UTF-8

<html><body style="font-family:Arial,sans-serif;">
<p>Voici vos acces :</p>
<table style="border-collapse:collapse;width:100%;">
<tr>
  <th style="padding:8px;border:1px solid #ddd;background:#f4f4f4;">Service</th>
  <th style="padding:8px;border:1px solid #ddd;background:#f4f4f4;">Description</th>
</tr>
$rows
</table>
<br>
<p>Username : <strong>$uid</strong></p>
<p>Password : <strong>blrzoo92330</strong></p>
<br>
<p><i>Les applications avec 🔐 permettent de changer son mot de passe</i></p>
<br>
<p><i>Les applications avec ⚠️ permettent de supprimer des medias</i></p>
</body></html>
EOF
}

# === MAIN ===
sent=0
errors=0

for email in "$@"; do
  echo "🔍 Traitement de: $email"

  uid=$(get_uid_by_email "$email")
  if [ -z "$uid" ]; then
    echo "   ❌ Aucun utilisateur trouvé pour $email"
    errors=$((errors + 1))
    continue
  fi
  echo "   👤 Username: $uid"

  groups=$(get_groups_by_uid "$uid")
  if [ -z "$groups" ]; then
    echo "   ⚠️  Aucun groupe trouvé — envoi avec services de base uniquement"
  else
    echo "   📋 Groupes: $(echo "$groups" | tr '\n' ' ')"
  fi

  send_mail "$email" "$uid" "$groups"
  echo "   ✅ Mail envoyé à $email"
  sent=$((sent + 1))
done

echo "════════════════════════════"
echo "📊 Total: $sent mail(s) | $errors erreur(s)"
