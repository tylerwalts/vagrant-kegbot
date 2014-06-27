domain     = 'kegbot.mydomain.com'
vagrantbox = 'https://cloud-images.ubuntu.com/vagrant/trusty/20140625/trusty-server-cloudimg-i386-vagrant-disk1.box'

nodes = [
  { :hostname => 'vagrant', :ip => '192.168.0.69', :box => 'trusty' },
]

Vagrant.configure("2") do |config|

  nodes.each do |node|
    config.vm.define node[:hostname] do |node_config|
      node_config.vm.box = node[:box]
      node_config.vm.hostname = node[:hostname] + '.' + domain
      node_config.vm.network :private_network, ip: node[:ip]

      node_config.vm.box_url = vagrantbox

      memory = node[:ram] ? node[:ram] : 2048;
      node_config.vm.provider :virtualbox do |vb|
        vb.customize [
            'modifyvm', :id,
            '--name', node[:hostname],
            '--memory', memory.to_s
        ]
        vb.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1" ]
      end

      node_config.vm.network :forwarded_port, guest: 8000, host: 8000, auto_correct: true

      node_config.vm.provision :shell do |shell|
        shell.inline = "/vagrant/tools/puppet/run_puppet_apply.sh -g -l -f FACTER_hostname=" + node[:hostname]
      end
    end
  end
end
