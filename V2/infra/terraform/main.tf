module "eks" {
  source = "./modules/eks"
  cluster_name = var.cluster_name
}
