Exec { path        => [ '/usr/local/bin', '/usr/bin', '/usr/sbin', '/bin', '/sbin', ], }

# Assign Classes, Defines & Parameters using Hiera
hiera_include("classes")
create_resources('kegbot::instance', hiera('kegbot_instances', {}))

