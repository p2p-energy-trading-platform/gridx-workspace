# GridX Workspace

This is the main workspace of the project that clones / fetches latest updates of each repository and stores them under this directory structure.

We use `go-task` to do this.

## 1. Tools and environment setup

### 1.1. For Linux

* For Arch linux (or arch like operating systems):

    Install `go-task` tool using the following command

    ```bash
    sudo pacman -S go-task
    ```

* For Ubunutu & Debian operating systems:

    Add the official Task repository:

    ```bash
    curl -1sLf 'https://dl.cloudsmith.io/public/task/task/setup.deb.sh' | sudo -E bash
    sudo apt update
    sudo apt install task
    ```
    
* For Red hat & Fedora like operating systems:

    Add the official Task repository:

    ```bash
    curl -1sLf 'https://dl.cloudsmith.io/public/task/task/setup.rpm.sh' | sudo -E bash
    sudo dnf install task
    ```

    Recent Fedora versions also package go-task directly:

    ```bash
    sudo dnf install go-task
    ```


After installing go-task, run the following command:

```bash
ssh -T git@github.com
```

If you get `Hi <username>! You've successfully authenticated, but GitHub does not provide shell access`, then you can skip directly to **3. Bootstrap the project repositories & containers**.

If you get `Permission denied (publickey).`, then do the following:

1. Generate a new ssh key

    ```bash
    ssh-keygen -t ed25519 -C "your_email@example.com"
    ```

    The above command will ask you enter location to save the file, accept the default location.

    **NOTE**: The above email must be github email!! The default location is `~/.ssh/`

1. Copy the public key

    ```bash
    cat ~/.ssh/id_ed25519.pub
    ```

    The above will output the public key in the terminal, select it and copy.

### 1.2. For Mac

Install `go-task` using Homebrew:

```bash
brew install go-task
```

If you don't already have Homebrew installed, install it first from the official Homebrew website.

After installing go-task follow the **same methods as mentioned above under linux** to setup ssh.

### 1.3. For Windows 11

Open PowerShell and run:

```bash
winget install Task.Task
```

After installing go-task, Open PowerShell (or Git Bash) and verify SSH authentication:

```powershell
ssh -T git@github.com
```

If you get `Hi <username>! You've successfully authenticated, but GitHub does not provide shell access`, then you can skip directly to **3. Bootstrap the project repositories & containers**.

If you get `Permission denied (publickey).`, then do the following:

1. Generate an SSH key:

    ```bash
    ssh-keygen -t ed25519 -C "your_email@example.com"
    ```

    The above command will ask you enter location to save the file, accept the default location.

    **NOTE**: The above email must be github email!! The default location is `~/.ssh/` if in git bash or `$env:USERPROFILE\.ssh\` if in powershell

1. Copy the public key

    If in powershell, run:
    ```powershell
    type $env:USERPROFILE\.ssh\id_ed25519.pub
    ```

    If in git bash, run:
    ```bash
    cat ~/.ssh/id_ed25519.pub
    ```

    The above will output the public key in the terminal, select it and copy.

---

## 2. Github setup

Add the above obtained ssh key to github.

1. Go to github.com -> Click your profile picture -> Settings.
1. On the left sidebar, click SSH and GPG keys.
1. Click the green New SSH Key button.
1. Give it a title (Ex: "Your Name Project"), paste your public key string into the Key field, and click Add SSH key.

Now run the same check again:

```bash
ssh -T git@github.com
```

If it returns a successful output then you can continue. Ex: `Hi <username>! You've successfully authenticated, but GitHub does not provide shell access`

---

## 3. Bootstrap the project repositories & containers

### 3.1. Clone / update existing repositories to common folder

Run the following command to clone missing repos and pull latest changes of existing repos.

* For Arch & Some fedora environements

    ```bash
    go-task setup
    ```

* For Ubuntu, Mac, Windows, etc

    ```bash
    task setup
    ```

**NOTE**: Try either to see which command works, the package can be named differently for different operating system

### 3.2. Build the docker containers

For now you can run the following command to spin up (or build and run) bootstrapped docker containers.

**NOTE**: You can also directly go into the repo folder and run them instead without using the go-task command.

* For Arch & Some fedora environements

    ```bash
    go-task up
    ```

* For Ubuntu, Mac, Windows, etc

    ```bash
    task up
    ```

### 3.3. Stopping all containers

Run the following command to stop all containers

* For Arch & Some fedora environements

    ```bash
    go-task down
    ```

* For Ubuntu, Mac, Windows, etc

    ```bash
    task down
    ```

### 3.4. Other commands

Run the following command to  check for additional commands

* For Arch & Some fedora environements

    ```bash
    go-task --list
    ```

* For Ubuntu, Mac, Windows, etc

    ```bash
    task --list
    ```