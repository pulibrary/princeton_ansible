Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2204" # Or any other x86_64 box.

  config.vm.provider "virtualbox" do |vb|
    # This is the crucial part:  Tell VirtualBox to use QEMU.
    vb.qemu_use_session = false # Use system QEMU, not the one bundled with VB (which is usually older)
    vb.qemu_path = "/opt/homebrew/bin/qemu-system-x86_64"  # Path to the QEMU binary.
    # Important:  Set the CPU to a compatible model.
    vb.customize ["modifyvm", :id, "--cpus", "2"] # Example: 2 CPUs
    vb.customize ["modifyvm", :id, "--memory", "4096"] # Example: 4GB RAM
    vb.customize [
      "modifyvm", :id,
      "--cpu-profile", "host"  # Or try a specific x86_64 CPU model like "Intel Core i7-6700K"
    ]

    # Other VirtualBox settings (optional)
    vb.gui = false  # Run headless (no GUI)
    vb.name = "my-x86-vm"

    #Optional, but recommended: Add a bridged or host-only network interface. NAT is usually the default.
    vb.customize ["modifyvm", :id, "--nic2", "hostonly", "--hostonlyadapter2", "vboxnet0"] # Example host-only network
  end

    # Configure port forwarding (if necessary)
    config.vm.network "forwarded_port", guest: 80, host: 8080
    config.vm.network "forwarded_port", guest: 22, host: 2222 #often good to change the default

    # Provisioning (optional) - run scripts after the VM is booted
    config.vm.provision "shell", inline: <<-SHELL
      echo "Hello from inside the VM!"
    SHELL

    # Enable Shared folders (optional)
    #  config.vm.synced_folder ".", "/vagrant" , type: "virtualbox"

end
