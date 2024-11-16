# Marc Beinder's Dotfiles

This repository contains the configuration files for my development setup. Everything from terminal configurations, to JetBrains keymaps and code inspections.

## Terminal

For the Terminal, I use ZSH on Mac (using iTerm) and on Windows I use Bash (using Git Bash). This setup has been configured to automatically detect which OS I am
currently using and adjusts accordingly.

## Mac (Primary Machine)

When running on a Mac, the configurations will load additional tools and configurations through Oh-My-Zsh. For the most part, OMZ uses the default configuration.
Some additional OMZ plugins have been installed.

## Windows (Before I saw the light)

There are still times when I need to use Windows for development. When this is the case, I load my basic tooling like aliases and custom terminal functions.
Beyond this, there isn't really anything special about the Windows setup.

## Oh-My-Zsh

OMZ is configured to automatically update itself when a new terminal session is started or the configurations are reloaded. There are some OMZ plugins that are loaded
in this configuration:

- colorize
- git
- terraform
- zsh-autosuggestions
- zsh-syntax-highlighting

The plugin that I rely on the most is most definitely `zsh-autosuggestions`. It makes things slightly quicker, which saves short amounts of time here and there. After a
while, this time adds up. I like to say that it's the small details that are inconsequential on their own that collectively make a world of difference.

I also changed the accept key for `zsh-autosuggestions` as it defaulted to `enter/return`. To make life easier and so that there was no confusion, I changed this to
the tab key. This was done with the following line.

```shell
bindkey '^I' autosuggest-accept
```

It may not seem like much, but this change has saved me multiple times from running a command with an extra flag that I did not intend to run. This may have also
saved production a time or two as well.

## Environment Variables

Yes, I did include environment variables in this repository. No, none of them are sensitive. These variables inform various different tools about where different
tools live on the machine. These tools include:

- Laravel Herd
- NodeJS (used for building Tailwind with Vite)
- Java and OpenJDK (used for building .NET MAUI apps for Android)

There are also some environment variable used to configure Homebrew and OMZ plugins.

## Final Thoughts

This README doesn't cover everything in this repository, but more documentation is coming soon, mainly for my benefit, but you are welcome to browse the docs as I
write them if you're curious.