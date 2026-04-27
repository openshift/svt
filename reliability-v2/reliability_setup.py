#!/usr/bin/env python3

import os
import subprocess
import argparse
from pathlib import Path
import getpass
import sys
import time
import re
import json


def redact_secrets(text):
    """Redact sensitive information from text."""
    text = re.sub(r"PODMAN_PASSWORD='[^']*'", "PODMAN_PASSWORD='****'", text)
    text = re.sub(r"(sha256~)[A-Za-z0-9_-]+", r"\1****", text)
    return text


def run_command(cmd, remote=False, ssh_prefix="", capture_output=False):
    if remote:
        full_cmd = f"{ssh_prefix} \"{cmd}\""
    else:
        full_cmd = cmd

    if capture_output:
        result = subprocess.run(
            full_cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        if result.returncode != 0:
            print(f"[ERROR] Command failed: {redact_secrets(full_cmd)}")
            print(redact_secrets(result.stderr))
            sys.exit(1)
        return result.stdout.strip()
    else:
        result = subprocess.run(full_cmd, shell=True)
        if result.returncode != 0:
            print(f"[ERROR] Command failed: {redact_secrets(full_cmd)}")
            sys.exit(1)


def validate_local_path(path, desc):
    if not Path(path).exists():
        print(f"[ERROR] {desc} does not exist at: {path}")
        exit(1)


def detect_topology(ssh_prefix):
    """Detect cluster topology by examining node roles via oc."""
    print("[INFO] Detecting cluster topology...")
    nodes_json = run_command(
        "oc get nodes -o json",
        remote=True, ssh_prefix=ssh_prefix, capture_output=True
    )
    nodes = json.loads(nodes_json)

    master_count = 0
    worker_count = 0
    arbiter_count = 0
    total = len(nodes.get("items", []))

    for node in nodes.get("items", []):
        labels = node.get("metadata", {}).get("labels", {})
        roles = [k.split("/")[1] for k in labels if k.startswith("node-role.kubernetes.io/")]

        if "master" in roles or "control-plane" in roles:
            master_count += 1
        if "worker" in roles and "master" not in roles and "control-plane" not in roles:
            worker_count += 1
        if "arbiter" in roles:
            arbiter_count += 1

    if master_count == 1:
        topology = "sno"
    elif master_count == 2:
        topology = "tna" if arbiter_count > 0 else "tnf"
    else:
        topology = "standard"

    print(f"[INFO] Detected {topology.upper()} cluster: "
          f"{master_count} masters, {worker_count} workers, "
          f"{total} nodes total"
          + (f", {arbiter_count} arbiter" if arbiter_count > 0 else ""))

    return topology


def select_config(topology):
    """Select the appropriate reliability config based on topology."""
    if topology in ("tnf", "tna", "sno"):
        config = "reliability-small-cluster.yaml"
    else:
        config = "reliability.yaml"

    print(f"[INFO] Using config: {config} (based on {topology.upper()} topology)")
    return config


def main():
    parser = argparse.ArgumentParser(
        description="Automate Longevity Reliability Setup for OpenShift clusters (TNF, TNA, standard, SNO)"
    )
    parser.add_argument("--ec2-ip", required=True, help="EC2 instance public IP")
    parser.add_argument("--ssh-user", default="ec2-user", help="SSH username (default: ec2-user)")
    parser.add_argument("--reliability-path", required=True, help="Local path to upstream svt/reliability-v2 folder")
    parser.add_argument("--enable-lvms", choices=["yes", "no"], default="no", help="Enable LVMS deployment")
    parser.add_argument("--slack-enable", choices=["TRUE", "FALSE"], default="TRUE", help="Enable Slack reporting")
    parser.add_argument("--slack-channel", required=True, help="Slack channel ID")
    parser.add_argument("--test-duration", default="2d", help="Duration of the test (e.g. 2d, 5h)")
    parser.add_argument("--slack-member", required=True, help="Slack member ID")
    parser.add_argument("--slack-api-token", required=True, help="Slack API token")
    parser.add_argument("--registry-namespace", required=False, help="Quay.io registry namespace for LVMS image")
    parser.add_argument("--repositry-name", required=False, help="Quay.io repository name inside the namespace")
    parser.add_argument("--podman-username", required=False, help="Podman login username for quay.io")
    parser.add_argument("--quay-token", required=False, help="Quay.io OAuth token (can also use QUAY_TOKEN env var)")
    parser.add_argument("--create-users", choices=["yes", "no"], default="yes", help="Whether to create test users and HTPasswd provider")
    args = parser.parse_args()

    if args.quay_token:
        args.podman_password = args.quay_token
    elif os.environ.get("QUAY_TOKEN"):
        args.podman_password = os.environ.get("QUAY_TOKEN")
        print("[INFO] Using QUAY_TOKEN from environment variable")
    elif args.enable_lvms == "yes":
        args.podman_password = getpass.getpass("Enter Quay.io OAuth token: ")
    else:
        args.podman_password = ""

    ssh_prefix = f"ssh {args.ssh_user}@{args.ec2_ip}"

    validate_local_path(args.reliability_path, "reliability-v2 directory")

    # Rsync reliability-v2 to EC2
    print("[INFO] Syncing reliability-v2 to EC2...")
    rsync_cmd = f'rsync -av --progress --exclude=".git" "{args.reliability_path}/" {args.ssh_user}@{args.ec2_ip}:~/reliability-v2'
    run_command(rsync_cmd)

    # Copy kubeconfig on EC2
    print("[INFO] Copying kubeconfig from dev-scripts into reliability-v2...")
    run_command("mkdir -p ~/reliability-v2/path_to_auth_files", remote=True, ssh_prefix=ssh_prefix)
    copy_kubeconfig_cmd = (
        "cp -f ~/openshift-metal3/dev-scripts/ocp/ostest/auth/kubeconfig "
        "~/reliability-v2/path_to_auth_files/kubeconfig"
    )
    run_command(copy_kubeconfig_cmd, remote=True, ssh_prefix=ssh_prefix)

    # Run EC2 preparation script
    print("[INFO] Running preparation script on EC2...")
    prepare_script_cmd = (
        f"PODMAN_PASSWORD='{args.podman_password}' "
        f"bash ~/reliability-v2/tasks/script/ec2_prepare_env.sh "
        f"{args.enable_lvms} "
        f"{args.registry_namespace or ''} "
        f"{args.podman_username or ''} "
        f"{args.repositry_name or ''} "
        f"{args.create_users}"
    )
    run_command(prepare_script_cmd, remote=True, ssh_prefix=ssh_prefix)

    # Detect topology and select config
    topology = detect_topology(ssh_prefix)
    config_file = select_config(topology)

    # Start tmux session with test command
    tmux_cmd = f"""tmux new-session -d -s longevity_test bash -c '
        cd /home/{args.ssh_user}/reliability-v2 && \\
        export KUBECONFIG=/home/{args.ssh_user}/reliability-v2/path_to_auth_files/kubeconfig && \\
        export SLACK_ENABLE={args.slack_enable} && \\
        export SLACK_CHANNEL={args.slack_channel} && \\
        export SLACK_MEMBER={args.slack_member} && \\
        export SLACK_API_TOKEN={args.slack_api_token} && \\
        ./start.sh -p /home/{args.ssh_user}/reliability-v2/path_to_auth_files -t {args.test_duration} -u -c {config_file} 2>&1 | tee live_output.log; \\
        tail -f live_output.log
    '"""
    run_command(tmux_cmd, remote=True, ssh_prefix=ssh_prefix)

    print("[INFO] Waiting for both readiness strings in live_output.log...")

    ready = False
    for _ in range(180):
        check_cmd = "tmux capture-pane -t longevity_test -p"
        out = run_command(check_cmd, remote=True, ssh_prefix=ssh_prefix, capture_output=True)

        if (
            "Reliability test will run" in out
            and "DO NOT CTRL+c or terminate this session" in out
        ):
            ready = True
            break
        time.sleep(5)

    if not ready:
        print("[ERROR] Timed out waiting for readiness.")
        sys.exit(1)

    print(f"[SUCCESS] Test has started on {topology.upper()} cluster. tmux session detached.")

    print(f"\n Test launched successfully in tmux (config: {config_file}).")
    print("  The tmux session has automatically detached once the test reached readiness.")
    print(f"To reattach manually at any time:\n  ssh {args.ssh_user}@{args.ec2_ip}\n  tmux attach -t longevity_test")
    print("To detach manually while inside tmux: Press Ctrl + B, then D")
    print("\n Setup complete. Longevity test is running inside tmux session 'longevity_test'.")
    print("To monitor view reliability-v2/testnumber/reliability.log")


if __name__ == "__main__":
    main()
