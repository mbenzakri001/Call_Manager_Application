#!/bin/sh
# Télécharge les annonces vocales françaises d'Asterisk (messagerie vocale :
# "laissez un message après le bip", menus de consultation…).
# L'image Docker n'en contient aucune. À lancer une fois, depuis ce dossier :
#   sh get-sounds.sh
set -e
URL=https://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-fr-ulaw-current.tar.gz
mkdir -p sounds/fr
curl -fsSL "$URL" | tar -xz -C sounds/fr
echo "Annonces installées dans sounds/fr ($(ls sounds/fr | wc -l) fichiers)"
