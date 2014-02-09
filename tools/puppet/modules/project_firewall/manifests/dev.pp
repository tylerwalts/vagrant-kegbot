###
# Define firewall ports that are open for the project
# See documentation:  https://github.com/puppetlabs/puppetlabs-firewall
class project_firewall::dev {

    firewall { '100 allow http and https access':
        port   => [80, 443],
        proto  => tcp,
        action => accept,
    }

}
