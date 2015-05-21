# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'fileutils'
require 'erb'
require 'ostruct'

Vagrant.require_version ">= 1.6.0"

CLOUD_CONFIG_PATH = File.join(File.dirname(__FILE__), "user-data")
CONFIG = File.join(File.dirname(__FILE__), "config.rb")

# Defaults for config options defined in CONFIG
$num_instances = 1
$instance_name = "core-%02d"

$aws_region = nil
$aws_availability_zone = nil
$aws_subnet_id = nil
$aws_security_groups = nil
$aws_ami = nil
$aws_keypair_path = '~/.ssh/id_rsa'
$aws_instance_type = 'r3.2xlarge'
$aws_rootfs_size = 32
$aws_elastic_ips = {}
$aws_slave_group = nil

$vb_gui = false
$vb_memory = 1024
$vb_cpus = 1
$vb_update_channel = 'stable'
$vb_forward_ports = [9200, 9300]

if File.exist?(CONFIG)
  require CONFIG
end

def render(templatepath, destinationpath, variables)
  if File.file?(templatepath)
    template = File.open(templatepath, "rb").read
    content = ERB.new(template).result(OpenStruct.new(variables).instance_eval { binding })
    outputpath = destinationpath.end_with?('/') ? "#{destinationpath}/#{File.basename(templatepath, '.erb')}" : destinationpath
    FileUtils.mkdir_p(File.dirname(outputpath))
    File.open(outputpath, "wb") { |f| f.write(content) }
  end
end
  
Vagrant.configure("2") do |config|
  config.vm.provider :virtualbox do |v, override|
    # On VirtualBox, we don't have guest additions or a functional vboxsf
    # in CoreOS, so tell Vagrant that so it can be smarter.
    v.check_guest_additions = false
    v.functional_vboxsf     = false

    override.vm.box = "coreos-%s" % $vb_update_channel
    override.vm.box_version = ">= 308.0.1"
    override.vm.box_url = "http://%s.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json" % $vb_update_channel
  end

  # plugin conflict
  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end
  
  config.vm.provider :aws do |aws, override|
    # https://vagrantcloud.com/dimroc/boxes/awsdummy
    override.vm.box = "dimroc/awsdummy"
    
    aws.region_config $aws_region do |region|
      region.ebs_optimzed = true
    end

    aws.instance_type = $aws_instance_type
    aws.region = $aws_region
    aws.subnet_id = $aws_subnet_id
    aws.ami = $aws_ami
    aws.associate_public_ip = true

    aws.keypair_name = $aws_keypair_name
    aws.access_key_id = $aws_access_key_id
    aws.secret_access_key = $aws_secret_access_key
    aws.security_groups = $aws_security_groups
    
    # Store root filesystem on SSD and increase its size to be able to store the docker images and volumes
    #  http://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_EbsBlockDevice.html
    aws.block_device_mapping = [{ 'DeviceName' => '/dev/xvda', 'Ebs.VolumeType' => 'gp2', 'Ebs.VolumeSize' => $aws_rootfs_size }]
    
    override.ssh.private_key_path = $aws_keypair_path
    override.ssh.insert_key = false
  end
  
  config.ssh.forward_agent = true
  config.ssh.username = "core"

  config.nfs.functional = false
  
  (1..$num_instances).each do |i|
    config.vm.define vm_name = $instance_name % i do |config|
      config.vm.hostname = vm_name

      config.vm.provider :virtualbox do |vb, override|
        vb.name = vm_name
        vb.gui = $vb_gui
        vb.memory = $vb_memory
        vb.cpus = $vb_cpus

        ip = "172.17.8.#{i+100}"
        override.vm.network :private_network, ip: ip
        
        # Provision the user-data (needs to be done for both VirtualBox/AWS due to ordering problem with config.vm.provision and override.vm.provision)
        if File.exist?(CLOUD_CONFIG_PATH)
          config.vm.provision :file, :source => "#{CLOUD_CONFIG_PATH}", :destination => "/tmp/vagrantfile-user-data"
          config.vm.provision :shell, :inline => "mkdir -p /var/lib/coreos-vagrant/ && mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true
        end
        
        # Automatically create the /etc/hosts file so that hostnames are resolved across the cluster
        hosts = ["127.0.0.1 localhost.localdomain localhost"]
        hosts += (1..$num_instances).collect {|j| "172.17.8.#{j+100} %s" % ($instance_name % j)}
        override.vm.provision :shell, :inline => "echo '%s' > /etc/hosts" % hosts.join("\n"), :privileged => true
  
        # Forward some ports so that services are reachable from the host
        if $vb_forward_ports != nil
          $vb_forward_ports.each do |port|
            override.vm.network "forwarded_port", guest: port, host: (port + i - 1), auto_correct: true
          end
        end
      end
      
      config.vm.provider :aws do |aws, override|
        aws.tags = {
          'Name' => vm_name,
        }
        
        # Provision the user-data
        if File.exist?(CLOUD_CONFIG_PATH)
          aws.user_data = File.read(CLOUD_CONFIG_PATH)
        end
        
        # Provision elastic ips
        aws.elastic_ip = $aws_elastic_ips[i - 1]
      end
      
      # Destroy any existing Fleet units
      config.vm.provision :shell, :path => "bin/fleet-destroy.sh", :privileged => true
      config.vm.provision :shell, :inline => "rm -rf /tmp/fleet/", :privileged => true
      
      # Deploy cluster infrastructure on last instance
      if i == $num_instances
        config.vm.provider :virtualbox do |vb, override|
          # Render templates with AWS IPs
          Dir.glob("fleet/*") do |file|
            render(file, ".vagrant/fleet-vb/", {:public_ips => (1..$num_instances).collect{|j| "172.17.8.#{j+100}"}})
          end
          
          # Provision and start Fleet units
          override.vm.provision :file, :source => ".vagrant/fleet-vb", :destination => "/tmp/fleet"
          override.vm.provision :shell, :path => "bin/fleet-start.sh", :args => [$num_instances.to_s], :privileged => true
        end
      
        config.vm.provider :aws do |aws, override|
          # Provision elastic ips defined in config.rb
          $aws_elastic_ips.keys.each do |eip|
            render("templates/elastic-ip.service.erb", ".vagrant/fleet-aws/elastic-ip-#{eip}.service", {:eip => eip})
          end
          
          # Render templates with AWS IPs
          Dir.glob("fleet/*") do |file|
            render(file, ".vagrant/fleet-aws/", {:public_ips => $aws_elastic_ips.values})
          end
          
          # Provision and start Fleet units
          override.vm.provision :file, :source => ".vagrant/fleet-aws", :destination => "/tmp/fleet"
          override.vm.provision :shell, :path => "bin/fleet-start.sh", :args => [$num_instances.to_s], :privileged => true
        end
      end
    end
  end
end
