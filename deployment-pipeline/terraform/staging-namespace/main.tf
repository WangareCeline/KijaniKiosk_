terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

resource "kubernetes_namespace" "kijani_staging" {
  metadata {
    name = "kijani-staging"
    labels = {
      environment = "staging"
      project     = "kijanikiosk"
    }
  }
}
