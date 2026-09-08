# Вывод IP-адресов
output "master_ip" {
  value = multipass_instance.master.ipv4
}

output "worker_ips" {
  value = [
    multipass_instance.worker1.ipv4,
    multipass_instance.worker2.ipv4
  ]
}