# r2u-ssh

This repository builds a Docker image based on **`rocker/r2u`** that enables:

- SSH access using a **base64-encoded** public key via `AUTHORIZED_KEYS_B64`
- `sudo` installed and configured (NOPASSWD) for the main user
- `bspm` enabled in R with the sudo backend
- A minimal boot script (`boot-sshd.sh`) that prepares `~/.ssh` and starts `sshd`

---

## Step 1 - Clone this repository

In terminal (bash/powershell):
```
git clone https://github.com/jmgirard/r2u-ssh.git
cd r2u-ssh
```

## Step 2 - Create an SSH key

In terminal (bash/powershell):
```
ssh-keygen -t ed25519 -C "your_email@example.com"
```

## Step 3 - Encode your public key

Create a `.env` file at the repo root containing your base64-encoded public key:

**macOS/Linux:**
```bash
{
  echo -n "AUTHORIZED_KEYS_B64="
  if base64 --help 2>&1 | grep -q '\-w'; then
    base64 -w0 ~/.ssh/id_ed25519.pub
  else
    base64 < ~/.ssh/id_ed25519.pub | tr -d '\n'
  fi
  echo
  echo "USERNAME=rocker"
} > .env
```

**Windows (PowerShell):**
```powershell
$pub = Get-Content -Raw "$env:USERPROFILE\.ssh\id_ed25519.pub"
$base64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pub))
"AUTHORIZED_KEYS_B64=$base64" | Out-File -Encoding ascii .env
"USERNAME=rocker" | Out-File -Append -Encoding ascii .env
```

## Step 4 - Build the image

In terminal (bash/powershell):
```
docker compose up -d --build
```

## Step 5 - Connect in Positron

1. Open **Positron**
2. Go to **Remote Explorer** (left pane)
3. Click on the "Configure" (gear) icon to open SSH config
4. Paste the following in:

```
Host r2u-ssh
  HostName 127.0.0.1
  Port 2222
  User rocker
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
```

4. Click the **Refresh** (cycle) icon
5. Click **Connect to Host in New Window** (window plus) icon next to r2u-ssh

You'll now be connected to a full R environment running inside Docker.

## Step 6 - Cleanup

To close the container but keep the image, use:
```
docker compose down
```

To close the container and remove the image, use:
```bash
docker compose down --rmi all
```
