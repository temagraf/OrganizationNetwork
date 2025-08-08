# Домашнее задание к занятию «Организация сети»

## Цель задания

1. Создать пустую VPC. Выбрать зону.  
2. Публичная подсеть.  
3. Создать в VPC subnet с названием public, сетью 192.168.10.0/24.  
4. Создать в этой подсети NAT-инстанс, присвоив ему адрес 192.168.10.254. В качестве image_id использовать fd80mrhj8fl2oe87o4e1.  
5. Создать в этой публичной подсети виртуалку с публичным IP, подключиться к ней и убедиться, что есть доступ к интернету.  
6. Приватная подсеть.  
7. Создать в VPC subnet с названием private, сетью 192.168.20.0/24.  
8. Создать route table. Добавить статический маршрут, направляющий весь исходящий трафик private сети в NAT-инстанс.  
9. Создать в этой приватной подсети виртуалку с внутренним IP, подключиться к ней через виртуалку, созданную ранее, и убедиться, что есть доступ к интернету.  

## Выполнение задания

### 1. Создание VPC и подсетей

Создал пустую VPC с подсетями:
- Публичная подсеть `public` с CIDR: 192.168.10.0/24
- Приватная подсеть `private` с CIDR: 192.168.20.0/24

![image](https://github.com/temagraf/OrganizationNetwork/blob/main/подсети.png)

### 2. Создание NAT-инстанса

В публичной подсети создан NAT-инстанс с фиксированным IP 192.168.10.254. Настроен для маршрутизации трафика из приватной подсети.

```hcl
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
      
      # Настройка IP-форвардинга
      echo 'net.ipv4.ip_forward = 1' | tee /etc/sysctl.d/99-ip-forward.conf
      sysctl -p /etc/sysctl.d/99-ip-forward.conf
      
      # Настройка NAT
      iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
      iptables-save | tee /etc/iptables/rules.v4
      
      # Включение и сохранение правил
      systemctl enable netfilter-persistent
      netfilter-persistent save
    EOF
  }
}
```

Настроена таблица маршрутизации.  
Для приватной подсети настроена таблица маршрутизации, направляющая весь исходящий трафик через NAT-инстанс:  

```hcl
resource "yandex_vpc_route_table" "nat-route" {
  name       = "nat-route-table"
  network_id = yandex_vpc_network.network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = "192.168.10.254"
  }
}
```
![image](https://github.com/temagraf/OrganizationNetwork/blob/main/таблица%20маршрутицации.png)

### 3. Создание виртуальных машин

Созданы две виртуальные машины:
- Публичная ВМ с внешним IP и доступом в интернет
- Приватная ВМ с доступом в интернет через NAT-инстанс

В публичной и приватной подсетях созданы виртуальные машины:

```hcl
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
      
      # Устанавливаем необходимые пакеты
      apt-get install -y openssh-server
      
      # Разрешаем аутентификацию по паролю
      sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
      
      # Устанавливаем пароль для пользователя ubuntu
      echo 'ubuntu:password123' | chpasswd
      
      # Перезапускаем SSH
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
      # Обновляем пакеты
      apt-get update
      
      # Устанавливаем необходимые пакеты
      apt-get install -y openssh-server
      
      # Разрешаем аутентификацию по паролю
      sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
      
      # Устанавливаем пароль для пользователя ubuntu
      echo 'ubuntu:password123' | chpasswd
      
      # Перезапускаем SSH
      systemctl restart ssh
    EOF
  }
}
```

![image](https://github.com/temagraf/OrganizationNetwork/blob/main/виртуалки.png) 


### 4. Проверка работоспособности

#### 4.1. Подключение к публичной ВМ и проверка доступа в интернет

![image](https://github.com/temagraf/OrganizationNetwork/blob/main/1-1.png)

#### 4.2. Подключение к приватной ВМ и проверка доступа в интернет

![image](https://github.com/temagraf/OrganizationNetwork/blob/main/2-2.png)


## Инфраструктура

```
                    +-----------------+
                    |                 |
                    |  Yandex Cloud   |
                    |                 |
                    +--------+--------+
                             |
                    +--------+--------+
                    |                 |
                    |      VPC        |
                    |                 |
                    +--------+--------+
                             |
           +----------------++-----------------+
           |                                   |
+----------+-----------+        +--------------+-------------+
|                      |        |                            |
| Публичная подсеть    |        | Приватная подсеть          |
| 192.168.10.0/24      |        | 192.168.20.0/24           |
|                      |        |                            |
| +-----------------+  |        | +------------------------+ |
| |                 |  |        | |                        | |
| | NAT-инстанс     +------------> Приватная VM            | |
| | 192.168.10.254  |  |        | | 192.168.20.11          | |
| |                 |  |        | |                        | |
| +-----------------+  |        | +------------------------+ |
|                      |        |                            |
| +-----------------+  |        |                            |
| |                 |  |        |                            |
| | Публичная VM    |  |        |                            |
| |                 |  |        |                            |
| +-----------------+  |        |                            |
|                      |        |                            |
+----------------------+        +----------------------------+
```

## Результат по заданию:
- Настроена маршрутизация между подсетями
- Публичная ВМ имеет доступ в интернет
- Приватная ВМ имеет доступ в интернет через NAT-инстанс
- Все соединения работают корректно
