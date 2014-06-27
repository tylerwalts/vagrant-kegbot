#!/usr/bin/env bash
###
# Run Puppet Apply
# This is a wrapper script around running masterless puppet.
###
export PATH=$PATH:/usr/local/bin/
basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
projectModules="${basedir}/lib"
OS_ARCH=$(uname -p)

log() {
    echo -e "[$(date "+%Y-%m-%dT%H:%M:%SZ%z")] $1"
}

usagePrompt() {
    log "
    run_puppet_apply.sh [options]

    -l | --librarian        Run Puppet Librarian to update modules
    -v | --lib_version ARG  Run Puppet Librarian with specified version
    -g | --gem_install      Install Puppet using gem
    -f | --facter           Run Puppet and use custom facter overrides
    -n | --noop             Run Puppet in No Operation (noop) mode

    "
}

foundInPath() {
    $(which $1 &>/dev/null)
    return $?
}

###
# Find Puppet
# Searches for the puppet executable location in the current
# path and some common installation paths.
findPuppet() {
    # Check the path.  This is not always same as user, when using sudo
    if foundInPath "puppet"; then
        puppetExec=$(which puppet)
    else
        # Check common locations of puppet install
        [[ -e "/opt/ruby/bin/puppet" ]] && puppetExec="/opt/ruby/bin/puppet"
        [[ -e "/usr/bin/puppet" ]] && puppetExec="/usr/bin/puppet"
    fi
    [[ -z "$puppetExec" ]] && return 1
    return 0
}

###
# Package Install
# Installs a package name to install using either apt-get or yum
# @param packageName
packageInstall() {
    packageName=$1
    [[ -z "$packageName" ]] && log "Missing packageInstall argument" && return 1
    [[ -n "$2" ]] && options="$2"
    log "Attempting to install $packageName..."
    if foundInPath yum; then
        log "Installing $packageName using yum..."
        yum -y -q install $options $packageName
    elif foundInPath apt-get; then
        log "Installing $packageName using apt-get..."
        apt-get -q -y update
        apt-get -q -y install $packageName
    else
        log "No package installer available. You may need to install $packageName manually or modify this script."
        exit 1
    fi
}

###
# Gem Install
# Installs a package using rubygem
# @param gemName
# @param gemVersion (optional)
gemInstall() {
    gemName=$1
    [[ -z "$gemName" ]] && log "Missing gemInstall argument" && return 1
    if [[ -n $2 ]]; then
        local versionOption="-v $2"
        local versionGemFile=", '$2'"
    fi
    log "Attempting to install gem $gemName..."
    cd $basedir
    ! foundInPath gem && packageInstall rubygems
    if foundInPath gem && [[ $(gem search -i $gemName $versionOption) == "false" ]]; then
      gem install $gemName $versionOption --no-ri --no-rdoc
      local rc=$?; if [[ $rc -ne 0 ]]; then
        [[ $(gem search -i bundler) == "false" ]] && gem install bundler
        [[ ! -e GemFile ]] && echo -e "source 'https://rubygems.org'" > Gemfile
        echo -e "gem '$gemName'$versionGemFile" >> Gemfile
        bundle install
      fi
    fi
    return $rc
}

###
# Puppet Install
# Installs a package using puppet resource
# @param packageName
puppetResourceInstall() {
    ensureArgs="ensure=installed"
    while [ -n "$1" ]; do
      case $1 in
        -p | --package ) shift
            resourceName="$1"
            ;;
        -g | --gem ) shift
            providerArgs="provider=gem"
            resourceName="$1"
            ;;
        -v | --version ) shift
            ensureArgs="ensure=$1"
            ;;
        *) log "Missing puppetResourceInstall argument"
            return 1
            ;;
      esac
      shift
    done
    log "Attempting to install $resourceName [$ensureArgs $providerArgs]..."
    findPuppet && $puppetExec resource package $resourceName $ensureArgs $providerArgs
    return $?
}

install_lsb() {
    local packageName=$1 && lsbExec=lsb_release
    if [[ -z "$packageName" ]]; then
        foundInPath dpkg && local packageName="lsb-release" && lsbExec=lsb-release
        foundInPath rpm && local packageName="redhat-lsb" && lsbExec=lsb_release
    fi
    [[ -n "$packageName" ]] && packageInstall "$packageName"
}

setupAptRepo() {
    local codename=$($lsbExec -ic)
    wget http://apt.puppetlabs.com/puppetlabs-release-${codename}.deb -O /tmp/puppetlabs-release-${codename}.deb
    local rc=$?
    [[ $rc -ne 0 ]] && log "failed to wget package from apt.puppetlabs.com [codename: $codename]" && return $rc
    dpkg -i /tmp/puppetlabs-release-${codename}.deb
    sudo apt-get update
}

setupYumRepo() {
    local yum_version="el-6"
    if [[ "$($lsbExec -ir)" == "Fedora" ]]; then
        local yum_version="fedora-$($lsbExec -ir)"
    fi
    rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-${yum_version}.noarch.rpm
}

setupPuppetRepo() {
    log "setting up puppetlabs repo..."
    if foundInPath dpkg; then
        log "Upgrading puppet using DPKG..."
        setupAptRepo
    elif foundInPath rpm; then
        log "setting puppetlabs repo using RPM..."
        setupYumRepo
    else
        log "No package system detected."
        exit 1
    fi
    log "Puppetlabs setup complete."
}

###
# Upgrade Puppet
# If the default repository does not include puppet
# version >= 3.x then this will use the puppetlabs repo.
upgradePuppet() {
    setupPuppetRepo
    log "Upgrading puppet from version $($puppetExec --version) to latest release from puppetlabs..."
    if foundInPath dpkg; then
        log "Upgrading puppet using DPKG..."
        packageInstall puppet
    elif foundInPath rpm; then
        log "Upgrading puppet using RPM..."
        yum -y install libselinux-utils libselinux-ruby ruby-devel rubygems puppet factor hiera dmidecode virt-what pciutils gcc systemd
        #yum -y install --disablerepo=amzn-* --enablerepo=puppetlabs*,epel*  facter hiera rubygems puppet
    else
        log "No package system detected."
        exit 1
    fi
    status="complete"
    ! foundInPath puppet && status="failed"
    log "Puppet toolset installation ${status}."
}

###
# Update Library
# Runs the puppet librarian to fetch/update non-project modules
updateLibrary() {
    log "Ensuring puppet librarian is run..."
    cd $basedir
    ! foundInPath git && packageInstall git
    if [[ -f $basedir/update_library.pre.sh ]]; then
        log "Running Pre Hook..."
        # Create project-specific dependencies in this pre hook file.  For example, if using a private
        # git repository as a puppet module source:  https://gist.github.com/tylerwalts/7127099
        source $basedir/update_library.pre.sh
    fi
    # Ensure the puppet librarian gem is installed.
    puppetResourceInstall --gem io-console
    puppetResourceInstall --gem librarian-puppet $LIBRARIAN_VERSION
    # Install or update the puppet module library
    if [ -f $basedir/.librarian ]; then
        log "Updating librarian..."
        libArgs="update"
    else
        log "Installing puppet lib with librarian"
        libArgs="install"
    fi
    log "Running librarian task: $libArgs"
    foundInPath librarian-puppet && librarian-puppet $libArgs
}

###
# Configure Hiera
# Checks puppet version and sets up hiera configuration accordingly
configHiera() {
    ! foundInPath hiera && (puppetResourceInstall --package hiera || puppetResourceInstall --gem hiera)

    findPuppet && puppetVersion="$($puppetExec --version)"
    [[ $puppetVersion == 2* ]] && cp ${basedir}/manifests/hiera.yaml /etc/puppet/
    [[ $puppetVersion == 3* ]] && puppetOpts="--hiera_config ${basedir}/manifests/hiera.yaml"

    # If deeper exists in file, install deep_merge (even if not used)
    hieraVersion=$(hiera --version)
    if grep -e 'deeper' ${basedir}/manifests/hiera.yaml && ! [[ $hieraVersion =~ ^[0-1]\.[0-1].* ]]; then
        log "Ensuring deep_merge gem is installed..."
        puppetResourceInstall --gem deep_merge
    fi

    # Hiera needs to know where to find the config data, via facter
    export FACTER_hiera_config="${basedir}/manifests/config"
}


install_module_bundle() {
    modulePath=$1
    [[ -f $modulePath/.gemfile ]] && gemfileOpt="--gemfile .gemfile"
    cd $modulePath
    bundle install $gemFileOpt --path .vendor
    cd -
}

lint_module() {
    modulePath=$1
    cd $modulePath
    log "Lint-ing module at: $(pwd)"
    bundle check || install_module_bundle $modulePath
    bundle exec rake lint
    cd -
}

spec_module() {
    modulePath=$1
    cd $modulePath
    log "Rspec-ing module at: $(pwd)"
    bundle check || install_module_bundle $modulePath
    bundle exec rake spec
    cd -
}

test_module() {
    modulePath=$1
    testType=$2
    if [[ ! -f $modulePath/Rakefile ]]; then
        log "Skipping module without tests: $modulePath (missing Rakefile)"
    elif [[ ! -f $modulePath/Gemfile && ! -f $modulePath/.gemfile ]]; then
        log "Skipping module without tests: $modulePath (missing Gemfile or .gemfile )"
    else
        if [[ -n "$testType" ]]; then
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

test_all_modules() {
    testType=$1
    moduleList="$(ls $projectModules)"
    echo "moduleList=$moduleList"
    for module in $moduleList; do
        log "Testing module: $module"
        test_module $projectModules/$module $testType
    done
}

testProject() {
    module=$1
    testType=$2
    if [[ -z "$module" || "$module" == "all" ]]; then
        test_all_modules $testType
    else
        test_module $projectModules/$module $testType
    fi
}

createPuppetConfFile() {
    log "implement me!"
}

gemInstallPuppet() {
    packageInstall rubygems
    gemInstall puppet
    ! findPuppet && log "puppet not found" && exit 1
    puppet resource group puppet ensure=present
    puppet resource user puppet ensure=present gid=puppet shell='/sbin/nologin'
    [[ ! -e /etc/puppet/puppet.conf ]] && createPuppetConfFile
    local gemDir=$(gem environment gemdir)
    if [[ -d $gemDir/gems/puppet*/conf/auth.conf ]]; then
        mv /etc/puppet/auth.conf /etc/puppet/auth.conf.$(date "+%Y%m%d%H%M")
        cp $gemDir/gems/puppet*/conf/auth.conf /etc/puppet/auth.conf
    fi
    puppetResourceInstall --package gcc
    puppetResourceInstall --package ruby-devel
    puppetResourceInstall --package ruby-dev
    puppetResourceInstall --package augeas-devel
    puppetResourceInstall --gem ruby-augeas
    puppetResourceInstall --gem ruby-nagios
}

checkUserHome() {
    if [[ -z $HOME ]]; then
        user=$(whoami)
        [[ "$user" != "root" ]] && home_dir=/home
        export HOME=$home_dir/$user
    fi
}

# Let's get this party started!!!
# Handle Args
while [ -n "$1" ]; do
    case $1 in
        -l | --librarian )
            FLAG_LIBRARIAN="Y"
            ;;
        -v | --lib_version ) shift
            LIBRARIAN_VERSION="--version $1"
            ;;
        -g | --gem_install )
            FLAG_GEM_INSTALL="Y"
            ;;
        -t | --test ) shift
            TEST_ARGS="$1 $2"
            ;;
        -f | --facter_override ) shift
            FACTOR_OPTIONS="$1"
            ;;
        -n | --noop )
            FLAG_NOOP="Y"
            ;;
        *) usagePrompt
            exit
            ;;
    esac
    shift
done

install_lsb
checkUserHome
if [[ -n "$FLAG_GEM_INSTALL" || "$($lsbExec -ir)" =~ ^[Aa]mazon.* ]]; then
    gemInstallPuppet
else
    ! findPuppet && packageInstall puppet
    ! findPuppet && log "puppet not found" && exit 1
    # Upgrade is puppet version <3.2
    [[ "$($puppetExec --version)" =~ ^([0-2]|3\.[0-1]).* ]] && upgradePuppet
fi

configHiera
if [[ -n "$TEST_ARGS" ]]; then
    gemInstall bundle
    testProject $TEST_ARGS
    exit
fi
[[ -n "$FLAG_LIBRARIAN" ]] && updateLibrary
[[ -n "$FACTOR_OPTIONS" ]] && log "Overriding Facter with: $FACTOR_OPTIONS" && export $FACTOR_OPTIONS
[[ -n "$FLAG_NOOP" ]] && log "Using noop (no operation) run mode - no changes will be realized" && noopArg=" --noop "

# Run Puppet Apply
[[ "$EUID" != "0" ]] && echo -e "\nError:\n\t**Run this script as root or sudo.\n" && exit 1
cd ${basedir}/manifests
command="$puppetExec apply $puppetOpts $noopArg --modulepath ${projectModules}/:${basedir}/modules/ ${basedir}/manifests/site.pp"
log "\nRunning Masterless Puppet using command: \n\t$command\n"
$command
