domain     = 'kegbot.mydomain.com'
vagrantbox = 'http://puppet-vagrant-boxes.puppetlabs.com/ubuntu-server-12042-x64-vbox4210.box'

nodes = [
  { :hostname => 'vagrant', :ip => '192.168.0.69', :box => 'precise64' },
]

Vagrant.configure("2") do |config|
 
  nodes.each do |node|
    config.vm.define node[:hostname] do |node_config|
      node_config.vm.box = node[:box]
      node_config.vm.hostname = node[:hostname] + '.' + domain
      node_config.vm.network :private_network, ip: node[:ip]

      node_config.vm.box_url = vagrantbox

      memory = node[:ram] ? node[:ram] : 1024;
      node_config.vm.provider :virtualbox do |vb|
        vb.customize [
            'modifyvm', :id,
            '--name', node[:hostname],
            '--memory', memory.to_s
        ]
        vb.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1" ]
      end

      node_config.vm.network :forwarded_port, guest: 8000, host: 8000
    end
  end

  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = 'tools/puppet/manifests'
    puppet.manifest_file = 'site.pp'
    puppet.module_path = 'tools/puppet/modules'
    puppet.options = "--hiera_config /vagrant/tools/puppet/manifests/config/hiera.yaml"
  end
end
