variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Folder ID"
  type        = string
}

variable "ssh_key_path" {
  description = "Путь к публичному SSH ключу"
  type        = string
  default     = "./vm_keys/id_rsa.pub"
}