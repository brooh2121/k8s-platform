# terraform/outputs.tf

output "master_ip" {
  value = multipass_instance.master.ipv4
  description = "IP address of the master node"
}