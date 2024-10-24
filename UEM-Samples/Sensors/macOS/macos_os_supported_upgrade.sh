#!/bin/bash
# Compare version numbers of two OS versions or floating point numbers up to 3 dots
compare_numbers() {
    IFS='.' read -r -a os1 <<< "$1"
    IFS='.' read -r -a os2 <<< "$2"

    counter=0

    if [[ "${#os1[@]}" -gt "${#os2[@]}" ]]; then
        counter="${#os1[@]}"
    else
        counter="${#os2[@]}"
    fi

    for (( k=0; k<counter; k++ )); do
        if [[ "${os1[$k]:-}" ]] && ! [[ "${os2[$k]:-}" ]]; then
            echo "gt"
            return 0
        elif [[ "${os2[$k]:-}" ]] && ! [[ "${os1[$k]:-}" ]]; then
            echo "lt"
            return 0
        fi

        if [[ "${os1[$k]}" != "${os2[$k]}" ]]; then
            t1="${os1[$k]}"
            t2="${os2[$k]}"

            alphat1=${t1//[^a-zA-Z]}; alphat1=${#alphat1}
            alphat2=${t2//[^a-zA-Z]}; alphat2=${#alphat2}

            if [[ "$alphat1" -gt 0 ]]; then
                temp1=""
                for (( j=0; j<${#t1}; j++ )); do
                    if [[ ${t1:$j:1} = *[[:alpha:]]* ]]; then
                        g=$(LC_CTYPE=C printf '%d' "'${t1:$j:1}")
                        g=$((g-40))
                        temp1="$temp1$g"
                    else
                        temp1="$temp1${t1:$j:1}"
                    fi
                done
                t1="$temp1"
            fi
            if [[ "$alphat2" -gt 0 ]]; then
                temp2=""
                for (( j=0; j<${#t2}; j++ )); do
                    if [[ ${t2:$j:1} = *[[:alpha:]]* ]]; then
                        g=$(LC_CTYPE=C printf '%d' "'${t2:$j:1}")
                        g=$((g-40))
                        temp2="$temp2$g"
                    else
                        temp2="$temp2${t2:$j:1}"
                    fi
                done
                t2="$temp2"
            fi

            if [[ "$t1" -gt "$t2" ]]; then
                echo "gt"
                return 0
            elif [[ "$t1" -lt "$t2" ]]; then
                echo "lt"
                return 0
            fi
        fi
    done

    echo "eq"
}

# compares two numbers n1 > n2
gt() {
    result=$(compare_numbers "$1" "$2")
    [[ "$result" == "gt" ]]
}

# compares two numbers n1 < n2
lt() {
    result=$(compare_numbers "$1" "$2")
    [[ "$result" == "lt" ]]
}

# compares two numbers n1 >= n2
ge() {
    result=$(compare_numbers "$1" "$2")
    [[ "$result" == "gt" || "$result" == "eq" ]]
}

# compares two numbers n1 <= n2
le() {
    result=$(compare_numbers "$1" "$2")
    [[ "$result" == "lt" || "$result" == "eq" ]]
}

# compares two numbers n1 == n2
eq() {
    result=$(compare_numbers "$1" "$2")
    [[ "$result" == "eq" ]]
}

# Get the list of available macOS versions
os_list=$(softwareupdate --list-full-installers | awk -F 'Version: |, Size' '/Title:/{print $2}')
IFS=$'\n'
os_list=($(sort -r --numeric-sort <<<"${os_list[*]}"))
currentOS=$(sw_vers -productVersion)
unset IFS

full_list=""
for os in "${os_list[@]}"; do
    if gt "$os" "$currentOS"; then
        full_list="$os,$full_list"
    fi
done

# Return the highest version if no upgrade is available
if [ -n "$full_list" ]; then
    full_list="${full_list:0:(${#full_list}-1)}"
else
    full_list="${os_list[0]}"  # Set to the highest available version
fi

echo "${full_list}"
# Description: Use SoftwareUpdate to display latest OS available for the specific device
# Execution Context: SYSTEM
# Return Type: INTEGER