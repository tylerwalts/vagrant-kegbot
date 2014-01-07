class kegbot::pre {

    stage { 'preinstall':
        before => Stage['main']
    }

    class apt_get_update {
        exec { 'apt-get -y update': }
    }

    class { 'apt_get_update':
        stage => preinstall
    }

}
