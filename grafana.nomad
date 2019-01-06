job "grafana" {
  datacenters = ["[[.datacenter]]"]
  type = "service"
  group "grafana" {
    update {
      stagger      = "10s"
      max_parallel = "1"
    }
    count = "1"
    restart {
      attempts = 5
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }
    task "grafana" {
      kill_timeout = "180s"
      env {
        GF_PATHS_CONFIG       = "/local/grafana/grafana.ini"
        GF_PATHS_PROVISIONING = "/local/grafana/provisioning"
      }
      logs {
        max_files     = 5
        max_file_size = 10
      }
      template {
        data          = <<EOH
[paths]
provisioning = /local/grafana/provisioning
[server]
domain = REPLACEME
root_url = https://%(domain)s/
[database]
log_queries =
[users]
auto_assign_org_role = Admin
viewers_can_edit = true
[auth]
disable_login_form = true
[auth.anonymous]
enabled = false
[auth.google]
enabled = true
client_id = REPLACEME
client_secret = REPLACEME
scopes = https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email
auth_url = https://accounts.google.com/o/oauth2/auth
token_url = https://accounts.google.com/o/oauth2/token
allow_sign_up = true
allowed_domains = REPLACEME REPLACEME
[auth.basic]
enabled = false
EOH
        destination   = "local/grafana/grafana.ini"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
      template {
        data          = <<EOH
apiVersion: 1
datasources:
- name: Prometheus
  type: prometheus
  access: proxy
  orgId: 1
  url: http://prometheus.service:9090/prometheus/
  password:
  user:
  database:
  basicAuth:
  basicAuthUser:
  basicAuthPassword:
  withCredentials:
  isDefault: true
  version: 1
  editable: true
EOH
        destination   = "local/grafana/provisioning/datasources/datasources.yaml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
      template {
        data          = <<EOH
apiVersion: 1
providers:
- name: 'default'
  orgId: 1
  folder: ''
  type: file
  disableDeletion: false
  updateIntervalSeconds: 30 #how often Grafana will scan for changed dashboards
  options:
    path: /local/grafana/provisioning/dashboards-json
EOH
        destination   = "local/grafana/provisioning/dashboards/dashboards.yaml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
      artifact {
        source      = "s3::https://storage.googleapis.com/REPLACEME/json"
        destination = "local/grafana/provisioning/dashboards-json"
        options {
          aws_access_key_id     = "[[.gcs_access_key]]"
          aws_access_key_secret = "[[.gcs_secret_key]]"
        }
      }
      driver = "docker"
      config {
        logging {
            type = "syslog"
            config {
              tag = "${NOMAD_JOB_NAME}${NOMAD_ALLOC_INDEX}"
            }   
        }
	network_mode       = "host"
        force_pull         = true
        image              = "grafana/grafana:[[.version]]"
	command            = "exec grafana-server"
        hostname           = "${attr.unique.hostname}"
	dns_servers        = ["${attr.unique.network.ip-address}"]
        dns_search_domains = ["consul","service.consul","node.consul"]
      }
      resources {
        memory = "[[.ram]]"
        network {
          mbits = 100
          port "healthcheck" {
            static = "3000"
          }
        } #network
      } #resources
      service {
        name = "grafana"
        tags = ["[[.version]]"]
        port = "healthcheck"
        check {
          name     = "grafana-internal-port-check"
          port     = "healthcheck"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        } #check
      } #service
    } #task
  } #group
} #job
