/*
Entradas de la EC2 administrativa.

La instancia se ubicará en una subred privada y utilizará el security group
admin_ec2 creado anteriormente. No recibe key_name porque no usaremos SSH.
*/

variable "project_name" {
  description = "Nombre del proyecto."
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente."
  type        = string
}

variable "subnet_id" {
  description = "Subred privada donde se ejecutará la instancia."
  type        = string
}

variable "security_group_id" {
  description = "Security group de la EC2 administrativa."
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Tamaño del volumen raíz cifrado en GiB."
  type        = number
  default     = 8
}
