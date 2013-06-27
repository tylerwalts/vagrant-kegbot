class base {

    $packages = [
        'screen',
        'git'
    ]

    package { $packages:
        ensure  => latest
    }

}
