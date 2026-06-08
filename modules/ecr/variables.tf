# modules/ecr/variables.tf
variable "name_prefix" {
    type = string 
}
variable "tags"{
    type = map(string)
    default = {}
}
