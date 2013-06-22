Using Vagrant for development
-----------------------------

OpenGuides ships with a [Vagrantfile](https://github.com/OpenGuides/OpenGuides/Vagrantfile) which sets up an install of Ubuntu 13.04 for testing and development.

To use this you need to install [Vagrant](http://www.vagrantup.com/) and a suitable virtualization provider such as [Virtualbox](https://www.virtualbox.org/) or [VMware Fusion](http://www.vmware.com/products/fusion/overview.html).

Then you should just be able to `vagrant up` and then `vagrant ssh` from your checkout of OpenGuides.

Once you are connected to your vagrant box you should be able to clone OpenGuides or copy your checkout from `/git`. The tests have issues if run from the `/git` mount.

If you have ssh agent forwarding set up your use of github should be seemless. If not you might want to create ssh keys on the vagrant box and add them to your github account or indeed use the https endpoint for github.


