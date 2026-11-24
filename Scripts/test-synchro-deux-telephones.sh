#!/usr/bin/env bash
# Simule deux téléphones (Théo et Lilou) sur le vrai serveur Supabase du foyer :
# comptes, foyer, invitation, ajout d'un côté, lecture de l'autre, élément privé invisible.
# Nécessite dans Supabase : Authentication > Sign In / Providers > Email > « Confirm email » désactivé.
set -euo pipefail
: "${SUPABASE_URL:?secret manquant}" ; : "${SUPABASE_PUBLISHABLE_KEY:?secret manquant}"
U="$SUPABASE_URL"; K="$SUPABASE_PUBLISHABLE_KEY"; RUN="${GITHUB_RUN_ID:-$(date +%s)}"
# Diagnostic sans révéler les valeurs : forme de l'adresse et de la clé.
python3 - <<'PY'
import os, urllib.parse, re
u=os.environ["SUPABASE_URL"]; k=os.environ["SUPABASE_PUBLISHABLE_KEY"]
p=urllib.parse.urlparse(u.strip())
host=re.sub(r"^[a-z0-9]{8,}", "<ref>", p.hostname or "")
print("Adresse :", "schéma="+p.scheme, "hôte="+host, "chemin="+repr(p.path), "espaces/retours="+str(u!=u.strip()), "longueur="+str(len(u)))
print("Clé :", "début="+k[:14]+"…", "longueur="+str(len(k)), "espaces/retours="+str(k!=k.strip()))
PY
U="$(echo -n "$U" | tr -d '[:space:]')"; U="${U%/}"; K="$(echo -n "$K" | tr -d '[:space:]')"
PW="DuoTest-$(openssl rand -hex 8)"
ok(){ echo "OK   $*"; }; ko(){ echo "ÉCHEC $*"; exit 1; }
call(){ # méthode chemin jeton corps
  curl -sS -X "$1" "$U$2" -H "apikey: $K" -H "Content-Type: application/json" ${3:+-H "Authorization: Bearer $3"} ${4:+-d "$4"}; }
signup(){ call POST /auth/v1/signup "" "{\"email\":\"$1\",\"password\":\"$PW\"}"; }
token_of(){ jq -r '.access_token // empty'; }

A_MAIL="aurora.web28+duo-ci-a-$RUN@gmail.com"; B_MAIL="aurora.web28+duo-ci-b-$RUN@gmail.com"
RA=$(signup "$A_MAIL"); TA=$(echo "$RA" | token_of)
if [ -z "$TA" ]; then
  echo "$RA" | jq -c '{msg: (.msg // .error_description // .message // "inscription sans session")}' || true
  ko "Inscription sans connexion immédiate : désactiver « Confirm email » dans Supabase (Authentication > Sign In / Providers > Email)."
fi
A_ID=$(echo "$RA" | jq -r '.user.id'); ok "Téléphone A : compte créé"
RB=$(signup "$B_MAIL"); TB=$(echo "$RB" | token_of); B_ID=$(echo "$RB" | jq -r '.user.id'); [ -n "$TB" ] || ko "compte B"; ok "Téléphone B : compte créé"

HOME_ID=$(call POST /rest/v1/rpc/create_household "$TA" '{}' | jq -r '.'); [[ "$HOME_ID" =~ ^[0-9a-f-]{36}$ ]] || ko "création du foyer : $HOME_ID"; ok "A crée le foyer"
INV=$(call POST /rest/v1/rpc/invite_partner "$TA" '{}' | jq -r '.'); [ ${#INV} -eq 72 ] || ko "invitation : $INV"; ok "A invite B"
JOIN=$(call POST /rest/v1/rpc/join_household "$TB" "{\"p_token\":\"$INV\"}" | jq -r '.'); [ "$JOIN" = "$HOME_ID" ] || ko "B rejoint : $JOIN"; ok "B rejoint le même foyer"

uuid(){ python3 -c 'import uuid;print(uuid.uuid4())'; }
T1=$(uuid); T2=$(uuid); T3=$(uuid)
# Même format que l'app (JSONEncoder Swift : dates en secondes depuis 2001).
TASK="{\"id\":\"$T1\",\"household_id\":\"$HOME_ID\",\"owner_id\":null,\"revision\":0,\"deleted\":false,\"payload\":{\"task\":{\"_0\":{\"title\":\"Aspirateur salon (test DUO)\",\"assignee\":\"Ensemble\",\"repeatDays\":0}}}}"
PRIV="{\"id\":\"$T2\",\"household_id\":\"$HOME_ID\",\"owner_id\":\"$A_ID\",\"revision\":0,\"deleted\":false,\"payload\":{\"task\":{\"_0\":{\"title\":\"Privé de A (test DUO)\",\"assignee\":\"$A_ID\",\"repeatDays\":0}}}}"
R=$(call POST /rest/v1/rpc/apply_records "$TA" "{\"p_rows\":[$TASK,$PRIV]}"); [ "$(echo "$R" | jq 'length')" = "2" ] || ko "A envoie : $R"; ok "A ajoute une tâche commune et une tâche privée"

SEEN=$(call POST /rest/v1/rpc/read_records "$TB" '{}')
echo "$SEEN" | jq -e --arg id "$T1" 'map(select(.id==$id)) | length==1' >/dev/null || ko "B ne voit pas la tâche commune"; ok "B voit la tâche commune de A"
echo "$SEEN" | jq -e --arg id "$T2" 'map(select(.id==$id)) | length==0' >/dev/null || ko "B voit la tâche privée de A"; ok "B ne voit pas la tâche privée de A"

BUD="{\"id\":\"$T3\",\"household_id\":\"$HOME_ID\",\"owner_id\":null,\"revision\":0,\"deleted\":false,\"payload\":{\"budget\":{\"_0\":{\"id\":\"$T3\",\"date\":786000000,\"kind\":\"Dépense\",\"cents\":2350,\"title\":\"Courses (test DUO)\",\"person\":\"Lilou\",\"shared\":true}}}}"
R=$(call POST /rest/v1/rpc/apply_records "$TB" "{\"p_rows\":[$BUD]}")
if [ "$(echo "$R" | jq 'type=="array" and length==1')" = "true" ]; then
  call POST /rest/v1/rpc/read_records "$TA" '{}' | jq -e --arg id "$T3" 'map(select(.id==$id)) | length==1' >/dev/null || ko "A ne voit pas la dépense de B"
  ok "B ajoute une dépense commune, A la voit"
else
  echo "Réponse : $R"; ko "Budget refusé par le serveur : coller Backend/005_budget_partage.sql dans Supabase"
fi

# Modification puis suppression : A coche, B voit la mise à jour, puis nettoyage.
DONE=$(echo "$TASK" | jq -c '.revision=1 | .payload.task._0.completed=786000100')
call POST /rest/v1/rpc/apply_records "$TA" "{\"p_rows\":[$DONE]}" >/dev/null
call POST /rest/v1/rpc/read_records "$TB" '{}' | jq -e --arg id "$T1" 'map(select(.id==$id))[0].payload.task._0.completed != null' >/dev/null || ko "B ne voit pas la tâche cochée"; ok "A coche la tâche, B la voit cochée"
DEL1=$(echo "$DONE" | jq -c '.revision=2 | .deleted=true'); DEL2=$(echo "$PRIV" | jq -c '.revision=1 | .deleted=true')
call POST /rest/v1/rpc/apply_records "$TA" "{\"p_rows\":[$DEL1,$DEL2]}" >/dev/null
DEL3=$(echo "$BUD" | jq -c '.revision=1 | .deleted=true'); call POST /rest/v1/rpc/apply_records "$TB" "{\"p_rows\":[$DEL3]}" >/dev/null
call POST /rest/v1/rpc/read_records "$TB" '{}' | jq -e --arg id "$T1" 'map(select(.id==$id))[0].deleted == true' >/dev/null || ko "suppression non propagée"; ok "Suppression propagée à l'autre téléphone"
echo "SYNCHRO DEUX TÉLÉPHONES : TOUT EST OK"
