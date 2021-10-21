Role Name
=========

A machine to hold legacy static web content.

Requirements
------------

Any pre-requisites that may not be covered by Ansible itself or the role should
be mentioned here. For instance, if the role uses the EC2 module, it may be a
good idea to mention in this section that the boto package is required.

Role Variables
--------------

libstatic role deploys a list of repos from github to the libstatic server.  To configure a new site you will need to add a item to the sites list like the following:
```
   sites:
   - doc_root: "/var/local/<your repo>"
      git_repo: 'git@github.com:pulibrary/<your repo>.git'
      options: 'Indexes FollowSymLinks MultiViews'
      version: 'main'
      alias: '<your repo>'
```
`doc_root` is where the code gets deployed to.
`git_repo` is the ssh clone url of the repo
`options` are Apache options for the site
`version` is the branch to deploy
`alias` the url path to your repo from the top level server

You may need to generate a deploy key for this role to deploy your private repo. Run the following commands to generate the key
```
export repo_name=<your repo>
ssh-keygen -t ed25519 -C deploy@princeton.edu -f $repo_name  -P ""
ansible-vault encrypt $repo_name
mv $repo_name* roles/libstatic/templates/ 
```

cat the public key and it as a deploy key in your repo in github (/settings/keys)

Your site will look like.  Note the ssh_opts:
```
   sites:
   ...
   - doc_root: "/var/local/<your repo>"
      git_repo: 'git@github.com:PrincetonUniversityLibrary/<your repo>.git'
      options: 'Indexes FollowSymLinks MultiViews'
      version: 'main'
      alias: '<your repo>'
      ssh_opts: -i /home/deploy/.ssh/<your repo>_ed25519 -o StrictHostKeyChecking=no
```

You will also need to put the key into the deploy key list
```
deploy_keys:
    ...
    - <your repo>_ed25519
```

Dependencies
------------

A list of other roles hosted on Galaxy should go here, plus any details in
regards to parameters that may need to be set for other roles, or variables that
are used from other roles.

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/libstatic, x: 42 }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
