from git import Repo
import os
import yaml

REPO = Repo("./")
GIT = REPO.git


def changed_files():
    return GIT.diff('--name-only', 'main').splitlines()


def role_name(path):
    path_parts = path.split('/')
    if path_parts[0] == 'roles':
        return path_parts[1]


def changed_roles():
    roles_map = map(role_name, changed_files())
    return list(filter(None, roles_map))


def current_branch():
    return GIT.name_rev('--name-only', 'HEAD')


def role_dependencies(role):
    path = './roles/' + role + '/meta/main.yml'
    if not os.path.exists(path):
        return []
    with open(path, 'r') as yamlfile:
        meta = yaml.safe_load(yamlfile)
        if 'dependencies' in meta and meta['dependencies']:
            return list(map(lambda x: x['role'], meta['dependencies']))


def roles_dependant_on_role(role_under_evaluation):
    roles_dir = './roles'
    all_roles = filter(lambda x: os.path.isdir(os.path.join(roles_dir, x)), os.listdir(roles_dir))
    dependant_roles = []
    for role in all_roles:
        dependencies = role_dependencies(role)
        if dependencies and role_under_evaluation in dependencies:
            dependant_roles.append(role)
    return dependant_roles


def roles_dependant_on_changed_roles():
    out_roles = []
    for role in changed_roles():
        dependant_roles = roles_dependant_on_role(role)
        if dependant_roles:
            out_roles.extend(dependant_roles)
    return out_roles


def run_test(role):
    exit_code = os.system('cd  roles/' + role + ' && molecule test')
    if not exit_code == 0:
        raise Exception('Molecule tests failed')


def evaluate(role):
    if current_branch() == 'main':
        run_test(role)
    elif role in changed_roles():
        run_test(role)
    elif role in roles_dependant_on_changed_roles():
        run_test(role)
    else:
        print('Not running tests for: ' + role)


evaluate(os.environ["ROLE"])
