if status is-interactive
# Commands to run in interactive sessions can go here
end

function fish_greeting
	#echo "===================================="
	#echo "  Welcome back, $USER!"
	#echo "  Today is $(date '+%A, %B %d, %Y')"
	#echo "===================================="
	fastfetch
	#set_color brblue --bold
	#echo '                  age  ' $(set_color normal) $(system_age)
	echo ''
end
#funcsave fish_greeting

function fish_prompt
    # Get the current user and hostname
    set -l user (whoami)
    set -l host (prompt_hostname)

    # Get the current working directory abbreviated (like ~ for home)
    set -l cwd (prompt_pwd)

    # Determine the symbol based on permissions (# for root, $ for regular user)
    set -l suffix '#'
    if fish_is_root_user
        set -l suffix '$'
    end

    # Print the prompt exactly like the-lobby: user@host:cwd#
    echo -n "$user:$cwd$suffix "
end

# Custom aliases
alias ls='eza --icons=auto'
alias ll='ls -l'
alias la='ls -la'
alias lh='ls -lah'
alias fastfetch-old='fastfetch -c ~/fastfetch.config.old.jsonc'
alias rmhosts='rm -rf ~/.ssh/known_hosts'
alias anon='fish -P'
alias ssh="TERM=xterm-256color command ssh"
alias lazyssh="TERM=xterm-256color command lazyssh"

# ghostty-related configuration
function sudo
    # 1. Change terminal background to dark red
    printf "\e]11;#3b0000\a"

    # 2. Run the actual sudo command
    command sudo $argv

    # 3. Reset the terminal background back to your default
    printf "\e]111\a"
end

#PATH
export PATH="/home/ext/.local/bin:$PATH"
fish_add_path ~/.local/share/yabridge/
