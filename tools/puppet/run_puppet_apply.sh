#!/bin/bash
###
# Run Puppet Apply
# This is a wrapper script around running masterless puppet.
###
[[ "$EUID" != "0" ]] && echo -e "\nError:\n\t**Run this script as root or sudo.\n" && exit 1
basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
projectModules="${basedir}/modules"

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
        # Install puppet from the puppetlabs repo
        packageInstall puppet
    elif [ "${foundRPM}" -eq '0' ]; then
        log "Adding the Puppet Labs repo..."
        rpm -ivh http://yum.puppetlabs.com/el/6/products/$arch/puppetlabs-release-6-7.noarch.rpm
        log "Upgrading puppet using RPM..."
        yum -y install libselinux-utils libselinux-ruby ruby-devel rubygems puppet git dmidecode virt-what pciutils gcc
        yum -y install  --disablerepo=amzn-* --enablerepo=puppetlabs*,epel*  facter hiera rubygems puppet
        log "Puppet toolset installation complete."
    else
        log "No package system detected."
        exit 1
    fi
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
      gem install librarian-puppet -v 0.9.11 --no-ri --no-rdoc
      return=$?
      # If the existing/default gem source is bad/old, then use rubygems and bundler
      libVersion="$(gem search librarian-puppet | grep '0.9.11')"
      if [[ "$return" != "0" || "$libVersion" == "" ]]; then
        gem install bundler
        echo -e "source 'https://rubygems.org'\ngem 'librarian-puppet', '0.9.11'" > Gemfile
        bundle install
      fi
    fi
    # Install or update the puppet module library
    librarianExec="$(which librarian-puppet)"
    if [ -f $basedir/.librarian ]; then
        log "Updating librarian..."
        command="$librarianExec update --path ./lib"
    else
        log "Installing puppet lib with librarian"
        command="$librarianExec install --path ./lib"
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


function install_module_bundle {
    modulePath=$1
    [[ -f $modulePath/.gemfile ]] && gemfileOpt="--gemfile .gemfile"
    cd $modulePath
    bundle install $gemFileOpt --path .vendor
    cd -
}

function lint_module {
    modulePath=$1
    cd $modulePath
    log "Lint-ing module at: $(pwd)"
    bundle check || install_module_bundle $modulePath
    bundle exec rake lint
    cd -
}

function spec_module {
    modulePath=$1
    cd $modulePath
    log "Rspec-ing module at: $(pwd)"
    bundle check || install_module_bundle $modulePath
    bundle exec rake spec
    cd -
}

function test_module {
    modulePath=$1
    testType=$2
    if [[ ! -f "$modulePath/Rakefile" ]]; then
        log "Skipping module without tests: $modulePath (missing Rakefile)"
    elif [[ ! -f "$modulePath/Gemfile" && ! -f "$modulePath/.gemfile" ]]; then
        log "Skipping module without tests: $modulePath (missing Gemfile or .gemfile )"
    else
        if [[ "$testType" != "" ]]; then
            case $testType in
                lint) lint_module $modulePath ;;
                spec) lint_module $modulePath ;;
                *) log "Invalid test type" && exit 1 ;;
            esac
        else
            #Default: Do both
            lint_module $modulePath
            spec_module $modulePath
        fi
    fi
}

function test_all_modules {
    testType=$1
    moduleList="$(ls $projectModules)"
    echo "moduleList=$moduleList"
    for module in $(ls $projectModules); do
        log "Testing module: $module"
        test_module $projectModules/$module $testType
    done
}

function testProject {
    module=$1
    testType=$2
    if [[ "$module" == "" || "$module" == "all" ]]; then
        test_all_modules $testType
    else
        test_module $projectModules/$module $testType
    fi
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
        -t | --test )
            shift
            testProject $1 $2
            exit
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

