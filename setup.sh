set -euo pipefail

configure_docker_ps_format() {
  mkdir -p ~/.docker
  cat <<'EOF' >~/.docker/config.json
{"psFormat": "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"}
EOF
}

create_default_network() {
  if ! docker network ls | grep -q 'vps-net'; then
    docker network create vps-net
    echo "Docker network 'vps-net' created."
  else
    echo "Docker network 'vps-net' already exists."
  fi
}

detect_os_family() {
  if [ ! -f /etc/os-release ]; then
    echo "Cannot detect OS." >&2
    exit 1
  fi

  . /etc/os-release
  local os_id_like="${ID_LIKE:-}"

  if echo "$ID" "$os_id_like" | grep -qi 'ubuntu'; then
    echo "ubuntu"
  elif echo "$ID" "$os_id_like" | grep -qi 'debian'; then
    echo "debian"
  elif echo "$ID" "$os_id_like" | grep -Eqi 'rhel|centos'; then
    echo "centos"
  else
    echo "unsupported"
  fi
}

setup_ubuntu() {
  # Load thông tin OS
  . /etc/os-release

  # Chặn luôn nếu không phải Ubuntu
  if [ "$ID" != "ubuntu" ]; then
    echo "❌ This script is only for Ubuntu. Current ID=$ID"
    return 1
  fi

  # Cập nhật repo & cài các gói base
  apt-get update
  apt-get install -y \
    git htop ca-certificates curl gnupg lsb-release

  # Tạo thư mục keyring cho docker
  install -m 0755 -d /etc/apt/keyrings

  # Tải GPG key của Docker
  curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # Lấy codename: jammy (22.04), noble (24.04), ...
  local codename="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo noble)}"

  # Thêm Docker repo
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $codename stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

  # Cập nhật lại repo sau khi thêm docker
  apt-get update

  # Cài đầy đủ Docker (CE + CLI + containerd + buildx + compose plugin)
  apt-get install -y \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

  # Bật & start docker daemon
  systemctl enable docker
  systemctl start docker

  echo "✅ Docker installed OK on Ubuntu ($codename)."
}


setup_debian() {
  . /etc/os-release

  apt-get update
  apt-get install -y git htop ca-certificates curl gnupg lsb-release

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/$ID/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  local codename="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo stable)}"

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$ID \
    $codename stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

  apt-get update

  # 👇 CÀI ĐỦ GÓI DOCKER
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl enable docker
  systemctl start docker
}

setup_centos() {
  yum install -y yum-utils git htop ca-certificates curl
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum makecache
}

main() {
  os_family=$(detect_os_family)
  case "$os_family" in
    ubuntu)
      setup_ubuntu
      ;;
    debian)
      setup_debian
      ;;
    centos)
      setup_centos
      ;;
    *)
      echo "Unsupported Linux distribution. Only Debian-based and CentOS/RHEL are handled." >&2
      exit 1
      ;;
  esac

  configure_docker_ps_format
  create_default_network
  cp config/.vimrc ~/.vimrc
}

main "$@"
