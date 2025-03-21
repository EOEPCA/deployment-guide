import contextlib
import os
import subprocess
import requests

test_results = {}

def load_eoepca_state():
    # Source the eoepca state and capture the exported variables
    proc = subprocess.Popen(
        "source $HOME/.eoepca/state && env",
        stdout=subprocess.PIPE,
        shell=True,
        executable="/bin/bash",
    )
    output, _ = proc.communicate()
    # Parse the variables and update the environment
    for line in output.decode("utf-8").splitlines():
        key, _, value = line.partition("=")
        os.environ[key] = value


def get_access_token(username, password, client_id, client_secret=None):
    url = f"{os.environ['HTTP_SCHEME']}://{os.environ['KEYCLOAK_HOST']}/realms/eoepca/protocol/openid-connect/token"
    payload = {
        "username": username,
        "password": password,
        "grant_type": "password",
        "client_id": client_id,
        "scope": "openid profile email",
    }
    if client_secret:
        payload["client_secret"] = client_secret

    headers = {
        "Content-Type": "application/x-www-form-urlencoded",
    }
    response = requests.post(url, data=payload, headers=headers)
    response.raise_for_status()
    access_token = response.json()["access_token"]
    return access_token


@contextlib.contextmanager
def test_cell(name):
    try:
        yield
        test_results[name] = {'status': 'PASS', 'message': ''}
    except AssertionError as e:
        test_results[name] = {'status': 'FAIL', 'message': f"Assertion failed: {e}"}
        print(f"[{name}] Assertion failed: {e}")
    except Exception as e:
        test_results[name] = {'status': 'FAIL', 'message': str(e)}
        print(f"[{name}] Exception: {e}")