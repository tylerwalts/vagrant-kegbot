class kegbot::server ( $install_base = "/opt/kegbot"){

    $packages = [
        'build-essential',
        #build-dep
        #python-mysqldb
        'git-core',
        'libjpeg-dev',
        'libmysqlclient-dev',
        'libsqlite3-0',
        'libsqlite3-dev',
        'memcached',
        'python-dev',
        'python-imaging',
        'python-mysqldb',
        'python-pip',
        'python-virtualenv',
        'virtualenvwrapper'
    ]

    package {$packages:
        ensure  => latest,
    }

    exec { 'kegbot_home':
        command => "mkdir -p $install_base",
        creates  => $install_base,
    }

    exec { 'create_kegbot_virtualenv':
        command => "virtualenv $install_base",
        creates  => "$install_base/bin/python",
        require => [
            Exec['kegbot_home'],
            Package['virtualenvwrapper']
        ],
    }

    exec { 'install_kegbot':
        command => "source ~/kb/bin/activate && pip install kegbot",
        creates  => "$install_base/bin/python",
        require => Exec['create_kegbot_virtualenv'],
    }


    notify {"TODO:  Need to create config file - left off at: https://kegbot.org/docs/server/configure-kegbot/": }
    #file { '/etc/kegbot/local_settings.py':
        #content => template("kegbot/local_settings.py.erb"),
        ##content => 'puppet:///kegbot/local_settings.py',
    #}

}
