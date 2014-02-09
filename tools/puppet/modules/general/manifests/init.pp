# Installs the general components necessary for all servers
class general ( $ensure = 'latest' ){

    $packages=[
        'wget',
        'ftp',
        'unzip',
        'zip',
        'git',
        'screen',
        'tree',
        'ntp',
        'curl'
    ]

    ensure_packages($packages)

}
