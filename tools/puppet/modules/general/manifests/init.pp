# Installs the general components necessary for all servers
class general ( $ensure = 'latest' ){

    $packages=[
        'wget',
        'ftp',
        'unzip',
        'zip',
        'git',
        'vim-enhanced',
        'screen',
        'tree',
        'net-snmp',
        'ntp',
        'curl'
    ]

    ensure_packages($packages)

}
