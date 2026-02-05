output "connection_info" {
  value = {
    gui_workstation_public_ip = yandex_compute_instance.gui.network_interface.0.nat_ip_address
    ssh_command_gui           = "ssh ubuntu@${yandex_compute_instance.gui.network_interface.0.nat_ip_address}"
    
    internal_ips = {
      etcd    = yandex_compute_instance.etcd[*].network_interface.0.ip_address
      db      = yandex_compute_instance.db[*].network_interface.0.ip_address
      haproxy = yandex_compute_instance.haproxy[*].network_interface.0.ip_address
      monitor = yandex_compute_instance.monitor.network_interface.0.ip_address
    }
  }
}

# Вывод данных
output "gui_public_ip" {
  value = yandex_compute_instance.gui.network_interface.0.nat_ip_address
}

output "load_balancer_internal_ip" {
  value = "10.10.10.100"
}