Role Name
=========

The Sensu role automates the Sensu monitoring and alerting system. For now it mainly installs the sensu-go-agent on monitored machines.

Requirements
------------

None.

Role Variables
--------------

The two main variables control which parts of the role are run. Set 'install_agent' to 'true' to install the agent on a machine you want to monitor. Set 'build_backend' to 'true' to build the Sensu backend server.

Dependencies
------------

None.

Example Playbook
----------------

See playbooks/sensu_agent.yml for an example playbook.

License
-------

BSD
