class base {

    $packages = [
        'screen',
        'git'
    ]

    package { $packages:
        ensure  => latest
    }

    file { '/home/vagrant/.screenrc':
        source => 'puppet:///modules/base/screenrc',
        owner  => 'vagrant',
    }

}
