#!/bin/bash
###
# Run Puppet Apply
# This is a wrapper script around running masterless puppet.
###
[[ "$EUID" != "0" ]] && echo -e "\nError:\n\t**Run this script as root or sudo.\n" && exit 1
basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function log  {
    echo -e "[$(date "+%Y-%m-%dT%H:%M:%SZ%z")] $1"
}

function usagePrompt {
    log "
    run_puppet_apply.sh [options]

    -l | --librarian      Run Puppet Librarian to update modules
    -f | --facter         Run Puppet and use custom facter overrides
    -n | --noop           Run Puppet in No Operation (noop) mode

    "
}

###
# Find Puppet
# Searches for the puppet executable location in the current
# path and some common installation paths.
function findPuppet {
    # Check the path.  This is not always same as user, when using sudo
    puppetExec="$(which puppet)"
    if [[ "$puppetExec" == "" ]]; then
        # Check common locations of puppet install
        [[ -e "/opt/ruby/bin/puppet" ]] && puppetExec="/opt/ruby/bin/puppet"
        [[ -e "/usr/bin/puppet" ]] && puppetExec="/usr/bin/puppet"
    fi
}

###
# Package Install
# Installs a package name to install using either apt-get or yum
# @param packageName
function packageInstall {
    packageName=$1
    [[ "$packageName" == "" ]] && log "Missing packageInstall argument" && exit 1
    log "Attempting to install $packageName..."
    $(which apt-get > /dev/null 2>&1)
    foundApt=$?
    $(which yum > /dev/null 2>&1)
    foundYum=$?
    if [ "${foundYum}" -eq '0' ]; then
        log "Installing $packageName using yum..."
        yum install $packageName -y -q
    elif [ "${foundApt}" -eq '0' ]; then
        log "Installing $packageName using apt-get..."
        apt-get -q -y update
        apt-get -q -y install $packageName
    else
        log "No package installer available. You may need to install $packageName manually or modify this script."
        exit 1
    fi
}

###
# Upgrade Puppet
# If the default repository does not include puppet
# version >= 3.x then this will use the puppetlabs repo.
function upgradePuppet {
    log "Upgrading puppet from version $(puppet --version) to latest from puppetlabs..."
    $(which rpm > /dev/null 2>&1)
    foundRPM=$?
    $(which dpkg > /dev/null 2>&1)
    foundDPKG=$?
    if [ "${foundDPKG}" -eq '0' ]; then
        log "Upgrading puppet using DPKG..."
        wget http://apt.puppetlabs.com/puppetlabs-release-precise.deb -O /tmp/puppetlabs-release-precise.deb
        dpkg -i /tmp/puppetlabs-release-precise.deb
        sudo apt-get update
    elif [ "${foundRPM}" -eq '0' ]; then
        log "Upgrading puppet using RPM..."
        rpm -ivh http://yum.puppetlabs.com/el/6/products/i386/puppetlabs-release-6-7.noarch.rpm
    else
        log "No package system detected."
        exit 1
    fi
    packageInstall puppet
}

###
# Update Library
# Runs the puppet librarian to fetch/update non-project modules
#
function updateLibrary {
    log "Ensuring puppet librarian is run..."
    cd $basedir
    [[ "$(which git)" == "" ]] && packageInstall git
    if [[ -f $basedir/update_library.pre.sh ]]; then
        log "Running Pre Hook..."
        # Create project-specific dependencies in this pre hook file.  For example, if using a private
        # git repository as a puppet module source:  https://gist.github.com/tylerwalts/7127099
        source $basedir/update_library.pre.sh
    fi
    # Ensure the puppet librarian gem is installed.
    if [[ "$(gem search -i librarian-puppet)" == "false" ]]; then
      gem install librarian-puppet --no-ri --no-rdoc
      return=$?
      # If the existing/default gem source is bad/old, then use rubygems.
      # TODO: refactor this to gem search first, and be >= 0.9.10
      libVersion="$(gem search librarian-puppet | grep '0.9.10')"
      if [[ "$return" != "0" || "$libVersion" == "" ]]; then
        gem install bundler
        echo -e "source 'https://rubygems.org'\ngem 'librarian-puppet'" > Gemfile
        bundle install
      fi
    fi
    # Install or update the puppet module library
    if [ -f $basedir/.librarian ]; then
        log "Installing librarian..."
        command="librarian-puppet update --path ./lib"
    else
        log "Updating puppet lib with librarian"
        command="librarian-puppet install --path ./lib"
    fi
    log "Running librarian command: $command"
    $command
}

###
# Configure Hiera
# Checks puppet version and sets up hiera configuration accordingly
function configHiera {
    [[ "$puppetExec" == "" ]] && findPuppet
    puppetVersion="$($puppetExec --version)"
    [[ $puppetVersion == 2* ]] && cp ${basedir}/manifests/hiera.yaml /etc/puppet/
    [[ $puppetVersion == 3* ]] && puppetOpts="--hiera_config ${basedir}/manifests/hiera.yaml"

    # Hiera needs to know where to find the config data, via facter
    export FACTER_hiera_config="${basedir}/manifests/config"
}

# Ensure puppet & dependencies are present
findPuppet
[[ "$puppetExec" == "" ]] && packageInstall puppet
[[ "$(puppet --version)" == 2* ]] && upgradePuppet
configHiera

# Handle Args
while [ "$1" != "" ]; do
    case $1 in
        -l | --librarian )
            shift
            updateLibrary
            ;;
        -f | --facter_override )
            shift
            facterOptions="$1"
            log "Overriding Facter with: $facterOptions"
            export $facterOptions
            shift
            ;;
        -n | --noop )
            shift
            noopArg=" --noop "
            log "Using noop (no operation) run mode - no changes will be realized"
            shift
            ;;
        *) usagePrompt
            shift
            exit
            ;;
    esac
done

# Run Puppet Apply
cd ${basedir}/manifests
command="$puppetExec apply $puppetOpts $noopArg --modulepath ${basedir}/modules/:${basedir}/lib/ ${basedir}/manifests/site.pp"
log "\nRunning Masterless Puppet using command: \n\t$command\n"
$command

