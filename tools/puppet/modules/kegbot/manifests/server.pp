class kegbot::server ( 
    $kegbot_pwd,
    $user = 'vagrant',
    $group = 'vagrant',
    $install_dir = '/opt/kegbot',
    $data_dir = '/opt/kegbot/data',
    $config_dir = '/etc/kegbot',
    $log_dir = '/var/log/kegbot'
    ){

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

    $directories = [
        $install_dir,
        $config_dir,
        $log_dir
    ]

    package { $packages:
        ensure  => latest,
    }

    file { $directories:
        ensure => directory,
        owner  => $user,
        group  => $group,
    }

    # Create gFlags file for setup script
    file { 'config_gflags':
        path     => "$config_dir/config.gflags",
        content  => template("kegbot/config.gflags.erb"),
        owner    => $user,
        group    => $group,
        require  => [
            File[$config_dir]
        ],
    }

    exec { 'create_virtualenv':
        command => "bash -c 'virtualenv $install_dir'",
        creates => "$install_dir/bin/python",
        user    => $user,
        require => [
            File[$install_dir],
            Package['virtualenvwrapper']
        ],
    }

    $install_command = "source $install_dir/bin/activate && $install_dir/bin/easy_install -U distribute && $install_dir/bin/pip install kegbot"
    exec { 'install_kegbot':
        command => "bash -c '$install_command'",
        creates => "$install_dir/bin/kegbot",
        user    => $user,
        timeout => 600,
        require => Exec["create_virtualenv"],
    }

    # Make the bashrc source the kegbot activate
    file { 'add_bashrc':
        path    => "/home/$user/.bashrc",
        source  => 'puppet:///modules/kegbot/bashrc',
        owner   => $user,
        group   => $group,
        require => Exec['install_kegbot'],
    }

    $setup_server_command = "source $install_dir/bin/activate && $install_dir/bin/setup-kegbot.py --flagfile=$config_dir/config.gflags"
    exec { 'setup_server':
        command => "bash -c '$setup_server_command'",
        user    => $user,
        creates => "/opt/kegbot/data",
        require => [
            Exec['install_kegbot'],
            File['config_gflags']
        ],
    }

    $upgrade_server_command = "source $install_dir/bin/activate && $install_dir/bin/pip install --upgrade kegbot && echo 'yes' | $install_dir/bin/kegbot kb_upgrade" 
    exec { 'upgrade_kegbot':
        command  => "bash -c '$upgrade_server_command'",
        user     => $user,
        require  => Exec["setup_server"],
    }

    $start_server_command = "source $install_dir/bin/activate && $install_dir/bin/kegbot runserver 0.0.0.0:8000 &> $log_dir/server.log &"
    exec { 'start_server':
        command => "bash -c '$start_server_command'",
        user    => $user,
        require => [
            Exec['upgrade_kegbot'],
            File[$log_dir]
        ],
    }

    $start_celeryd_command = "source $install_dir/bin/activate && $install_dir/bin/kegbot celeryd_detach -E"
    exec { 'start_celeryd':
        command => "bash -c '$start_celeryd_command'",
        user    => $user,
        require => Exec['start_server'],
    }

}
