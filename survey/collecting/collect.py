import requests
import time
import math
import json

REST_MAX_RESULTS_PER_PAGE = 100


def handle_rate_limit(access_token):
    rate_limit_url = "https://api.github.com/rate_limit"

    headers = {
        "Authorization": f"token {access_token}",
    }

    response = requests.get(rate_limit_url, headers=headers)
    if response.status_code == 200:
        rate_data = response.json()
        remaining = rate_data["resources"]["core"]["remaining"]
        reset_time = rate_data["resources"]["core"]["reset"]

    if response.status_code == 200:
        rate_data = response.json()
        remaining = rate_data["resources"]["core"]["remaining"]
        reset_time = rate_data["resources"]["core"]["reset"]
        print(f"Rate limit: {remaining} remaining, resets at {reset_time}")

        if remaining == 0:
            current_time = time.time()
            wait_seconds = reset_time - current_time
            print(f"Rate limit exceeded. Waiting for {wait_seconds} seconds.")
            time.sleep(wait_seconds + 10)
        else:
            print(f"Rate limit: {remaining} remaining, resets at {reset_time}")
            print("Waiting for 10 seconds")
            time.sleep(10)
    else:
        print(f"Error checking rate limit: {response.status_code}")
        print("Waiting for 5 minutes")
        time.sleep(300)


def fetch_gracefully(access_token, url, headers=None, params=None):
    tries = 0
    MAX_TRIES = 20
    print(f"Fetching {url}")
    while tries < MAX_TRIES:
        print(f"Try {tries}/{MAX_TRIES}")
        response = requests.get(url, headers=headers, params=params)
        if response.status_code == 200:
            return response.json()
        elif response.status_code == 403:
            handle_rate_limit(access_token)
        else:
            print(f"Error fetching: {response.status_code}")
            print(response.text)

        tries += 1
        time.sleep(1)

    print(f"Fetching failed")
    exit(1)


def fetch_pull_requests_page(access_token, repo_owner, repo_name, page):
    url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/pulls"

    headers = {
        "Authorization": f"token {access_token}",
    }

    params = {
        "state": "all",
        "sort": "created-asc",
        "per_page": REST_MAX_RESULTS_PER_PAGE,
        "page": page,
    }

    pull_requests = fetch_gracefully(access_token, url, headers=headers, params=params)
    return pull_requests


def fetch_files(access_token, pull_request):
    url = pull_request["url"] + "/files"

    headers = {
        "Authorization": f"token {access_token}",
    }

    print(f"Fetching files for PR {pull_request['number']}")

    files = fetch_gracefully(access_token, url, headers=headers)
    return files


def fetch_commits(access_token, pull_request):
    url = pull_request["url"] + "/commits"

    headers = {
        "Authorization": f"token {access_token}",
    }

    params = {
        "per_page": REST_MAX_RESULTS_PER_PAGE,
    }

    print(f"Fetching commits for PR {pull_request['number']}")

    commits = fetch_gracefully(access_token, url, headers=headers, params=params)
    return commits


def fetch_interesting_pull_requests(
    access_token, repo_owner, repo_name, source_directories, num_requests=100
):
    print(f"Fetching {num_requests} pull requests for {repo_owner}/{repo_name}")
    pull_requests = []
    keywords = ["fix"]
    page = 1
    interesting = 0
    directories_tuple = tuple(source_directories)
    while interesting < num_requests:
        print("Checking rate limit")
        handle_rate_limit(access_token)
        page_pull_requests = fetch_pull_requests_page(
            access_token, repo_owner, repo_name, page
        )
        for pr in page_pull_requests:
            text = (
                str(pr.get("title", "") or "") + str(pr.get("body", "") or "")
            ).lower()
            contains_keyword = any(keyword in text for keyword in keywords)
            pr["encarsia"] = {"contains_keyword": contains_keyword}
            if contains_keyword:
                print(f"PR passed keyword check: {pr['number']}")
                interesting += 1
                files = fetch_files(access_token, pr)
                pr["files"] = files
                modifies_design = False
                for file in files:
                    path = file["filename"]
                    if path.startswith(directories_tuple):
                        modifies_design = True
                        break
                pr["encarsia"]["modifies_design"] = modifies_design
                if modifies_design:
                    print(f"PR modifies design: {pr['number']}")

                commits = fetch_commits(access_token, pr)
                pr["commits"] = commits

            pull_requests.append(pr)
            if interesting >= num_requests:
                break

        print(f"Page {page}: {interesting}/{num_requests} pull requests")

        page += 1
    return pull_requests


if __name__ == "__main__":
    with open("token", "r") as file:
        token = file.read()

    with open("sources.json", "r") as file:
        sources = json.load(file)

    data = {}
    for source in sources:
        repo_owner = source["repo_owner"]
        repo_name = source["repo_name"]
        source_directories = source["source_directories"]
        pull_requests = fetch_interesting_pull_requests(
            token, repo_owner, repo_name, source_directories, 100
        )
        data[repo_name] = pull_requests

    with open("data.json", "w") as file:
        json.dump(data, file, indent=2)
