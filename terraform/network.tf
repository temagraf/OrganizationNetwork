# Network
resource "yandex_vpc_network" "vpc" {
  name = var.vpc_name
}

# Public Subnet
resource "yandex_vpc_subnet" "public" {
  name           = "public"
  zone           = var.zone
  network_id     = yandex_vpc_network.vpc.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# Private Subnet
resource "yandex_vpc_subnet" "private" {
  name           = "private"
  zone           = var.zone
  network_id     = yandex_vpc_network.vpc.id
  route_table_id = yandex_vpc_route_table.private_route.id
  v4_cidr_blocks = ["192.168.20.0/24"]
}

# Route Table for Private Subnet
resource "yandex_vpc_route_table" "private_route" {
  name       = "private-route"
  network_id = yandex_vpc_network.vpc.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address  = "192.168.10.254"
  }
}
