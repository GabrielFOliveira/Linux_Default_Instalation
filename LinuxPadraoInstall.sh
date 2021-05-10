#!/bin/bash/env bash
#

#(0) Linux Default Installation
#------------------------------------------------------------------------------------------------
#(0) Author: Gabriel França
#(0) Company: AVCorp Comercio e ServiÃ§os em Tecnologia LTDA
#(0) Creation Date 23/05/2018
#(0) Last update: 18/07/2018
#(0) Version:1.0
#-----------------------------------------------------------------------------------
#(0) Perform a default installation on AVCorp's Linux Machines.
#(0)
#(0)


#(1) Here te global variables are set
OLDIFS=$IFS
#(1) Setting "SYSTEM" to get the OS installed
SYSTEM=$(cat /etc/os-release | head -1)
#(1) Setting DIR to be the actual directory
DIR=$(pwd)

##(2) Here is tested if the script is running with help parameter, show it's information
_testhelp(){
  if [[ "${1}" == "help" ]]; then
    echo -e "This script was developed to do the default installation of Linux machines.  \n ****To run this script is required to be root****"
    exit 1
  fi
}

##(3) Make sure that the script is running on root
_testroot(){
  local i=`id -u`
  if [[ ${i} != 0 ]]; then
    echo "Not Root"
    exit 1
  fi
}


#(4) Set installer based in the OSs, between yum and apt
_testinstaller(){
  IFS=$'\n'

  local os=`cat ./OSs/yumOS.txt`

  for i in ${os};  do
    if [[ "${SYSTEM}" == "NAME=${i}" ]]; then
      INSTALLER=yum
      SYSTEMOS="${i%\"}"
      SYSTEMOS="${SYSTEMOS#\"}"
      SYSTEMOS="${SYSTEMOS%\ *}"
      SYSTEMOS="${SYSTEMOS%\"}"
    fi
  done

  local os=`cat OSs/aptOS.txt`
  for i in ${os}; do
    if [[ "${SYSTEM}" == "NAME=${i}" ]]; then
      INSTALLER=apt
      SYSTEMOS=${i}
      SYSTEMOS="${SYSTEMOS#\"}"
      SYSTEMOS="${SYSTEMOS%\ *}"
      SYSTEMOS="${SYSTEMOS%\"}"
      fi
  done

  if [[ -z "${INSTALLER}" ]]; then
    echo 'No installer found'
    exit 1
  fi
}

#(5) Setting up secure settings
_security_settings(){
  if [[ "${INSTALLER}" == "yum" ]]; then
    sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config
    setenforce 0
    systemctl stop firewalld
    systemctl disable firewalld
  fi
  iptables -F
}


#(6) Create the 

_createusers(){

  local dusers=`cat dusers`

  for i in ${dusers}; do
  _createusers${INSTALLER} ${i}
  done
}

_createusersapt(){
    echo -e "${1}@123\n${1}@123" | adduser ${1}
    usermod -aG sudo ${1}
}

_createusersyum(){
    adduser ${1}
    echo "${1}@123" |  passwd --stdin ${1}
    grep ${1} /etc/sudoers &>> /dev/null
    if [[ "${?}" = "1" ]]; then
      echo "${1} ALL=(ALL:ALL) ALL" >> /etc/sudoers
    fi
}

#(7) Install the basic apps that will be used on the machines
_installapps(){

  #(7) Install epel release
  ${INSTALLER} update -y &&  ${INSTALLER} upgrade -y


  ${INSTALLER} install make -y
  #(7) Add missing repositories
  _repos${SYSTEMOS}
  _repos${INSTALLER}


  #(7) Install listed apps of apps_padrao
  local apps="$(cat apps_padrao)"
  for i in ${apps}; do
    ${INSTALLER} install -y ${i}
    _testerror INSTALL ${i}
  done

  #(7) Configuring vim
  git clone https://github.com/willyrgf/vimfiles
  local users=`cat dusers`
  chmod 777 vimfiles
  cd vimfiles
  for i in ${users}; do
    su -c "echo -e "\\n" | bash install_vimrc.sh" -s /bin/sh ${i}
    if [[ "${?}" = "1" ]]; then
     su -c "echo -e "\\n" | vim +:BundleClean +q +q && vim +:BundleInstall +q +q" /bin/sh -s ${i}
      _testerror INSTALL_VIM
    fi
  done
  cd $DIR
  git clone https://github.com/willyrgf/vimfiles
  cd vimfiles
  echo -e "\n" | bash install_vimrc.sh
  if [[ "${?}" = "1" ]]; then
    echo -e "\n" | vim +:BundleClean +q +q && vim +:BundleInstall +q +q
    _testerror INSTALL_VIM
  fi
  cd ..

  #(7) Install sngrep
  command -v sngrep &>> /dev/null
  if [[ "${?}" = "1" ]]; then
    _sngrep${INSTALLER}
  fi
}

_reposCentOS(){
  ${INSTALLER} install -y epel-release
    _testerror INSTALL EPEL-RELEASE
  rpm -ivh https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
  rpm -ivh https://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-agent-3.4.0-1.el7.x86_64.rpm
  rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg
  yum-config-manager --add-repo https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo
}

_reposFedora(){
  rpm -ivh https://dev.mysql.com/get/mysql80-community-release-fc30-1.noarch.rpm
  sudo rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg
  sudo dnf config-manager --add-repo https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo
}

_reposapt(){
  ${INSTALLER} install -y  mysql-client
  _testerror INSTALL MYSQL-CLIENT
  wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
  apt install apt-transport-https
  echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
}

_reposyum(){
  ${INSTALLER} install -y yum-utils
  rpm -Uvh http://mirror.ghettoforge.org/distributions/gf/gf-release-latest.gf.el7.noarch.rpm
  rpm --import http://mirror.ghettoforge.org/distributions/gf/RPM-GPG-KEY-gf.el7
  yum -y remove vim-minimal vim-common vim-enhanced
  yum -y --enablerepo=gf-plus install vim-enhanced
}

_sngrepyum(){
  cat sngrep.repo >> /etc/yum.repos.d/sngrep.repo
  rpm --import http://packages.irontec.com/public.key
  yum install sngrep -y
  yum update -y
  _testerror INSTALL_SNGREP
}

_sngrepapt(){
  ${INSTALLER} install -y autoconf automake gcc make \ libncurses5-dev libpcap-dev libssl-dev libpcre3-dev
  ${INSTALLER} install -y sngrep
  _testerror INSTALL_SNGREP
}

#(8) Set some basic configurations on the system
_basicconf(){
  ### Increase history size
  sed 's/HISTSIZE=*/HISTSIZE=50000/g' /etc/profile &>> /dev/null
  export HISTFILESIZE=50000

   #(8) Set timezone, time and date
  timedatectl set-timezone America/Sao_Paulo
  #(8) Make journalctl persistent
  sed -i.sample 's/#Storage=auto/Storage=persistent/g' /etc/systemd/journald.conf &>> /dev/null

  #(8) Config SSH
  chmod 766 /etc/ssh/sshd_config
  cat padraossh > /etc/ssh/sshd_config
  chmod 744 /etc/ssh/sshd_config

}

#(9) Test if the last command had any errors
_testerror(){
  if [[ "${?}" != "0" ]]; then
    echo "ERROR ${1} ${2}"
    exit 1
  fi
}

#(10) The main function
_main(){
  _testhelp ${1}
  _testroot
  _testinstaller
  _security_settings
  _createusers
  _installapps
  _basicconf
}

_main ${1}

