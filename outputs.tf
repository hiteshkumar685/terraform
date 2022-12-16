output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = module.eks_blueprints.configure_kubectl
}

output "docker_machine_security_group_id" {
  value = module.gitlab-runner.runner_sg_id
}