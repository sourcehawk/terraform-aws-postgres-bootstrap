variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "db_subnet_ids" {
  description = "The IDs of the subnets"
  type        = list(string)
}

variable "allowed_cidrs" {
  description = "The allowed CIDRs"
  type = list(object({
    cidr_blocks = list(string)
    description = string
  }))
}
