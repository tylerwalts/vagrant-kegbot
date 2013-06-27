class kegbot::mysql ( $root_pwd, $kegbot_pwd ){

    package { ['mysql-server', 'mysql-client']: }

    service{ 'mysql':
        ensure     => running,
        enable     => true,
        hasstatus  => true,
        hasrestart => true,
        require    => Package['mysql-server'],
    }

    exec { 'setRootPwd':
        command     => "mysqladmin -u root password '$root_pwd'",
        subscribe   => Package['mysql-server'],
        refreshonly => true,
        require     => Service['mysql'],
    }

    exec { 'createKegbotDb':
        command        => "mysql -uroot -p$root_pwd -e 'create database kegbot;' -sN",
        onlyif        => "test `mysql -uroot -p$root_pwd -e 'show databases;' -sN | grep -c '^kegbot$'` -eq 0",
        require        => Exec['setRootPwd'],
    }

    exec { 'createKegbotDbUser':
        command        => "mysql -uroot -p$root_pwd -e 'GRANT ALL PRIVILEGES ON kegbot.* to kegbot@localhost IDENTIFIED BY \"$kegbot_pwd\";' -sN",
        onlyif  => "test `mysql -ukegbot -p$kegbot_pwd kegbot -e 'show tables;' -sN | grep -c 'Table'` -eq 0",
        require => Exec['createKegbotDb'],
    }

}
