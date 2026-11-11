variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "devsecops-eks"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "github_repository" {
  description = "GitHub repository (owner/name) allowed to assume the CI role"
  type        = string
  default     = "ematobi1/Tobi-devsecops-eks-pipeline"
}
