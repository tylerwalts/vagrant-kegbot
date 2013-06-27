class kegbot::server ( $install_base = "/opt/kegbot"){

    $packages = [
        'build-essential',
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

    package { $packages:
        ensure  => latest,
    }

    exec { 'kegbot_home':
        command => "mkdir -p $install_base",
        creates => $install_base,
    }

    exec { 'create_kegbot_virtualenv':
        command => "virtualenv $install_base",
        creates => "$install_base/bin/python",
        require => [
            Exec['kegbot_home'],
            Package['virtualenvwrapper']
        ],
    }

    $install_kegbot_command  = "source /opt/kegbot/bin/activate && sudo pip install kegbot"
    exec { 'install_kegbot':
        command  => "bash -c '$install_kegbot_command'",
        creates  => "/usr/local/bin/kegbot",
        user     => 'vagrant',
        timeout  => 900,
        require  => Exec['create_kegbot_virtualenv'],
    }

    # Make the bashrc source the kegbot activate
    file { '/home/vagrant/.bashrc':
        source  => 'puppet:///modules/kegbot/bashrc',
        owner   => 'vagrant',
        require => Exec['install_kegbot'],
    }

    ####  TODO:  Ensure kegbot configuration and data dir

    #file { '/etc/kegbot/local_settings.py':
        #content  => template("kegbot/local_settings.py.erb"),
        ##content => 'puppet:///kegbot/local_settings.py',
    #}

    #file { '/opt/kegbot-data':

}
