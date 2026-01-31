# Example Role

This role is a placeholder for creation of molecule roles

1. From your new role create a molecule directory

  ```bash
  cd roles/<your_role_name>
  mkdir -p molecule/default
  ```

1. Copy the files from the example role from the root of the repo:

  ```bash
  cp -a roles/example/* roles/your_role_name
  ```

1. Edit the following files:
   * `molecule/default/converge.yml`

    ```yaml
    roles:
      - role: <your_role_name>
    ```

   * `meta/main.yml`

    ```yaml
    role_name: <your_role_name>
    ...
    description: <Description of your role>
    ...
    dependencies: []
    ### or if your role depends on another
      - role: other_role
    ```

2. Run:

    ```bash
    cd roles/<your_role_name>
    molecule converge
    molecule verify
    ```

## Architecture/platform notes (Apple Silicon vs GHA CI)

We use a multi-arch Docker image:

  * ghcr.io/pulibrary/vm-builds/ubuntu-22.04

  * It has linux/amd64 and linux/arm64 manifests.

  * GitHub Actions runners are amd64.

  * Local Macs (M1/M2/M3) are arm64.

Molecule’s Docker driver honors the MOLECULE_DOCKER_PLATFORM environment variable:

  * If not set, Docker chooses a platform based on the host.

  * If set, Molecule passes it to Docker as the platform= option.

### Important: `.env.yml` vs GitHub Actions `env`:

Molecule will load environment variables from `.env.yml` (or whatever `MOLECULE_ENV_FILE` points to) **inside the runner/container.**

That means:

  * If you commit:

    ```yaml
    # roles/<role>/.env.yml
      ---
      MOLECULE_DOCKER_PLATFORM: linux/arm64
      ```


  * And in GitHub Actions you also set:

      ```yaml
      env:
        MOLECULE_DOCKER_PLATFORM: linux/amd64
      ```


Then the value from `.env.yml` wins inside Molecule, and CI will still use `linux/arm64`.

#### Rule of thumb:

Let CI control the platform, so **do not commit** `MOLECULE_DOCKER_PLATFORM` in `.env.yml.`

### Recommended patterns

Local Apple Silicon (M1/M2/M3)

Use:

Export the variable when you run Molecule:

Use a local, untracked env file:

  * Depend on the global .gitignore (at repo root):

  * Create `roles/<your_role_name>/.env.local.yml`:

    ```yaml
    ---
    MOLECULE_DOCKER_PLATFORM: linux/arm64
    ```


  * Run Molecule with:

    ```bash
    cd roles/<your_role_name>
    MOLECULE_ENV_FILE=.env.local.yml molecule test
    ```

#### GitHub Actions (CI)

  * The workflow sets MOLECULE_DOCKER_PLATFORM=linux/amd64 (or relies on the default amd64 runner).
