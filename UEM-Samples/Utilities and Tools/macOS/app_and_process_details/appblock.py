#!/usr/bin/python3
#
# Helper tool to find required data for Workspace ONE UEM App Blocking functionality for macOS
#
# Original Created by Adam Matthews - adam@adammatthews.co.uk // matthewsa@vmware.com
# Date: 6th July 2021
# CodeRequirement Additions by Ciara Spencer - github.com/cspence001
# Date: 13th September 2024

import subprocess, sys, getopt, re, argparse, os

parser = argparse.ArgumentParser()
parser.add_argument('--apps', help='Application Path')
parser.add_argument('--list', help='List applications', action='store_true')

args = parser.parse_args()

if args.apps:
    app = args.apps
    cmd = ["/usr/bin/codesign", "-dv", "--verbose=4", app]
    returned_value = subprocess.run(cmd, capture_output=True)  # returns the exit code in unix

    out = returned_value.stderr

    cdhash = ""
    teamid = ""
    sha256 = ""
    name = ""
    bundleid = ""
    path = ""
    codereq = ""

    # Get CDHash
    for line in out.splitlines():
        if line.startswith(b'CDHash'):
            m = re.search(r'(?<=\=).*', line.decode('utf-8').strip())
            if m:
                cdhash = m.group(0)

    # Get TeamIdentifier
    for line in out.splitlines():
        if line.startswith(b'TeamIdentifier'):
            m = re.search(r'(?<=\=).*', line.decode('utf-8').strip())
            if m:
                teamid = m.group(0)

    # Get CodeRequirement
    cmd_code_req = ["/usr/bin/codesign", "--display", "-r-", app]
    returned_code_req = subprocess.run(cmd_code_req, capture_output=True)
    code_req_out = returned_code_req.stdout.decode('utf-8')

    for line in code_req_out.splitlines():
        if line.startswith('designated'):
            codereq = line.replace('designated => ', '').strip()

    # Get Sha-256 Hash
    list_files = subprocess.run(["ls", f"{app}/Contents/MacOS"], capture_output=True)
    sha_contents = str(list_files.stdout, 'utf-8').strip()
    name = sha_contents
    sha = ["/usr/bin/openssl", "dgst", "-sha256", f"{app}/Contents/MacOS/{sha_contents}"]
    sha_value = subprocess.run(sha, capture_output=True)  # returns the exit code in unix
    sha_out = sha_value.stdout
    m = re.search(r'(?<=\=).*', sha_out.decode('utf-8').strip())
    if m:
        sha256 = m.group(0)

    # Get Bundle ID
    bundle_plist = subprocess.run(["osascript", "-e", f'id of app "{sha_contents}"'], capture_output=True)
    bundleid = str(bundle_plist.stdout, 'utf-8').strip()

    print(f"Name: {name}")
    print(f"File Path: {app}/Contents/MacOS")
    print(f"CD Hash: {cdhash}")
    print(f"Team ID: {teamid}")
    print(f"SHA-256: {sha256}")
    print(f"Bundle ID: {bundleid}")
    print(f"Code Requirement: {codereq}")

if args.list:
    list_apps = subprocess.run(["ls"], capture_output=True, cwd="/Applications/")
    apps_list = list_apps.stdout

    list_system_apps = subprocess.run(["ls"], capture_output=True, cwd="/System/Applications/")
    system_apps_list = list_system_apps.stdout

    list_utility_apps = subprocess.run(["ls"], capture_output=True, cwd="/System/Applications/Utilities")
    utility_apps_list = list_utility_apps.stdout

    for line in apps_list.splitlines():
        print(f"/Applications/{line.decode('utf-8')}")
    for line in system_apps_list.splitlines():
        print(f"/System/Applications/{line.decode('utf-8')}")
    for line in utility_apps_list.splitlines():
        print(f"/System/Applications/Utilities/{line.decode('utf-8')}")
