#!/bin/bash

conteneur='base-puppet'
locale='fr_FR.UTF-8'
cheminManifestsHote="${HOME}/Code/ci-wazuh-puppet/Manifests"
cheminManifestsInvite='root/Manifests/Wazuh'
cheminModuleHote="${HOME}/Code/wazuh-puppet"
cheminModuleInvite='etc/puppetlabs/code/environments/production/modules/wazuh'

# Préparation du conteneur
lxc-stop -n "${conteneur}"
lxc-destroy -n "$conteneur"
systemd-run --user --scope -p "Delegate=yes" -- lxc-create -n "${conteneur}" -t /usr/share/lxc/templates/lxc-download -- --dist debian --release buster --arch amd64
systemd-run --user --scope -p "Delegate=yes" -- lxc-start -n "${conteneur}"
executerDansConteneur="lxc-attach -n ${conteneur} -- "
sleep 2

# Configuration de la locale FR
$executerDansConteneur sed -E -i "s/# (${locale})/\1/" /etc/locale.gen
$executerDansConteneur locale-gen

# Installation paquets nécessaires
$executerDansConteneur apt -y update
$executerDansConteneur apt -y upgrade
$executerDansConteneur apt -y install wget

# Installation Puppet
cheminPaquetPuppet='/root/puppet6-release-buster.deb'
$executerDansConteneur wget -O "${cheminPaquetPuppet}" 'https://apt.puppet.com/puppet6-release-buster.deb'
$executerDansConteneur dpkg -i "${cheminPaquetPuppet}"
$executerDansConteneur rm "${cheminPaquetPuppet}"
$executerDansConteneur apt -y update
$executerDansConteneur apt install -y puppet-agent

# Configuration des points de montage
$executerDansConteneur mkdir -p "${cheminManifestsInvite}"
echo "lxc.mount.entry = ${cheminManifestsHote} ${cheminManifestsInvite} none bind 0 0" >> "${HOME}/.local/share/lxc/${conteneur}/config"
$executerDansConteneur mkdir -p "${cheminModuleInvite}"
echo "lxc.mount.entry = ${cheminModuleHote} ${cheminModuleInvite} none bind 0 0" >> "${HOME}/.local/share/lxc/${conteneur}/config"

# Dépendances puppet
$executerDansConteneur /opt/puppetlabs/bin/puppet module install puppetlabs-stdlib
$executerDansConteneur /opt/puppetlabs/bin/puppet module install puppet-archive
$executerDansConteneur /opt/puppetlabs/bin/puppet module install puppet-nodejs
$executerDansConteneur /opt/puppetlabs/bin/puppet module install puppet-selinux
$executerDansConteneur /opt/puppetlabs/bin/puppet module install puppetlabs-apt
$executerDansConteneur /opt/puppetlabs/bin/puppet module install puppetlabs-concat
$executerDansConteneur /opt/puppetlabs/bin/puppet module install puppetlabs-firewall
$executerDansConteneur /opt/puppetlabs/bin/puppet module install puppetlabs-powershell
$executerDansConteneur apt install -y lsb-release
$executerDansConteneur apt install -y curl

# Supporter nesting
echo 'lxc.include = /usr/share/lxc/config/nesting.conf' >> "${HOME}/.local/share/lxc/${conteneur}/config"

# Arrêt du conteneur avant sortie
lxc-stop -n "${conteneur}"
