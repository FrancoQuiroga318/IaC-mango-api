# modules/sqs/variables.tf
variable "name_prefix" {
  type = string
}

variable "create_queues" {
  type    = bool
  default = true
}

variable "existing_api_queue_url" {
  type    = string
  default = ""
}

variable "existing_admin_queue_url" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}