# CoreOS Vagrant
This repo provides a Vagrantfile and sample Fleet units to create a CoreOS cluster using Amazon AWS or VirtualBox.

## Installation
1) Install dependencies

* [VirtualBox][virtualbox] 4.3.10 or greater.
* [Vagrant][vagrant] 1.6 or greater.

2) Clone this project and get it running!

```
git clone https://github.com/meltwater/vagrant-coreos/
cd vagrant-coreos
cp config.rb.sample config.rb
cp user-data.sample user-data
```

3) The [Amazon AWS provider](https://github.com/mitchellh/vagrant-aws) is a plugin for Vagrant. Install like:
```
vagrant plugin install vagrant-aws
```

## VM providers
There are two "providers" for Vagrant with slightly different instructions. Follow one of the following two options:

### VirtualBox Provider
The VirtualBox provider is the default Vagrant provider. Use this if you are unsure.

```
vagrant up
vagrant ssh core-01
```

### AWS Provider
Edit *config.rb* and specify AWS access keys, datacenter and instance settings. Take care to never check *config.rb* into source control or make it publically available, the BitCoin miners are continuously scanning for and hijacking AWS keys!

```
vagrant up --provider=aws
vagrant ssh core-01
```

## Get started 
The [using CoreOS][using-coreos] tutorial is a great starting point.

[virtualbox]: https://www.virtualbox.org/
[vagrant]: https://www.vagrantup.com/downloads.html
[using-coreos]: http://coreos.com/docs/using-coreos/

### Provisioning with user-data
The Vagrantfile will provision your CoreOS VM(s) with [coreos-cloudinit][coreos-cloudinit] if a `user-data` file is found in the project directory.
coreos-cloudinit simplifies the provisioning process through the use of a script or cloud-config document.

To get started, copy `user-data.sample` to `user-data` and make any necessary modifications.
Check out the [coreos-cloudinit documentation][coreos-cloudinit] to learn about the available features.

[coreos-cloudinit]: https://github.com/coreos/coreos-cloudinit

### Configuration
The Vagrantfile will parse a `config.rb` file containing a set of options used to configure your CoreOS cluster.
See `config.rb.sample` for more information.

## Cluster Setup
Launching a CoreOS cluster on Vagrant is as simple as configuring `$num_instances` in a `config.rb` file to 3 (or more!) and running `vagrant up`.
Make sure you provide a fresh discovery URL in your `user-data` if you wish to bootstrap etcd in your cluster.

## Fleet Units
Systemd/[Fleet][fleet] units found in the *fleet/* directory will be automatically submitted to the cluster. Some useful commands to check up on the cluster status are:

```
vagrant ssh core-01
fleetctl list-machines
fleetctl list-units
```

### ERB Templating

Fleet units units with a *.erb* extension may use Ruby [ERB][erb] templating syntax which will be executed before submission to the cluster. This allows for dynamic injection of e.g. IP-addresses or AWS keys into units. See the *fleet/samples/elasticsearch.service.erb* for examples.

[fleet]: https://coreos.com/using-coreos/clustering/
[erb]: http://www.stuartellis.eu/articles/erb/

## New Box Versions
CoreOS is a rolling release distribution and versions that are out of date will automatically update.
If you want to start from the most up to date version you will need to make sure that you have the latest box file of CoreOS.
Simply remove the old box file and vagrant will download the latest one the next time you `vagrant up`.

```
vagrant box remove coreos --provider virtualbox
```
