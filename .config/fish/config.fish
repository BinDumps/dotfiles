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
	# CHM GREETING
	# ~/chmcrypt.sh
	# echo ''
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

#PATH
export PATH="/home/ext/.local/bin:$PATH"
fish_add_path ~/.local/share/yabridge/
