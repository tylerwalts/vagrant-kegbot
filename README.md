vagrant-kegbot
==============

This project uses vagrant and puppet to configure an image to host the kegbot server from www.kegbot.org.


Usage:
======

1.  Install Virtualbox
2.  Install Vagrant
3.  Get code:
* `git clone https://github.com/tylerwalts/vagrant-kegbot.git`
* (Optional - change passwords, config): `vi vagrant-kegbot/puppet/manifests/config/vagrant.kegbot.mydomain.com.json`
4.  Run VM:
* `cd vagrant-kegbot`
* `vagrant up`
5.  Test in browser:
* http://192.168.0.69:8000/

