#!/bin/bash

# Downgrade: Downgrade to CE https://docs.gitlab.com/ee/downgrade_ee_to_ce/
gitlab-rails runner "Service.where(type: ['JenkinsService', 'JenkinsDeprecatedService']).delete_all"
# https://about.gitlab.com/installation/?version=ce#ubuntu
curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash

while [[ $(ps aux | grep "[a]pt") != '' ]]; do
  sleep 2
done

export EXTERNAL_URL="${fqdn}"
apt-get update && \
    apt-get install awscli \
    gitlab-ce=${gitlab_version}-ce.0 -y

if [[ ${restore_enabled} == "true" ]]; then
  # Retrieve latest /etc/ssh
  etcssh=$$(aws s3api list-objects --bucket ${s3_bucket} --prefix ${fqdn}/etc-ssh --query 'reverse(sort_by(Contents,&LastModified))[0].Key' --output text)

  aws s3api get-object --bucket ${s3_bucket} --key $${etcssh} $${etcssh/${fqdn}\//}
  tar -xf $${etcssh/${fqdn}\//}

  # Retrieve latest /etc/gitlab
  etcgitlab=$$(aws s3api list-objects --bucket ${s3_bucket} --prefix ${fqdn}/etc-gitlab --query 'reverse(sort_by(Contents,&LastModified))[0].Key' --output text)

  aws s3api get-object --bucket ${s3_bucket} --key $${etcgitlab} $${etcgitlab/${fqdn}\//}
  tar -xf $${etcgitlab/${fqdn}\//}

  # Retrieve latest backup
  backup=$$(aws s3api list-objects --bucket ${s3_bucket} --query 'reverse(sort_by(Contents,&LastModified))[0].Key' --output text)

  aws s3api get-object --bucket ${s3_bucket} --key $${backup} /var/opt/gitlab/backups/$${backup}

  gitlab-ctl stop unicorn
  gitlab-ctl stop sidekiq

  gitlab-rake gitlab:backup:restore force=yes
  cp -R etc/gitlab /etc/
  cp -R etc/ssh /etc/

  gitlab-ctl restart
  gitlab-rake gitlab:check SANITIZE=true
  gitlab-ctl reconfigure
fi

if [[ ${backup_enabled} == "true" ]]; then
  cat <<- EOF > /etc/systemd/system/backup_gitlab.service
[Unit]
Description=Backup Gitlab
[Service]
Type=simple
User=root
ExecStart=/usr/bin/gitlab-rake --trace gitlab:backup:create SKIP=artifacts,registry
ExecStartPost=/opt/gitlab_ce_backup/gitlab_configuration_backup.sh
EOF

  cat <<- EOF > /etc/systemd/system/backup_gitlab.timer
[Unit]
Description=Backup Gitlab

[Timer]
Unit=backup_gitlab.service
OnUnitActiveSec=1d
OnBootSec=10min

[Install]
WantedBy=timers.target
EOF

  mkdir -p /opt/gitlab_ce_backup /var/opt/gitlab/backups/configuration

  #
  # todo: confirm "EOF" fixes expansion issue below
  #
  cat <<- "EOF" > /opt/gitlab_ce_backup/gitlab_configuration_backup.sh
#!/bin/bash
gitlab_tag=$$(date "+etc-gitlab-%s.tar")
ssh_tag=$$(date "+etc-ssh-%s.tar")
umask 0077; tar -cf /var/opt/gitlab/backups/configuration/$${gitlab_tag} -C / etc/gitlab
umask 0077; tar -cf /var/opt/gitlab/backups/configuration/$${ssh_tag} -C / etc/ssh
aws s3 sync --quiet --region ${region} --storage-class STANDARD_IA /var/opt/gitlab/backups/configuration/ s3://${s3_bucket}/${fqdn}
find /var/opt/gitlab/backups/configuration/* -type f -delete
EOF


  chmod +x /opt/gitlab_ce_backup/gitlab_configuration_backup.sh

  systemctl daemon-reload
fi
