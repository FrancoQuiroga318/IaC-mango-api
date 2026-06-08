# modules/sg/variables.tf

variable "name_prefix"{
    type = string 
}
variable "vpc_id"{
    type = string 
}
variable "rds_security_group_id"{
    type = string 
}
variable "api_container_port"{
    type = number
    default = 80 
}
variable "admin_container_port"{
    type = number
    default = 80 
}
variable "tags"{
    type = map(string)
    default = {} 
}
