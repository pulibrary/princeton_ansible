# Princeton Ansible Playbooks

A collection of roles and playbooks for provisioning and managing the machines that run PUL applications.

# Project Setup for Development and Testing

## First-time setup

Do these things once, after you clone this repo.

### Mac

1. Install Homebrew
2. Install [Docker Desktop](https://docs.docker.com/desktop/install/mac-install/)
3. Run `bin/first-time-setup.sh` – this installs all the language and tooling dependencies
4. Ensure [`uv`](https://github.com/pypa/uv) is installed (`pipx install uv` or your preferred installer)
5. Run `bin/setup` – this adds a [pre-commit hook](.githooks/pre-commit) to your environment that prevents checking in unencrypted vault files
6. Follow the steps under "Every time setup"

### Windows / Ubuntu (WSL)

1. See the [WSL Document](./README_Windows.md)

## Every time setup

Run these commands every time you use this repo:

```bash
uv sync      # install dependencies into .venv
uv shell     # spawn a shell inside the .venv
source princeton_ansible_env.sh
lpass login <your-netid@princeton.edu>
```

Now you can run tests (see "Running molecule tests") or playbooks (see "Usage").

## Validate that everything is installed correctly

With Docker running and inside your `uv shell`, run:

```bash
cd roles/common
pip install 'molecule-plugins[docker]'
molecule test
```

# Developing

## Create a new role

Replace `your_new_role` with your role name:

1. Initialize the role via Ansible Galaxy:

   ```bash
   export your_new_role=<role_name>
   cd roles/$your_new_role
   molecule init scenario
   cd ../..
   ```

2. Add your role to the GitHub Actions matrix in `.github/workflows/molecule_tests.yml`.
3. Copy example files and update metadata:

   ```bash
   cp -r roles/example/* $your_new_role
   vi roles/$your_new_role/meta/main.yml   # add a description
   vi roles/$your_new_role/molecule/default/converge.yml  # update name
   ```

4. Test your role:

   ```bash
   cd roles/$your_new_role
   molecule test
   ```

5. Push your branch and verify CI passes.
6. If the role supports a new project, add group\_vars and inventory entries as documented.

# Running Molecule tests

You can run `molecule test` from the repository root or role folder. For faster iteration, use:

```bash
molecule lint
molecule converge
molecule verify
```

To inspect a running container:

```bash
molecule login
```

# Usage

## Running a playbook

```bash
ansible-playbook playbooks/example.yml
```

To resume at a specific task:

```bash
ansible-playbook playbooks/example.yml --start-at-task="Task Name"
```

## Avoiding downtime

To ensure uptime while provisioning a set of machines, the general process is to remove half the machines from the load balancer, provision and deploy them, then put them back on the load balancer and remove the other half for provisioning and deployment.

2 ways to remove machines from the load balancer:

- Use the capistrano tasks, duplicated to every rails application, called `remove_from_nginx` and `serve_from_nginx` to remove and replace sets of machines.
- [Use the load balancer UI](https://github.com/pulibrary/pul-it-handbook/blob/main/services/nginxplus.md#using-the-admin-ui) to control which boxes are being served.

To run a playbook on only a subset of hosts, use the `--limit` option to `ansible-playbook`, e.g.:

```
ansible-playbook playbooks/figgy_production.yml --limit figgy3.princeton.edu
```

You can also add `--list-hosts` just to check which hosts will be affected before you run.

Make sure to deploy the application to each set of boxes after they are provisioned, to ensure the local webserver is restarted after the environment changes.

To check the newly-provisioned boxes before swapping to the other group, SSH to the box that's off the load balancer and check that the index page still looks okay
`$ curl localhost:80`

Note that some playbooks have separate sections for webservers and workers. Make sure that all the boxes get provisioned.

# Connections to other boxes

Currently there's no automation on firewall changes when the box you're provisioning needs to talk to the postgres or solr machines. See instructions for manual edits at:

- <https://github.com/pulibrary/pul-the-hard-way/blob/master/services/postgresql.md#allow-access-from-a-new-box>
- <https://github.com/pulibrary/pul-the-hard-way/blob/master/services/solr.md#allow-access-from-a-new-box>

# Vault

Use `ansible-vault edit` to update secrets (e.g., `group_vars/bibdata/vault.yml`).

# Upgrading Ansible version

1. Enter your project env:

   ```bash
   uv sync
   uv shell
   ```

2. Bump the `ansible` version in `pyproject.toml` under `[project.dependencies]`.
3. Re-lock and sync:

   ```bash
   uv lock
   uv sync
   ```

# Patching Dependencies (Dependabot)

When Dependabot opens a PR, update your `pyproject.toml` as needed, then:

```bash
uv lock
uv sync
molecule test
```
