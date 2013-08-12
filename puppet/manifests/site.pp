Exec {
    path        => [ '/usr/local/bin', '/usr/bin', '/usr/sbin', '/bin', '/sbin', ],
}

# Hiera needs to know where to find the config, relative to puppet files
case $::fqdn {
    /vagrant/: { $puppet_cwd="/vagrant/puppet/" }
    default:{ fail("Set path to puppet files") }
}

# Classes
hiera_include("classes", [])

