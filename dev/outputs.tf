output "bastion_public_ip" {
  value = module.instances.bastion_public_ip
}

output "web_private_ip" {
  value = module.instances.web_instance.private_ip
}

output "ELB_DNS" {
  value = module.ELB.ELB_dns
}