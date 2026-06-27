# GridX Workspace

This is the main workspace of the project that clones / fetches latest updates of each repository and stores them under this directory structure.

We use `go-task` to do this.

## How to set it up?

### 1. Tools and environment setup

#### 1.1. For Linux

* For Arch linux (or arch like operating systems):

    Install `go-task` tool using the following command

    ```bash
    sudo pacman -S go-task
    ```

* For Ubunutu & Debian operating systems:

    
* For Red hat & Fedora like operating systems:


After installing go-task, run the following command:

```bash
ssh -T git@github.com
```

If you get `Hi <username>! You've successfully authenticated, but GitHub does not provide shell access`, then you can skip the next few steps listed down.

If you get `Permission denied (publickey).`, then do the following:

1. Generate a new ssh key

    ```bash
    ssh-keygen -t ed25519 -C "your_email@example.com"
    ```

    The above command will ask you enter location to save the file, accept the default location.

**NOTE**: The above email must be github email!! The default location is `~/.ssh/`

2. Copy the public key

    ```bash
    cat ~/.ssh/id_ed25519.pub
    ```

The above will output the public key in the terminal, select it and copy.

#### 1.2. For Mac

#### 1.3. For Windows 11

---

### 2. Github setup

Add the above obtained ssh key to github.

1. Go to github.com -> Click your profile picture -> Settings.
1. On the left sidebar, click SSH and GPG keys.
1. Click the green New SSH Key button.
1. Give it a title (Ex: "Your Name Project"), paste your public key string into the Key field, and click Add SSH key.

Now run the same check again:

#### 2.1. For Linux

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

If it returns a successful output then you can continue. Ex: `Hi <username>! You've successfully authenticated, but GitHub does not provide shell access`

#### 2.2. For Mac

#### 2.3. For Windows 11

---

### 3. Bootstrap the project repositories & containers

#### 3.1. Clone / update existing repositories to common folder

Run the following command to clone missing repos and pull latest changes of existing repos.

* For Linux environements

    ```bash
    go-task setup
    ```

* For Mac environments

* For windows environment

#### 3.2. Build the docker containers

For now you can run the following command to spin up (or build and run) bootstrapped docker containers.

**NOTE**: You can also directly go into the repo folder and run them instead without using the go-task command.

* For Linux environements

    ```bash
    go-task up
    ```

* For Mac environments

* For windows environment

#### 3.3. Stopping all containers

Run the following command to stop all containers

* For Linux environements

    ```bash
    go-task down
    ```

* For Mac environments

* For windows environment

#### Other commands

Run the following command to  check for additional commands

* For Linux environements

    ```bash
    go-task --list
    ```

* For Mac environments

* For windows environment