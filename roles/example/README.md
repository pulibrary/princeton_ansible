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
