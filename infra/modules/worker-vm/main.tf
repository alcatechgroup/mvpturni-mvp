# GCE e2-micro para o queue:work (ADR-004 — Cloud Run não serve processo long-running sem HTTP).
# Opção alternativa futura: Cloud Scheduler → Cloud Run Job (ADR-004, seção Negativas).

resource "google_compute_instance" "worker" {
  project      = var.project_id
  zone         = "${var.region}-a"
  name         = "turni-worker-${var.env}"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable" # Container-Optimized OS — sem SO a manter
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

  # Startup (COS): no boot, busca os segredos no Secret Manager (a SA da VM tem
  # secretAccessor) com a imagem cloud-sdk — o host do COS não tem curl/gcloud — e
  # escreve um env-file em /run (tmpfs). Conecta o Cloud SQL por IP privado (mesma
  # VPC, sem proxy). Então sobe o queue:work via Docker com --env-file.
  metadata = {
    user-data = <<-CLOUD_INIT
      #cloud-config
      write_files:
        - path: /var/lib/turni/fetch-secrets.sh
          permissions: "0755"
          content: |
            #!/bin/bash
            set -e
            umask 077
            IMG=google/cloud-sdk:slim
            /usr/bin/docker pull "$IMG" >/dev/null 2>&1 || true
            sec() { /usr/bin/docker run --rm "$IMG" gcloud secrets versions access latest --secret="$1" --project="${var.project_id}"; }
            {
              echo "APP_ENV=production"
              echo "APP_DEBUG=false"
              echo "APP_KEY=$(sec ${var.app_key_secret_id})"
              echo "DB_CONNECTION=pgsql"
              echo "DB_HOST=${var.db_private_ip}"
              echo "DB_PORT=5432"
              echo "DB_DATABASE=turni"
              echo "DB_USERNAME=turni"
              echo "DB_PASSWORD=$(sec ${var.db_password_secret_id})"
              echo "QUEUE_CONNECTION=database"
              echo "CACHE_STORE=database"
              echo "LOG_CHANNEL=stderr"
              echo "MAIL_MAILER=${var.mail_mailer}"
              echo "MAIL_FROM_ADDRESS=${var.mail_from_address}"
              echo "MAIL_FROM_NAME=${var.mail_from_name}"
              echo "RESEND_API_KEY=$(sec ${var.resend_api_key_secret_id})"
            } > /run/turni-worker.env
        - path: /etc/systemd/system/turni-worker.service
          permissions: "0644"
          content: |
            [Unit]
            Description=Turni Queue Worker
            After=network-online.target
            Wants=network-online.target

            [Service]
            Restart=always
            RestartSec=10
            ExecStartPre=/usr/bin/docker pull ${var.image}
            ExecStartPre=/bin/bash /var/lib/turni/fetch-secrets.sh
            ExecStart=/usr/bin/docker run --rm --name turni-worker --env-file /run/turni-worker.env ${var.image} php artisan queue:work database --tries=3 --sleep=2 --timeout=60
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
    ignore_changes = [metadata] # o CI atualiza a imagem diretamente
  }
}
