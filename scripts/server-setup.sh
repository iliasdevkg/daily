#!/usr/bin/env bash
# Ubuntu 24.04 LTS — one-time production server bootstrap. Idempotent:
# safe to re-run (every step checks before acting), so a partial run that
# gets interrupted can just be re-run from the top.
#
# Usage (as a sudo-capable user, NOT root — the script uses sudo itself
# and creates a dedicated deploy user):
#   curl -fsSL https://raw.githubusercontent.com/<you>/daily_all_system/main/scripts/server-setup.sh | bash
#   # or, cloned locally:
#   chmod +x scripts/server-setup.sh && ./scripts/server-setup.sh
#
# What this does NOT do: issue TLS certs (needs DNS pointed here first —
# see scripts/init-letsencrypt.sh, run after this), clone the repo, or
# start any containers — see scripts/deploy.sh for that half.
set -euo pipefail

DEPLOY_USER="${DEPLOY_USER:-deploy}"
TIMEZONE="${TIMEZONE:-UTC}"
SWAP_SIZE_GB="${SWAP_SIZE_GB:-4}"

log() { echo -e "\n\033[1;34m==> $1\033[0m"; }

if [ "$(id -u)" -eq 0 ]; then
  echo "root катары эмес, sudo укугу бар колдонуучу катары иштетиңиз." >&2
  exit 1
fi

# ── 1. System update ─────────────────────────────────────────────────
log "Системаны жаңылоо"
sudo apt-get update -y
sudo apt-get upgrade -y

# ── 2. Timezone ───────────────────────────────────────────────────────
log "Timezone: $TIMEZONE"
sudo timedatectl set-timezone "$TIMEZONE"

# ── 3. Swap (a small/free-tier VM without swap OOM-kills under any real
# load spike — this exact class of problem stalled this project's own
# dev machine repeatedly, see PRODUCTION_HARDENING_REPORT.md) ──────────
log "Swap: ${SWAP_SIZE_GB}GB"
if [ ! -f /swapfile ]; then
  sudo fallocate -l "${SWAP_SIZE_GB}G" /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  # Prefer RAM over swap (swappiness=10) — swap is for absorbing spikes,
  # not for routine operation, which would be far slower than staying in RAM.
  echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
else
  echo "  /swapfile мурунтан эле бар — өткөрүлдү"
fi

# ── 4. Dedicated deploy user (not root) ──────────────────────────────
log "Deploy колдонуучусу: $DEPLOY_USER"
if ! id "$DEPLOY_USER" &>/dev/null; then
  sudo adduser --disabled-password --gecos "" "$DEPLOY_USER"
  sudo usermod -aG sudo "$DEPLOY_USER"
  echo "  '$DEPLOY_USER' түзүлдү. SSH ачкычын кол менен кошуңуз:"
  echo "  sudo mkdir -p /home/$DEPLOY_USER/.ssh && sudo cp ~/.ssh/authorized_keys /home/$DEPLOY_USER/.ssh/ && sudo chown -R $DEPLOY_USER:$DEPLOY_USER /home/$DEPLOY_USER/.ssh"
else
  echo "  '$DEPLOY_USER' мурунтан эле бар"
fi

# ── 5. SSH hardening ──────────────────────────────────────────────────
log "SSH катуулатуу (пароль менен кирүү өчүрүлөт — ачкыч гана)"
SSHD_CONFIG=/etc/ssh/sshd_config.d/99-hardening.conf
sudo tee "$SSHD_CONFIG" > /dev/null <<'EOF'
PasswordAuthentication no
PermitRootLogin no
X11Forwarding no
MaxAuthTries 3
EOF
echo "  !!! SSH ачкычыңызды ($DEPLOY_USER) текшергенге чейин учурдагы сессияны жаппаңыз !!!"
sudo systemctl reload ssh

# ── 6. UFW firewall ───────────────────────────────────────────────────
log "UFW firewall"
sudo apt-get install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
# 3000 (Grafana) / 9090 (Prometheus) сыртка ачылбайт — docker-compose.prod.yml
# аларды 127.0.0.1'ге гана байлайт, эске тартуу гана.
sudo ufw --force enable
sudo ufw status verbose

# ── 7. Fail2Ban ───────────────────────────────────────────────────────
log "Fail2Ban"
sudo apt-get install -y fail2ban
sudo tee /etc/fail2ban/jail.d/sshd.local > /dev/null <<'EOF'
[sshd]
enabled = true
maxretry = 5
bantime = 3600
findtime = 600
EOF
sudo systemctl enable --now fail2ban

# ── 8. Docker + Docker Compose plugin ────────────────────────────────
log "Docker"
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  sudo usermod -aG docker "$DEPLOY_USER"
  echo "  Docker орнотулду. Топко кошулуу үчүн кайра кириңиз (logout/login)."
else
  echo "  Docker мурунтан эле бар: $(docker --version)"
fi
sudo systemctl enable --now docker

# ── 9. Git ─────────────────────────────────────────────────────────────
log "Git"
sudo apt-get install -y git

# ── 10. Node.js 20 LTS (Docker Compose иштетсе да, миграция скрипттерин
# кол менен иштетүү/debug үчүн хостто да керек болушу мүмкүн) ────────
log "Node.js 20"
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
else
  echo "  Node мурунтан эле бар: $(node --version)"
fi

# ── 11. PM2 (Docker колдонбогон, түз VM'де иштетүү опциясы үчүн) ─────
log "PM2"
sudo npm install -g pm2

# ── 12. nginx (хост деңгээлинде эмес — docker-compose.prod.yml'дин
# өзүнүн nginx контейнери бар; бул орнотуу ЖАЛГЫЗ Docker'ди колдонбой,
# PM2 менен түз VM'де иштетким келгендерге гана керек) ────────────────
log "nginx (host-level, optional)"
sudo apt-get install -y nginx
sudo systemctl enable nginx

# ── 13. Certbot (host-level, PM2 жолу үчүн — Docker жолунда
# docker-compose.prod.yml'дин certbot сервиси бул ролду ойнойт) ──────
log "Certbot (host-level, optional)"
sudo apt-get install -y certbot python3-certbot-nginx

# ── 14. Logrotate — Docker логдору көлөмдүү болуп, дискти толтуруп
# кетпеши үчүн (бул долбоордун өз тажрыйбасында толгон диск бир жолу
# бүт системаны туруктуу кылган — PRODUCTION_HARDENING_REPORT.md) ────
log "Logrotate (Docker JSON логдору үчүн)"
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "20m", "max-file": "5" }
}
EOF
sudo systemctl restart docker

# ── Жыйынтык ──────────────────────────────────────────────────────────
log "Даяр"
echo "Текшериңиз:"
echo "  docker --version && docker compose version"
echo "  node --version"
echo "  sudo ufw status"
echo "  sudo systemctl status fail2ban"
echo ""
echo "Кийинки кадам: scripts/deploy.sh (репозиторийди clone кылат жана иштетет)"
