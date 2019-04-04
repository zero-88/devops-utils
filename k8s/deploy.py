#!/usr/bin/python
"""
Kubernetes deployment script
"""

import argparse
import fileinput
import logging
import os
import re
import subprocess
from subprocess import CompletedProcess
import tempfile
from pathlib import Path

from dotenv import dotenv_values, load_dotenv

parser = argparse.ArgumentParser()
parser.add_argument("-e", "--env", action="store", default="dev", choices=["dev", "test", "stag", "prod"], help="Environment")
parser.add_argument("-m", "--mode", action="store", default="local", choices=["local", "gcp"], help="Cluster mode")
parser.add_argument("-n", "--namespace", action="store", type=str, help="K8s Namespace. Override declared variable in .env")
parser.add_argument("-d", "--dir", action="store", default="./", type=str, help="Working directory")
parser.add_argument("-p", "--prefix", action="store", default="", type=str, help="Prefix file name")
parser.add_argument("--fix-permission", dest="fix_permission", default=False, action="store_true", help="Fix cloud permission")
parser.add_argument("-v", "--verbose", action="store_true", help="Verbose log")
args = parser.parse_args()
logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO, handlers=[logging.StreamHandler()],
                    format="%(asctime)s %(levelname)-5s %(name)s %(message)s")
logger = logging.getLogger("k8s_deploy")

TEMPLATE_VAR = "{{%s}}"


def __subtitle_var(f_yaml: str, envs: dict) -> str:
    content = ""
    with fileinput.FileInput(f_yaml) as f:
        for line in f:
            new_line = line
            for key, val in envs.items():
                new_line = new_line.replace(TEMPLATE_VAR % key, val or "\"\"")
            content += new_line
    return content


def __execute_command(command: str):
    logger.debug("\tExecute: %s", command)
    list_cmd = command.split(" | ")
    length = len(list_cmd)
    prev = None
    for idx, cmd in enumerate(list_cmd, 1):
        logger.debug("\tsub_command::input %s::%s", cmd, prev)
        complete = subprocess.run(cmd.split(), input=prev, env=os.environ, encoding='utf-8', stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            prev = __handle_command_result(complete)
        finally:
            level = logging.ERROR if complete.returncode != 0 else logging.INFO if idx == length else logging.DEBUG
            logger.log(level, "\tReturn code: %s", complete.returncode)
    return prev


def __handle_command_result(complete: CompletedProcess):
    stdout = complete.stdout
    stderr = complete.stderr
    if complete.returncode == 0:
        logger.debug("\t%s", stdout.strip())
        return stdout.strip()
    logger.info("+" * 25)
    logger.info("\tcommand:\n%s", complete.args)
    logger.info("-" * 25)
    logger.info("\tstdout:\n%s", stdout)
    logger.info("-" * 25)
    logger.error("\tstderr:\n%s", stderr)
    logger.info("+" * 25)
    raise RuntimeError("Failed when executing command")


def __k8s_apply(namespace="") -> str:
    return "kubectl %s apply -f -" % ("-n %s" % namespace if namespace else "")


def __execute_yaml(f_yaml: str, namespace: str, envs: dict):
    logger.info("  - YAML: %s", f_yaml)
    content = __subtitle_var(f_yaml, envs)
    logger.debug(content)
    logger.debug("-" * 50)
    with tempfile.NamedTemporaryFile() as tmpfile:
        with open(tmpfile.name, "w", encoding="utf-8") as fd:
            fd.write(content)
        __execute_command("cat -- %s" % tmpfile.name + " | " + __k8s_apply(namespace))


def __execute_py(f_py: str, namespace: str, envs: dict):
    logger.info("  - PYTHON: %s", f_py)
    raise NotImplementedError("Not yet implemented")


def __execute(f: str, namespace: str, envs: dict):
    if f.endswith(".yaml"):
        __execute_yaml(f, namespace, envs)
    if f.endswith(".py"):
        __execute_py(f, namespace, envs)
    if f.endswith(".sh"):
        logger.info("  - BASH: %s", f)
        __execute_command("bash " + f)
    logger.info("-" * 25)


def __check(workdir: str, file_name: str, prefix: str) -> bool:
    logger.debug("%s::%s", workdir, file_name)
    if prefix and not file_name.startswith(prefix):
        return False
    return Path(workdir, file_name).is_file() and re.match(r"^\d{2}_.+\.(yaml|sh|py)$", file_name)


def run(workdir: str, mode: str, namespace: str, prefix: str, envs: dict):
    files = sorted([file_name for file_name in os.listdir(workdir) if __check(workdir, file_name, prefix)])
    logger.info("- Scan files...")
    logger.debug(files)
    for file_name in files:
        if re.match(r"^0\d_.+", file_name):
            if mode != "local":
                __execute(str(Path(workdir, file_name)), None, envs)
            continue
        __execute(str(Path(workdir, file_name)), namespace, envs)


def load_env(arguments):
    env_path = Path(arguments.dir, ".env")
    logger.debug("Default env path: %s", env_path)
    load_dotenv(env_path)
    envs = dotenv_values(dotenv_path=env_path)
    custom_env_path = Path(arguments.dir, "./.%s.env" % arguments.env)
    logger.debug("Custom env path: %s", env_path)
    if custom_env_path.exists() and custom_env_path.is_file():
        load_dotenv(dotenv_path=custom_env_path, override=True)
        envs.update(dotenv_values(dotenv_path=custom_env_path))
    if arguments.namespace:
        envs["NAMESPACE"] = arguments.namespace
        os.environ["NAMESPACE"] = arguments.namespace
    if not envs.get("NAMESPACE", None):
        envs["NAMESPACE"] = "default"
        os.environ["NAMESPACE"] = "default"
    envs["WORK_DIR"] = arguments.dir
    os.environ["WORK_DIR"] = arguments.dir
    return envs


def print_context(arguments, envs):
    logger.debug("=" * 50)
    logger.debug("Parameters:")
    logger.debug("-" * 25)
    for k, val in vars(arguments).items():
        logger.debug('%s=%s', k, val)
    logger.debug("=" * 50)
    logger.info("=" * 50)
    logger.info("Context:")
    logger.info("-" * 25)
    for k, val in envs.items():
        logger.info('%s=%s', k, val)
    logger.info("=" * 50)


def fix_cloud_permission(is_fixed: bool, mode: str, envs: dict):
    if not is_fixed:
        return
    if mode == "gcp":
        logger.info("- Fix Google Cloud permission")
        if not envs.get("GCP_USER", None):
            logger.info("  - Get Google account")
            account = __execute_command("gcloud config get-value account")
            envs["GCP_USER"] = account
        acc_name = envs.get("GCP_USER").split("@")[0]
        __execute_command("kubectl create clusterrolebinding %s-crb --clusterrole cluster-admin --user %s --dry-run --output=yaml | %s" %
                          (acc_name, envs.get("GCP_USER"), __k8s_apply()))
    logger.info("-" * 25)


def create_k8s_namespace(namespace):
    logger.info("- Create Kubernetes namespace")
    __execute_command("kubectl create namespace %s --dry-run --output=yaml | %s" % (namespace, __k8s_apply()))
    logger.info("-" * 25)


ENVS = load_env(args)
print_context(args, ENVS)
fix_cloud_permission(args.fix_permission, args.mode, ENVS)
create_k8s_namespace(ENVS.get("NAMESPACE"))
run(args.dir, args.mode, ENVS.get("NAMESPACE"), args.prefix, ENVS)
