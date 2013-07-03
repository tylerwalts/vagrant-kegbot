class kegbot::server ( 
$kegbot_pwd,
$user = 'vagrant',
$group = 'vagrant',
$install_dir = '/opt/kegbot',
$data_dir = '/opt/kegbot-data',
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
        $data_dir,
        $config_dir,
        $log_dir
    ]

    package { $packages:
        ensure  => latest
    }

    file { $directories:
        ensure => directory,
        owner  => $user,
        group  => $group
    }
    
    exec { 'create_virtualenv':
        command => "bash -c 'virtualenv $install_dir'",
        creates => "$install_dir/bin/python",
        user    => $user,
        require => [
            File[$install_dir],
            Package['virtualenvwrapper']
        ]
    }

    $install_command = "source $install_dir/bin/activate && $install_dir/bin/easy_install -U distribute && $install_dir/bin/pip install kegbot"
    exec { 'install_kegbot':
        command  => "bash -c '$install_command'",
        creates  => "$install_dir/bin/kegbot",
        user     => $user,
        require  => Exec["create_virtualenv"]
    }

    # Make the bashrc source the kegbot activate
    file { 'add_bashrc':
        path    => "/home/$user/.bashrc",
        source  => 'puppet:///modules/kegbot/bashrc',
        owner   => $user,
        group   => $group,
        require => Exec['install_kegbot']
    }

    file { 'local_settings':
        path     => "$config_dir/local_settings.py",
        content  => template("kegbot/local_settings.py.erb"),
        owner    => $user,
        group    => $group,
        require  => [ 
            Exec['install_kegbot'],
            File[$data_dir],
            File[$config_dir]
        ]
    }

    $start_server_command = "source $install_dir/bin/activate && $install_dir/bin/kegbot runserver &> $log_dir/server.log &"
    exec { 'start_server':
        command => "bash -c '$start_server_command'",
        user    => $user,
        require => [
            File['local_settings'],
            File[$log_dir]
        ]
    }
}
