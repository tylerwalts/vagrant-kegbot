Exec { path        => [ '/usr/local/bin', '/usr/bin', '/usr/sbin', '/bin', '/sbin', ], }

# Assign Classes, Defines & Parameters using Hiera
hiera_include("classes")

# Realize Defines, if any
import "defines.pp"

