# Parker's Dotfiles

## Overview

This repo contains my personal dotfiles, managed via [dfm](https://github.com/justone/dfm).

## Using this repo

First, fork this repo on GitHub.

Then, add your dotfiles:

    $ git clone git@github.com:username/dotfiles.git .dotfiles
    $ cd .dotfiles
    $  # edit files
    $  # edit files
    $ git push origin master

Finally, to install your dotfiles onto a new system:

    $ cd $HOME
    $ git clone git@github.com:username/dotfiles.git .dotfiles
    $ ./.dotfiles/bin/dfm install # creates symlinks to install files

## Full documentation

For more information, check out the [wiki](http://github.com/justone/dotfiles/wiki).

