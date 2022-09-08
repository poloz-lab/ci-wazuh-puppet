#!/bin/bash

# Codes d'erreur
# 1 : Argument inconnu
# 2 : Conteneur non créé
# 3 : Conteneur non démarré
# 4 : Keystore non supprimé sur le dashboard

# FONCTIONS

afficher_separateur()
{
	echo ""
	echo "#####################################################"
	echo "${1}"
	echo "#####################################################"
}

afficher_separateur_test()
{
	echo ""
	echo "-----------------------------------------------------"
	echo "${1}"
	echo "-----------------------------------------------------"
}

# Création d'un conteneur
creation_conteneur()
{
	# Destruction de l'ancien conteneur si existant
	lxc-ls | grep --word-regexp --only-matching "${1}" > /dev/null
	if [ "$?" -eq "0" ]
	then
		echo "Ancien conteneur ${1} trouvé" > ${sortie_flux}
		lxc-stop -n "${1}" > ${sortie_flux} 2>&1
		lxc-destroy -n "${1}" && echo "Ancien conteneur ${1} détruit" > ${sortie_flux}
	fi
	# Création du nouveau conteneur
	lxc-copy -n "${conteneur_base}" -N "${1}" && echo "Conteneur ${1} créé" > ${sortie_flux} || exit 2
	# Démarage du nouveau conteneur
	systemd-run --user --scope -p "Delegate=yes" -- lxc-start -n ${1}  && echo "Conteneur ${1} démarré" > ${sortie_flux} || exit 3
}

# Création du groupe de conteneurs défini dans la variable $conteneurs
creation_conteneurs()
{
	afficher_separateur_test "Création des conteneurs"
	for conteneur in "${conteneurs[@]}"
	do
		creation_conteneur "${conteneur}"
	done
}

# passage de puppet sur les conteneurs
passage_puppet()
{
	for conteneur in "${conteneurs[@]}"
	do
		readarray -d "-" -t tab <<< "${conteneur}"
		manifest="${tab[1]}${suffixe_manifests}.pp"
		afficher_separateur_test "Passage de Puppet sur ${conteneur}"
		lxc-attach -n "${conteneur}" -- puppet apply "/root/Manifests/Wazuh/${manifest}" > ${sortie_flux}
	done
}

# Procédure de test appliquée à chaque situation à tester
procedure_test()
{
	# Passage de Puppet
	passage_puppet

	# Vérification de l'idempotence
	afficher_separateur_test "Vérification de l'idempotence"
	ancien_sortie_flux="${sortie_flux}"
	sortie_flux="/dev/stdout"
	sortie=`passage_puppet`
	sortie_flux="${ancien_sortie_flux}"
	compteur_notice=`echo "${sortie}" | grep --count "Notice:"`
	echo -e "\n'Notice:' comptés : ${compteur_notice}" > ${sortie_flux}
	notice_attendu=`expr ${#conteneurs[@]} \* 2`
	echo "'Notice:' attendus : ${notice_attendu}" > ${sortie_flux}
	if [ "${compteur_notice}" -ne "${notice_attendu}" ]
	then
		echo "Pas d'idempotence" >&2
		echo "${sortie}" >&2
		exit 11
	else
		echo "Idempotence respectée"
	fi

	# En fonction du manifest, vérifier si le keystore du dashboard est supprimé
	if [ "${suffixe_manifests}" == "1" ]
	then
		afficher_separateur_test "Vérification de la suppression du keystore sur le dashboard"
		lxc-attach -n 'wazuh-monolithe-0' -- test -f '/usr/share/wazuh-dashboard/config/opensearch_dashboards.keystore'
		if [ "$?" -eq "0" ]
		then
			echo "Le keystore n'a pas été supprimé"
			exit 4
		fi
		echo "Le keystore a été supprimé"
	fi

	return 0
}

# DÉFINITION DES VARIABLES GLOBALES

# Mode silencieux
if [ "$1" == "quiet" ]
then
	sortie_flux="/dev/null"
else
	sortie_flux="/dev/stdout"
fi

# Définition des noms des conteneurs
conteneur_base="base-puppet"
conteneurs_monolithique=("wazuh-agent-1" "wazuh-monolithe-0")
conteneurs_distribuee=("wazuh-agent-1" "wazuh-master-1" "wazuh-indexer-1" "wazuh-dashboard-0")
conteneurs_cluster=("wazuh-agent-1" "wazuh-master-1" "wazuh-worker-1" "wazuh-worker-2" "wazuh-worker-3" "wazuh-indexer-1" "wazuh-indexer-2" "wazuh-indexer-3" "wazuh-dashboard-0")

# MAIN

# Situation 1, création depuis 0, architecture monolithique
afficher_separateur "Situation 1 : Création depuis 0, architecture monolithique"

conteneurs=("${conteneurs_monolithique[@]}")
creation_conteneurs

suffixe_manifests=""
procedure_test && echo -e "\nSituation réussie"

# Situation 2, sur architecture précédente, suppression de keystore sur dashboard
afficher_separateur "Situation 2 : Suppression du keystore sur le dashboard"

suffixe_manifests="1"
procedure_test && echo -e "\nSituation réussie"

# Arrêt des conteneurs
afficher_separateur "Arrêt des conteneurs"
for conteneur in "${conteneurs[@]}"
do
	lxc-stop -n "${conteneur}" && echo "Conteneur ${conteneur} arrêté" > ${sortie_flux}
done
echo "Conteneurs arrêtés"

exit 0
