#!/bin/bash

basedir="$( dirname $( readlink -f "${0}" ) )"

## required for the relative datadir path in hiera.yaml
cd ${basedir}/puppet/manifests

exec /opt/ruby/bin/puppet apply \
    --hiera_config ${basedir}/puppet/manifests/hiera.yaml \
    --modulepath ${basedir}/puppet/modules \
    ${basedir}/puppet/manifests/site.pp
