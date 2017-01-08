#!/bin/sh -eux
# this script runs in /bin/sh by default
# respawn as bash so we can source in rbenv
exec /bin/bash <<'EOT'
# Pick your poison :) Or none if you're using a system wide installed Ruby.
# rbenv
# source /home/apps/.bash_profile
# OR
# source /home/apps/.profile
# OR system:
# source /etc/profile.d/rbenv.sh
#
# rvm
# source /home/apps/.rvm/scripts/rvm

# Logs out to /var/log/upstart/sidekiq.log by default

source /home/{{deploy_user}}/.bashrc
source /etc/environment
cd /opt/{{plum_directory}}/current
export RAILS_ENV={{plum_environment}}
exec bundle exec sidekiq -c 5 -e production -q high ingest default lowest | join(" -q ") -i ${index}
EOT
