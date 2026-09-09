# opentofu/outputs.tf

output "master_ip" {
  value       = module.master_vm.ip
  description = "IP address of the master node"
}

output "worker_ips" {
  value = [
    module.worker1_vm.ip,
    module.worker2_vm.ip
  ]
  description = "IP addresses of the worker nodes"
}