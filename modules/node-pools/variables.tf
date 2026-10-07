variable "cluster_name" {
  description = "EKS cluster name. Tags the nodes with `karpenter.sh/discovery`, and selects subnets / security groups by that tag when their ids aren't given."
  type        = string
}

variable "node_role_name" {
  description = "IAM role name for the Karpenter nodes (e.g. the `node_iam_role_name` output of terraform-aws-modules/eks//modules/karpenter)."
  type        = string
}

variable "ami_alias" {
  description = "EC2NodeClass AMI alias, e.g. `bottlerocket@v1.64.0`."
  type        = string
}

variable "user_data" {
  description = "userData for the EC2NodeClass in the AMI family's format (Bottlerocket TOML). Empty for none."
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnets for the nodes. Empty: select subnets tagged `karpenter.sh/discovery = <cluster_name>`."
  type        = list(string)
  default     = []
}

variable "node_security_group_id" {
  description = "The node security group, selected by id (recommended: an orphaned node SG that kept the discovery tag breaks NLB target groups). Null: select by the `karpenter.sh/discovery` tag."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags for the EC2 instances Karpenter launches."
  type        = map(string)
  default     = {}
}

variable "tenants" {
  description = <<-EOT
    One tainted NodePool + EC2NodeClass per tenant (`gizmosql-<key>`, label and taint
    `gizmodata.com/tenant=<key>`). One shared tenant gives every workload a place to run;
    a tenant per customer isolates them. instance_types must cover every compute size the
    control plane offers that tenant (sizes pin their pods to their instance type).
  EOT
  type = map(object({
    instance_types = list(string)
    kms_key_arn    = string
    capacity_types = optional(list(string), ["on-demand", "spot"])
    cpu_limit      = optional(string, "256")
    memory_limit   = optional(string, "2048Gi")
  }))

  validation {
    condition     = alltrue([for t in values(var.tenants) : length(t.instance_types) > 0])
    error_message = "Every tenant needs at least one instance type."
  }
  validation {
    condition = alltrue([for t in values(var.tenants) :
    length(t.capacity_types) > 0 && length(setsubtract(t.capacity_types, ["on-demand", "spot"])) == 0])
    error_message = "capacity_types must be a non-empty subset of [\"on-demand\", \"spot\"]."
  }
}

variable "shared_compute" {
  description = "Optional bin-packed pool for shared sizes (pico / nano / micro): `gizmodata.com/compute=shared`, on-demand only, on an existing tenant's EC2NodeClass. Null: none."
  type = object({
    tenant         = string
    instance_types = list(string)
    cpu_limit      = optional(string, "256")
    memory_limit   = optional(string, "2048Gi")
  })
  default = null

  validation {
    condition     = var.shared_compute == null || contains(keys(var.tenants), try(var.shared_compute.tenant, ""))
    error_message = "shared_compute.tenant must be one of the tenants (it uses that tenant's EC2NodeClass)."
  }
}

variable "release_name" {
  description = "Helm release name."
  type        = string
  default     = "karpenter-node-config"
}

variable "namespace" {
  description = "Namespace for the Helm release record (the NodePools / EC2NodeClasses are cluster-scoped)."
  type        = string
  default     = "kube-system"
}
