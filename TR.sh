#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m" 
RESET="\033[0m"
iranian_count=0
temp_dir=$(mktemp -d)
mirror_file="./mirrorlist.txt"
mirrorlist_arch="/etc/pacman.d/mirrorlist-arch"
TST_file="$temp_dir/mirrorlistXX.txt"

if [[ ! -f $mirrorlist_arch ]]; then
    $mirrorlist_arch="/etc/pacman.d/mirrorlist"
fi

if [[ ! -f $mirror_file ]]; then
    echo -e "${RED}File $mirror_file not found.${RESET}"
	echo "Downloading mirror list..."
	curl -s -o "$mirror_file" https://archlinux.org/mirrorlist/all/
fi

total_iranian_mirrors=$(awk '/## Iran/{flag=1; next} /## Israel/{flag=0} flag && /\$arch/{count++} END{print count}' "$mirror_file")
total_mirrors=$(grep -c "\$arch" "$mirror_file")


echo -e "${BLUE}Please select one of the following options:${RESET}"
echo -e "1) Check Iranian mirrors ($total_iranian_mirrors)"
echo -e "2) Check all mirrors ($total_mirrors)"
echo -e "0) Exit"

error_message=""
prompt="Your choice (0, 1 or 2): "

while true; do
    if [[ -n "$error_message" ]]; then
        echo -ne "\r\033[K$error_message"
    fi

    read -p "$prompt" choice

    if [[ "$choice" == "0" ]]; then
        echo "Exiting..."

        rm -rf "$temp_dir"
        exit 0
    elif [[ "$choice" == "1" || "$choice" == "2" ]]; then
        echo -e "${GREEN}You selected option $choice.${RESET}"
            if [ "$choice" == "1" ]; then
                choice_name="Iran"
                choice_count=$total_iranian_mirrors
            elif [ "$choice" == "2" ]; then
                choice_name="all"
                choice_count=$total_mirrors
            fi
        break
    else
        error_message="${RED}Invalid choice. Please enter 0, 1 or 2.${RESET}"
        prompt="Your choice (0, 1 or 2): "
    fi
done



process_mirror() {
    mirror_url="$1"
    domain_name=$(echo "$mirror_url" | awk -F[/:] '{print $4}')
    ping_result=$(ping -c 1 -W 1 "$domain_name" 2>/dev/null | grep 'time=' | awk -F 'time=' '{print $2}' | awk '{print $1}')

    if [ -z "$ping_result" ]; then
        echo "$mirror_url Unavailable" >> "$TST_file"
    else
        echo "$ping_result $mirror_url" >> "$TST_file"
    fi
}




while read -r line; do
    if [[ "$choice" -eq 1 && "$line" == "## Iran" ]]; then
        iran_mirrors=1
        continue
    elif [[ "$choice" -eq 1 && "$line" == "## Israel" && $iran_mirrors -eq 1 ]]; then
        break
    fi


    if [[ "$choice" -eq 2 || ( "$iran_mirrors" -eq 1 && "$line" == *"\$arch" ) ]]; then
        mirror_url="${line#* = }"
        mirror_url="${mirror_url#\#}"

        if [[ "$mirror_url" != "" ]]; then

            if [[ "$mirror_url" == *"\$arch" ]]; then
                if [[ "$choice" -eq 1 ]]; then
                    iranian_count=$((iranian_count + 1))
                    printf "\rChecking Iranian mirrors... %d/%d" "$iranian_count" "$total_iranian_mirrors"
                else
                    mirror_count=$((mirror_count + 1))
                    printf "\rChecking mirrors... %d/%d" "$mirror_count" "$total_mirrors"
                fi
                
                process_mirror "$mirror_url" &
            fi
        fi
    fi
done < "$mirror_file"

wait 

echo -e "\nAccessible Mirrors:"
    sort -n "$TST_file" | while read -r result; do
        if [[ "$result" != *"Unavailable"* ]]; then
            ping_time=$(echo "$result" | awk '{print $1}')  
            mirror_url=$(echo "$result" | cut -d' ' -f2- )  
            printf "${YELLOW}%-70s${RESET} ${GREEN}%s ms${RESET}\n" "$mirror_url" "$ping_time" 
        fi
    done

echo -e "\n${RED}Unavailable Mirrors:${RESET}"
if ! grep -q "Unavailable" "$TST_file"; then
    echo -e "${GREEN}All mirrors are accessible.${RESET}"
else
    while read -r result; do
        if [[ "$result" == *"Unavailable"* ]]; then
            mirror_url=$(echo "$result" | awk '{print $1}')
            printf "%-70s ${RED}%-10s${RESET}\n" "$mirror_url" "Unavailable"  
        fi
    done < "$TST_file"
fi


#######
echo -e "${BLUE}Please select one of the following options:${RESET}"
echo -e "1) Use $choice_name mirrors ($choice_count)"
echo -e "0) Exit"

error_messageX=""
promptX="Your choice (0, 1): "

while true; do
    if [[ -n "$error_messageX" ]]; then
        echo -ne "\r\033[K$error_messageX"
    fi

    read -p "$promptX" choiceX

    if [[ "$choiceX" == "0" ]]; then
        echo "Exiting..."

        rm -rf "$temp_dir"
        exit 0
    elif [ "$choiceX" == "1" ]; then
            grep -v "Unavailable" "$TST_file" | sort -n | awk '{ $1=""; sub(/^ /, ""); print "Server = "$0 }' | sudo tee "$mirrorlist_arch" > /dev/null
            echo -e "${GREEN}       Completed!! ${RESET}"
        break
    else
        error_messageX="${RED}Invalid choice. Please enter 0, 1 or 2.${RESET}"
        promptX="Your choice (0, 1): "
    fi
done

rm -rf "$TST_dir"  
