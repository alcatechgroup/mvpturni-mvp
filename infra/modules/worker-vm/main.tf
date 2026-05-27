# GCE e2-micro para o queue:work (ADR-004 — Cloud Run não serve processo long-running sem HTTP).
# Opção alternativa futura: Cloud Scheduler → Cloud Run Job (ADR-004, seção Negativas).

resource "google_compute_instance" "worker" {
  project      = var.project_id
  zone         = "${var.region}-a"
  name         = "turni-worker-${var.env}"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"  # Container-Optimized OS — sem SO a manter
      size  = 10
    }
  }

  network_interface {
    network    = var.vpc_network
    subnetwork = var.subnetwork
    # Sem IP público (acesso via Cloud SQL socket + IAM)
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  # Startup: puxa a imagem mais recente e sobe o worker via Docker
  metadata = {
    user-data = <<-CLOUD_INIT
      #cloud-config
      write_files:
        - path: /etc/systemd/system/turni-worker.service
          permissions: "0644"
          content: |
            [Unit]
            Description=Turni Queue Worker
            After=network.target

            [Service]
            Restart=always
            RestartSec=5
            ExecStartPre=/usr/bin/docker pull ${var.image}
            ExecStart=/usr/bin/docker run --rm \
              --name turni-worker \
              -e APP_ENV=production \
              -e DB_SOCKET=/cloudsql/${var.cloudsql_connection_name} \
              -v /cloudsql:/cloudsql \
              ${var.image} \
              php artisan queue:work database --tries=3 --sleep=2 --timeout=60
            ExecStop=/usr/bin/docker stop turni-worker

            [Install]
            WantedBy=multi-user.target

      runcmd:
        - systemctl daemon-reload
        - systemctl enable turni-worker
        - systemctl start turni-worker
    CLOUD_INIT
  }

  tags = ["turni-worker"]

  lifecycle {
    ignore_changes = [metadata]  # o CI atualiza a imagem diretamente
  }
}
