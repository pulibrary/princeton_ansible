Bibdata
===========

This role installs all of the necessary components to run a rails server for marc_liberation.

Can we use postgres? It'd be nice to use the cluster. Or use maria_db_cluster.

How are config files managed?
config.email_regexp

create directory /opt/marc_liberation/shared/config/ip_whitelist.yml
(rails_app role creates /opt/rails_app/shared)
move secret.yml to env variable (update capistrano config file appropriately)

Oracle instant client and sdk
(required login to oracle and download from website)

/data shared across servers?

improve resque...

Role Componenents
--------------
 - role: pulibrary.ruby
 - role: pulibrary.deploy-user
 - role: pulibrary.passenger
 - role: pulibrary.redis
 - role: pulibrary.nodejs
 - role: pulibrary.rails-app
