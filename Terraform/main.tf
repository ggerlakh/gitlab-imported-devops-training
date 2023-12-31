terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = var.SA_AUTHORIZED_KEY
  folder_id                = local.folder_id
  zone                     = "ru-central1-a"
}

resource "yandex_vpc_network" "foo" {}

resource "yandex_vpc_subnet" "foo" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.foo.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

locals {
  folder_id = "b1gasol6123sgd9gtq3p"
  service-accounts = toset([
    "bingo-sa",
    "bingo-ig-sa",
  ])
  bingo-sa-roles = toset([
    "monitoring.editor",
  ])
  bingo-ig-sa-roles = toset([
    "compute.editor",
    "iam.serviceAccounts.user",
    "load-balancer.admin",
    "vpc.publicAdmin",
    "vpc.user",
  ])
}
resource "yandex_iam_service_account" "service-accounts" {
  for_each = local.service-accounts
  name     = "${local.folder_id}-${each.key}"
}
resource "yandex_resourcemanager_folder_iam_member" "bingo-roles" {
  for_each  = local.bingo-sa-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["bingo-sa"].id}"
  role      = each.key
}
resource "yandex_resourcemanager_folder_iam_member" "bingo-ig-roles" {
  for_each  = local.bingo-ig-sa-roles
  folder_id = local.folder_id
  member    = "serviceAccount:${yandex_iam_service_account.service-accounts["bingo-ig-sa"].id}"
  role      = each.key
}

data "yandex_compute_image" "ubuntu-vm-image" {
  family = "ubuntu-2004-lts"
}

resource "yandex_compute_instance_group" "bingo" {
  depends_on = [
    yandex_resourcemanager_folder_iam_member.bingo-ig-roles
  ]
  name               = "bingo"
  service_account_id = yandex_iam_service_account.service-accounts["bingo-ig-sa"].id
  allocation_policy {
    zones = ["ru-central1-a"]
  }
  deploy_policy {
    max_unavailable = 1
    max_creating    = 2
    max_expansion   = 2
    max_deleting    = 2
  }
  scale_policy {
    fixed_scale {
      size = 2
    }
  }
  instance_template {
    platform_id        = "standard-v2"
    service_account_id = yandex_iam_service_account.service-accounts["bingo-sa"].id
    resources {
      cores         = 2
      memory        = 1
      core_fraction = 5
    }
    scheduling_policy {
      preemptible = true
    }
    network_interface {
      network_id = yandex_vpc_network.foo.id
      subnet_ids = ["${yandex_vpc_subnet.foo.id}"]
      nat        = true
    }
    boot_disk {
      initialize_params {
        type     = "network-hdd"
        size     = "30"
        image_id = data.yandex_compute_image.ubuntu-vm-image.id
      }
    }
    metadata = {
      user-data = file("${path.module}/cloud-config.yml")
      #ssh-keys  = "vm-user:${var.SSH_VM_USER_PUB}"
    }
  }
  load_balancer {
    target_group_name = "bingo"
  }
}

resource "yandex_compute_instance_group" "bingo-db" {
  depends_on = [
    yandex_resourcemanager_folder_iam_member.bingo-ig-roles
  ]
  name               = "bingo-db"
  service_account_id = yandex_iam_service_account.service-accounts["bingo-ig-sa"].id
  allocation_policy {
    zones = ["ru-central1-a"]
  }
  deploy_policy {
    max_unavailable = 1
    max_creating    = 1
    max_expansion   = 1
    max_deleting    = 1
  }
  scale_policy {
    fixed_scale {
      size = 1
    }
  }
  instance_template {
    platform_id        = "standard-v2"
    service_account_id = yandex_iam_service_account.service-accounts["bingo-sa"].id
    resources {
      cores         = 2
      memory        = 1
      core_fraction = 5
    }
    scheduling_policy {
      preemptible = true
    }
    network_interface {
      network_id = yandex_vpc_network.foo.id
      subnet_ids = ["${yandex_vpc_subnet.foo.id}"]
      nat        = true
    }
    boot_disk {
      initialize_params {
        type     = "network-hdd"
        size     = "30"
        image_id = data.yandex_compute_image.ubuntu-vm-image.id
      }
    }
    metadata = {
      user-data = file("${path.module}/cloud-config-db.yml")
      #ssh-keys  = "vmdb-user:${var.SSH_VMDB_USER_PUB}"
    }
  }
}

resource "yandex_lb_network_load_balancer" "lb-bingo" {
  name = "bingo"

  listener {
    name        = "bingo-http-listener"
    port        = 80
    target_port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  listener {
    name        = "bingo-https-listener"
    port        = 443
    target_port = 443
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.bingo.load_balancer[0].target_group_id

    healthcheck {
      name = "http"
      http_options {
        port = 33227
        path = "/ping"
      }
    }
  }
}
