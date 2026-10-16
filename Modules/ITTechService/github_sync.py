import os
import sys
import json
import datetime
import subprocess

def run_sync():
    print("=== SENTINEL GitHub Sync Tool ===")
    
    config_file = ".github_settings.json"
    if not os.path.exists(config_file):
        print("Error: .github_settings.json not found. Please configure settings in the Toolkit UI first.")
        return

    try:
        with open(config_file, "r", encoding="utf-8") as f:
            data = json.load(f)
            token = data.get("token")
            repo_url = data.get("repo")
    except Exception as e:
        print(f"Error reading config: {e}")
        return

    if not token or not repo_url:
        print("Error: Missing token or repo URL in config.")
        return

    base_dir = os.path.dirname(os.path.abspath(__file__))
    clean_host = repo_url.replace("https://", "").replace("http://", "")
    # User is assumed to be 'mtahiryilmazz' based on the Toolkit code
    auth_url = f"https://mtahiryilmazz:{token}@{clean_host}"
    
    def log(msg):
        print(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] {msg}")

    try:
        base_cmd = ["git", "-c", "credential.helper="]
        
        log("Initializing/Updating git remote...")
        subprocess.run(base_cmd + ["init"], capture_output=True, cwd=base_dir)
        subprocess.run(base_cmd + ["remote", "remove", "origin"], capture_output=True, cwd=base_dir)
        subprocess.run(base_cmd + ["remote", "add", "origin", auth_url], capture_output=True, cwd=base_dir)

        log("Staging changes...")
        subprocess.run(base_cmd + ["add", "-A"], capture_output=True, cwd=base_dir)
        
        status_proc = subprocess.run(base_cmd + ["status", "--porcelain"], capture_output=True, text=True, cwd=base_dir)
        if not status_proc.stdout.strip():
            log("No changes to sync.")
            return

        commit_msg = f"Standalone Sync {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}"
        log(f"Committing: {commit_msg}")
        subprocess.run(base_cmd + ["commit", "-m", commit_msg], capture_output=True, cwd=base_dir)

        log("Pushing to GitHub...")
        push_proc = subprocess.run(base_cmd + ["push", "-u", "origin", "main", "--force"], 
                                 capture_output=True, text=True, errors='replace', cwd=base_dir)
        
        if push_proc.returncode == 0:
            log("Sync successful!")
        else:
            print(f"Error during push: {push_proc.stderr}")
            
    except Exception as e:
        print(f"Critical error: {e}")

if __name__ == "__main__":
    run_sync()
