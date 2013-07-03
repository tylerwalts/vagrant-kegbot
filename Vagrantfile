domain     = 'mydomain.com'
#vagrantbox = 'http://puppet-vagrant-boxes.puppetlabs.com/ubuntu-server-12042-x64-vbox4210.box'
vagrantbox = 'ubuntu-server-12042-x64-vbox4210.box'

nodes = [
  { :hostname => 'kegbot',          :ip => '192.168.0.69', :box => 'Ubuntu12' },
]

Vagrant::Config.run do |config|
 
  ### Port Forwarding
  # kegbot server
  config.vm.forward_port 8000, 6969 

  nodes.each do |node|
    config.vm.define node[:hostname] do |node_config|
      node_config.vm.box = node[:box]
      node_config.vm.host_name = node[:hostname] + '.' + domain
      node_config.vm.network :hostonly, node[:ip]
      node_config.vm.box_url = vagrantbox

      memory = node[:ram] ? node[:ram] : 1024;
      node_config.vm.customize [
        'modifyvm', :id,
        '--name', node[:hostname],
        '--memory', memory.to_s
      ]
    end
  end

  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = 'puppet/manifests'
    puppet.manifest_file = 'site.pp'
    puppet.module_path = 'puppet/modules'
    puppet.options = "--hiera_config hiera.yaml"
    puppet.facter = {
        "is_vagrant" => true,
    }
  end
end
