# Git Authentication Fix

## Problem
Getting `403 Permission denied` when pushing to GitHub because authenticated as wrong account.

## Solutions

### Option 1: Update Git Credentials (Recommended)

1. **Clear cached credentials:**
```bash
git credential-osxkeychain erase <<EOF
host=github.com
protocol=https
EOF
```

2. **Next time you push, Git will prompt for credentials:**
```bash
git push -u origin main
```
Enter your GitHub username (`shaileshms05`) and a Personal Access Token (not password).

### Option 2: Use SSH Instead of HTTPS

1. **Change remote URL to SSH:**
```bash
git remote set-url origin git@github.com:shaileshms05/learnXAI.git
```

2. **Set up SSH key (if not already done):**
```bash
# Check if SSH key exists
ls -la ~/.ssh/id_rsa.pub

# If not, generate one
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key
cat ~/.ssh/id_ed25519.pub
# Then add it to GitHub: Settings > SSH and GPG keys > New SSH key
```

3. **Test SSH connection:**
```bash
ssh -T git@github.com
```

4. **Push:**
```bash
git push -u origin main
```

### Option 3: Use Personal Access Token

1. **Create Personal Access Token:**
   - Go to GitHub: Settings > Developer settings > Personal access tokens > Tokens (classic)
   - Generate new token with `repo` scope
   - Copy the token

2. **Use token as password when pushing:**
```bash
git push -u origin main
# Username: shaileshms05
# Password: <paste your token>
```

### Option 4: Update Git User Config

If you want to use a different account for this repo:

```bash
# For this repo only
git config user.name "shaileshms05"
git config user.email "your-email@example.com"

# Or globally
git config --global user.name "shaileshms05"
git config --global user.email "your-email@example.com"
```

## Quick Fix (Try This First)

```bash
# Clear credentials
git credential-osxkeychain erase <<EOF
host=github.com
protocol=https
EOF

# Try pushing again (will prompt for credentials)
git push -u origin main
```

When prompted:
- Username: `shaileshms05`
- Password: Use a Personal Access Token (not your GitHub password)

