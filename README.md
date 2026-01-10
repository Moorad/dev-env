# Dev env

A repository to store my dotfiles, configs and global scripts. Feel free to looking around!

## Prerequisites

-   zsh
-   br. w

## Installation

I've setup things in a way where you will only need to run one script and it will take care of everything.

```sh
./setup.sh
```

This script will take the dotfiles and configs and place them in their appropriate locations. This script is also intended to be used for syncing config and not just for initial environment setup.

If it finds that one of the files exists in your system already it will show you a diff of what would happen if the existing file were to be replaced. You will get prompted on whether to replace each file.
