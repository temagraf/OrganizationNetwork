resource "yandex_compute_instance" "nat-instance" {
  name        = "nat-instance"
  platform_id = "standard-v1"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }

  network_interface {
    subnet_id      = yandex_vpc_subnet.public.id
    nat            = true
    ip_address     = "192.168.10.254"
    security_group_ids = [yandex_vpc_security_group.basic.id]
  }

  metadata = {
    ssh-keys  = "ubuntu:${file(var.public_key_path)}"
    user-data = <<-EOF
      #!/bin/bash
      apt-get update
      apt-get install -y iptables-persistent traceroute tcpdump curl
      
      sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

      echo 'ubuntu:password123' | chpasswd

      systemctl restart sshd
      
   
      echo 'net.ipv4.ip_forward = 1' | tee /etc/sysctl.d/99-ip-forward.conf
      sysctl -p /etc/sysctl.d/99-ip-forward.conf
      

      iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
      iptables-save | tee /etc/iptables/rules.v4
      
     
      systemctl enable netfilter-persistent
      netfilter-persistent save
    EOF
  }
}

resource "yandex_compute_instance" "public-vm" {
  name        = "public-vm"
  platform_id = "standard-v1"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8vmcue7aajpmeo39kk"  # Ubuntu 20.04 LTS
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.basic.id]
  }

  metadata = {
    ssh-keys  = "ubuntu:${file(var.public_key_path)}"
    user-data = <<-EOF
      #!/bin/bash
      # Обновляем пакеты
      apt-get update
      
   
      apt-get install -y openssh-server
    
      sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
      
      echo 'ubuntu:password123' | chpasswd
      
      systemctl restart ssh
    EOF
  }
}

resource "yandex_compute_instance" "private-vm" {
  name        = "private-vm"
  platform_id = "standard-v1"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8vmcue7aajpmeo39kk"  # Ubuntu 20.04 LTS
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.basic.id]
  }

  metadata = {
    ssh-keys  = "ubuntu:${file(var.public_key_path)}"
    user-data = <<-EOF
      #!/bin/bash
     
      apt-get update
      
     
      apt-get install -y openssh-server
      
     
      sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
      
  
      echo 'ubuntu:password123' | chpasswd
      
     
      systemctl restart ssh
    EOF
  }
}
