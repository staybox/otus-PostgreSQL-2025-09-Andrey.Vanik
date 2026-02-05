terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex" # Обязательно указывается провайдер
    }
  }
}

provider "yandex" {
  service_account_key_file = file("./vm_keys/authorized_key.json") # Создайте в папке terraform подпапку vm_keys и положите туда Вами сгенерированные SSH ключи.
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = "ru-central1-a" # Здесь можно указать зону, где будут развернуты Ваши сервера
}