# --- ЛОКАЛЬНЫЕ ПЕРЕМЕННЫЕ ---
locals {
  # ID образа Rocky Linux 9 (из Marketplace)
  rocky_image_id = "fd86813qeuo70ff2q6e9"
}

# --- СЕТЬ (НОВАЯ АРХИТЕКТУРА) ---

# Берем существующую сеть
data "yandex_vpc_network" "default" {
  name = "default"
}

# 1. Создаем NAT-шлюз (дает интернет без расхода белых IP)
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "diploma-gateway"
  shared_egress_gateway {}
}

# 2. Создаем таблицу маршрутизации (весь трафик -> в шлюз)
resource "yandex_vpc_route_table" "nat_route_table" {
  name       = "diploma-route-table"
  network_id = data.yandex_vpc_network.default.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

# 3. Создаем СВОЮ подсеть и привязываем к ней таблицу маршрутизации
resource "yandex_vpc_subnet" "diploma_subnet" {
  name           = "diploma-subnet-internal"
  zone           = "ru-central1-a"
  network_id     = data.yandex_vpc_network.default.id
  v4_cidr_blocks = ["10.10.10.0/24"] # Новая адресация
  route_table_id = yandex_vpc_route_table.nat_route_table.id
}

# Образ Ubuntu для GUI
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# --- 1. ETCD (3 шт) - БЕЗ ВНЕШНЕГО IP ---
resource "yandex_compute_instance" "etcd" {
  count       = 3
  name        = "etcd-${count.index + 1}"
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }
  scheduling_policy { preemptible = true }

  boot_disk {
    initialize_params {
      image_id = local.rocky_image_id
      type     = "network-ssd"
      size     = 10
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.diploma_subnet.id
    # Новые внутренние IP
    ip_address = "10.10.10.1${count.index + 1}" 
    nat        = false # ЭКОНОМИМ КВОТУ, интернет будет через шлюз
  }

  metadata = {
    ssh-keys = "rocky:${file(var.ssh_key_path)}"
  }
}

# --- 2. DB Nodes (3 шт) - БЕЗ ВНЕШНЕГО IP ---
resource "yandex_compute_instance" "db" {
  count       = 3
  name        = "pg-node-${count.index + 1}"
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }
  scheduling_policy { preemptible = true }

  boot_disk {
    initialize_params {
      image_id = local.rocky_image_id
      type     = "network-ssd"
      size     = 20
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.diploma_subnet.id
    ip_address = "10.10.10.2${count.index + 1}" 
    nat        = false
  }

  metadata = {
    ssh-keys = "rocky:${file(var.ssh_key_path)}"
  }
}

# --- 3. HAProxy (2 шт) - БЕЗ ВНЕШНЕГО IP ---
resource "yandex_compute_instance" "haproxy" {
  count       = 2
  name        = "haproxy-${count.index + 1}"
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }
  scheduling_policy { preemptible = true }

  boot_disk {
    initialize_params {
      image_id = local.rocky_image_id
      type     = "network-ssd"
      size     = 10
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.diploma_subnet.id
    ip_address = "10.10.10.3${count.index + 1}"
    nat        = false
  }

  metadata = {
    ssh-keys = "rocky:${file(var.ssh_key_path)}"
  }
}

# --- 4. Monitor (1 шт) - БЕЗ ВНЕШНЕГО IP ---
resource "yandex_compute_instance" "monitor" {
  name        = "monitor-01"
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }
  scheduling_policy { preemptible = true }

  boot_disk {
    initialize_params {
      image_id = local.rocky_image_id
      type     = "network-ssd"
      size     = 15
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.diploma_subnet.id
    ip_address = "10.10.10.40"
    nat        = false
  }

  metadata = {
    ssh-keys = "rocky:${file(var.ssh_key_path)}"
  }
}

# --- 5. GUI Workstation - ЕДИНСТВЕННЫЙ БЕЛЫЙ IP ---
resource "yandex_compute_instance" "gui" {
  name        = "gui-workstation"
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }
  scheduling_policy { preemptible = true }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      type     = "network-ssd"
      size     = 30
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.diploma_subnet.id
    # Ему оставляем NAT, чтобы ты мог подключиться
    nat       = true 
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_key_path)}"
  }
}

# ------------------------
# --- Группа целевых ресурсов ---
resource "yandex_lb_target_group" "haproxy_nodes" {
  name = "haproxy-target-group"

  # Динамический блок: он пройдет по списку всех созданных HAProxy
  # и сам подставит их IP и ID подсети.
  dynamic "target" {
    for_each = yandex_compute_instance.haproxy
    content {
      subnet_id = yandex_vpc_subnet.diploma_subnet.id
      address   = target.value.network_interface.0.ip_address
    }
  }
}

# --- Сетевой балансировщик ---
resource "yandex_lb_network_load_balancer" "pg_balancer" {
  name = "pg-cluster-lb"
  type = "internal"

  listener {
    name = "postgres-rw"
    port = 5432
    target_port = 5432
    internal_address_spec {
      subnet_id = yandex_vpc_subnet.diploma_subnet.id # ССЫЛКА ВМЕСТО ID
      address   = "10.10.10.100"
    }
  }

  listener {
    name = "postgres-ro"
    port = 5433
    target_port = 5433
    internal_address_spec {
      subnet_id = yandex_vpc_subnet.diploma_subnet.id # ССЫЛКА ВМЕСТО ID
      address   = "10.10.10.100"
    }
  }

  listener {
    name = "haproxy-web"
    port = 8080
    target_port = 8080
    internal_address_spec {
      subnet_id = yandex_vpc_subnet.diploma_subnet.id # ССЫЛКА ВМЕСТО ID
      address   = "10.10.10.100"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.haproxy_nodes.id
    healthcheck {
      name = "haproxy-health-check"
      tcp_options {
        port = 8080
      }
      interval            = 2
      timeout             = 1
      unhealthy_threshold = 2
      healthy_threshold   = 2
    }
  }
}
