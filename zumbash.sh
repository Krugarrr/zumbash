#!/bin/bash

TICK_RATE="0.02"
GAME_RUNNING=1
GAME_STATE="MENU"
FIELD_W=80
FIELD_H=25
PLAYER_X=40
OLD_PLAYER_X=-1

SNAKE_ORIG=(R G G B Y R R G Y B B R G Y R G B Y R R G Y B B R G Y)
SNAKE=()
PATH_X=()
PATH_Y=()
PATH_LEN=0
SNAKE_HEAD_POS=0
SNAKE_SPEED=10
TICK_COUNT=0
SCORE=0
COLORS=(R G B Y)
NEXT_COLOR="G"

B_X=()
B_Y=()
B_C=()

C_R="\e[31m"
C_G="\e[32m"
C_B="\e[34m"
C_Y="\e[33m"
C_RST="\e[0m"
C_GRY="\e[90m"

cup() { printf "\e[%d;%dH" "$1" "$2"; }

init_engine() {
    printf "\e[?1049h\e[?25l"
    stty -echo
    clear
    generate_path
}

cleanup() {
    printf "\e[?25h\e[?1049l"
    stty echo
    clear
    exit 0
}

draw_menu_text() {
    clear
    cup 2 $((FIELD_W/2 - 10)); printf "\e[1;33m=== ZUMBASH ===\e[0m"
    cup 4 5; printf "\e[1;36mУПРАВЛЕНИЕ:\e[0m"
    cup 5 5; printf "A / D / СТРЕЛКИ < > - Движение пушки"
    cup 6 5; printf "W / ПРОБЕЛ / СТРЕЛКА ВВЕРХ - Выстрел"
    cup 7 5; printf "Q - Выход"
    
    cup 9 5; printf "\e[1;32mВЫБЕРИТЕ СЛОЖНОСТЬ (Нажмите цифру):\e[0m"
    cup 11 10; printf "1. Легко"
    cup 12 10; printf "2. Нормально"
    cup 13 10; printf "3. Сложно"
}

handle_resize() {
    if [[ "$GAME_STATE" == "PLAYING" ]]; then
        clear
        OLD_PLAYER_X=-1
        draw_static
    elif [[ "$GAME_STATE" == "MENU" ]]; then
        draw_menu_text
    fi
}

trap cleanup SIGINT SIGTERM SIGALRM
trap handle_resize SIGWINCH

generate_path() {
    local x y
    y=3; for ((x=2; x<FIELD_W-2; x++)); do PATH_X+=($x); PATH_Y+=($y); done
    x=$((FIELD_W-3)); for ((y=4; y<=8; y++)); do PATH_X+=($x); PATH_Y+=($y); done
    y=8; for ((x=FIELD_W-4; x>=4; x--)); do PATH_X+=($x); PATH_Y+=($y); done
    x=4; for ((y=9; y<=14; y++)); do PATH_X+=($x); PATH_Y+=($y); done
    y=14; for ((x=5; x<FIELD_W-4; x++)); do PATH_X+=($x); PATH_Y+=($y); done
    x=$((FIELD_W-5)); for ((y=15; y<=19; y++)); do PATH_X+=($x); PATH_Y+=($y); done
    y=19; for ((x=FIELD_W-6; x>=20; x--)); do PATH_X+=($x); PATH_Y+=($y); done
    PATH_LEN=${#PATH_X[@]}
}

show_menu() {
    GAME_STATE="MENU"
    draw_menu_text

    local choice
    while true; do
        read -rsn1 choice
        case "$choice" in
            1) SNAKE_SPEED=12; break ;;
            2) SNAKE_SPEED=8; break ;;
            3) SNAKE_SPEED=4; break ;;
            q|Q|й|Й) cleanup ;;
        esac
    done

    SNAKE=("${SNAKE_ORIG[@]}")
    SNAKE_HEAD_POS=0
    SCORE=0
    PLAYER_X=40
    OLD_PLAYER_X=-1
    B_X=(); B_Y=(); B_C=()
    GAME_STATE="PLAYING"
    clear
    draw_static
}

draw_static() {
    local i
    cup 1 1; printf "Score: %-5d" "$SCORE"
    cup 2 1; printf "%${FIELD_W}s\n" | tr ' ' '='
    for ((i=3; i<=FIELD_H; i++)); do
        cup $i 1; printf "|"
        cup $i $FIELD_W; printf "|"
    done
    cup $((FIELD_H+1)) 1; printf "%${FIELD_W}s\n" | tr ' ' '='

    for ((i=0; i<PATH_LEN; i++)); do
        cup ${PATH_Y[$i]} ${PATH_X[$i]}
        if [[ $i -eq $((PATH_LEN-1)) ]]; then
            printf "${C_R}@${C_RST}"
        else
            printf "${C_GRY}.${C_RST}"
        fi
    done
}

clear_full_snake() {
    local i pos
    for ((i=0; i<${#SNAKE[@]}; i++)); do
        pos=$((SNAKE_HEAD_POS - i))
        if (( pos >= 0 && pos < PATH_LEN )); then
            cup ${PATH_Y[$pos]} ${PATH_X[$pos]}
            if [[ $pos -eq $((PATH_LEN-1)) ]]; then
                printf "${C_R}@${C_RST}"
            else
                printf "${C_GRY}.${C_RST}"
            fi
        fi
    done
}

check_match3() {
    local idx=$1 color left right count
    [[ -z "${SNAKE[$idx]}" ]] && return
    color=${SNAKE[$idx]}
    left=$idx
    right=$idx

    while [[ $left -gt 0 ]] && [[ "${SNAKE[$((left-1))]}" == "$color" ]]; do ((left--)); done
    while [[ $right -lt $((${#SNAKE[@]}-1)) ]] && [[ "${SNAKE[$((right+1))]}" == "$color" ]]; do ((right++)); done

    count=$((right - left + 1))
    if [[ $count -ge 3 ]]; then
        clear_full_snake
        SNAKE=("${SNAKE[@]:0:$left}" "${SNAKE[@]:$((right+1))}")
        ((SCORE += count * 10))
        cup 1 8; printf "%-5d" "$SCORE"
        
        if [[ ${#SNAKE[@]} -gt 0 ]] && [[ $left -lt ${#SNAKE[@]} ]] && [[ $left -gt 0 ]]; then
            [[ "${SNAKE[$left]}" == "${SNAKE[$((left-1))]}" ]] && check_match3 $left
        fi
    fi
}

process_key() {
    case "$1" in
        q|Q|й|Й) GAME_RUNNING=0 ;;
        a|A|ф|Ф|LEFT) [[ $PLAYER_X -gt 3 ]] && ((PLAYER_X-=2)) ;;
        d|D|в|В|RIGHT) [[ $PLAYER_X -lt $((FIELD_W - 3)) ]] && ((PLAYER_X+=2)) ;;
        w|W|ц|Ц|" "|UP)
            B_X+=($PLAYER_X)
            B_Y+=($((FIELD_H - 1)))
            B_C+=($NEXT_COLOR)
            NEXT_COLOR=${COLORS[$((RANDOM % 4))]}
            ;;
    esac
}

handle_input() {
    local key="" _junk=""
    
    if (( ${BASH_VERSINFO[0]:-0} >= 4 )); then
        if IFS= read -rsn1 -t "$TICK_RATE" key 2>/dev/null; then
            if [[ "$key" == $'\e' ]]; then
                IFS= read -rsn2 -t 0.01 _junk 2>/dev/null
                key="$key$_junk"
            fi
            IFS= read -rsn100 -t 0.01 _junk 2>/dev/null
            
            case "$key" in
                *$'\e[D'*) process_key "LEFT" ;;
                *$'\e[C'*) process_key "RIGHT" ;;
                *$'\e[A'*) process_key "UP" ;;
                *) process_key "$key" ;;
            esac
        fi
    else
        if read -t 0 2>/dev/null; then
            IFS= read -rsn1 key 2>/dev/null
            if [[ "$key" == $'\e' ]]; then
                IFS= read -rsn2 -t 1 _junk 2>/dev/null
                key="$key$_junk"
            fi
            
            while read -t 0 2>/dev/null; do
                IFS= read -rsn1 _junk 2>/dev/null
            done
            
            case "$key" in
                *$'\e[D'*) process_key "LEFT" ;;
                *$'\e[C'*) process_key "RIGHT" ;;
                *$'\e[A'*) process_key "UP" ;;
                *) process_key "$key" ;;
            esac
        fi
        sleep "$TICK_RATE"
    fi
}

is_path() {
    local tx=$1 ty=$2 p
    for ((p=0; p<PATH_LEN; p++)); do
        [[ ${PATH_X[$p]} -eq $tx && ${PATH_Y[$p]} -eq $ty ]] && return 0
    done
    return 1
}

update_logic() {
    local b i pos hit new_bx=() new_by=() new_bc=()

    if [[ ${#SNAKE[@]} -eq 0 ]]; then GAME_STATE="WIN"; GAME_RUNNING=0; return; fi
    if (( SNAKE_HEAD_POS >= PATH_LEN )); then GAME_STATE="LOSE"; GAME_RUNNING=0; return; fi

    if (( TICK_COUNT % SNAKE_SPEED == 0 )); then ((SNAKE_HEAD_POS++)); fi

    for b in "${!B_X[@]}"; do
        hit=0
        
        cup ${B_Y[$b]} ${B_X[$b]}
        if is_path ${B_X[$b]} ${B_Y[$b]}; then 
            printf "${C_GRY}.${C_RST}"
        else 
            if [[ ${B_X[$b]} -eq $PLAYER_X ]]; then
                printf "${C_GRY}:${C_RST}"
            else
                printf " "
            fi
        fi

        ((B_Y[$b]--))

        if [[ ${B_Y[$b]} -le 2 ]]; then
            cup 2 ${B_X[$b]}; printf "=" 
            continue
        fi

        for ((i=0; i<${#SNAKE[@]}; i++)); do
            pos=$((SNAKE_HEAD_POS - i))
            if (( pos >= 0 && pos < PATH_LEN )); then
                if [[ ${PATH_X[$pos]} -eq ${B_X[$b]} && ${PATH_Y[$pos]} -eq ${B_Y[$b]} ]]; then
                    clear_full_snake
                    SNAKE=("${SNAKE[@]:0:$i}" "${B_C[$b]}" "${SNAKE[@]:$i}")
                    check_match3 $i
                    hit=1
                    break
                fi
            fi
        done

        if [[ $hit -eq 0 ]]; then
            new_bx+=(${B_X[$b]})
            new_by+=(${B_Y[$b]})
            new_bc+=(${B_C[$b]})
        fi
    done

    B_X=("${new_bx[@]}"); B_Y=("${new_by[@]}"); B_C=("${new_bc[@]}")
}

draw_dynamic() {
    local tail_pos i pos b cc y

    if [[ "$OLD_PLAYER_X" -ne "$PLAYER_X" ]]; then
        if [[ "$OLD_PLAYER_X" -gt 0 ]]; then
            cup $FIELD_H $((OLD_PLAYER_X - 1)); printf "   "
            for ((y=3; y<FIELD_H; y++)); do
                cup $y $OLD_PLAYER_X; printf " "
            done
            for ((i=0; i<PATH_LEN; i++)); do
                if [[ ${PATH_X[$i]} -eq $OLD_PLAYER_X ]]; then
                    cup ${PATH_Y[$i]} ${PATH_X[$i]}
                    if [[ $i -eq $((PATH_LEN-1)) ]]; then printf "${C_R}@${C_RST}"
                    else printf "${C_GRY}.${C_RST}"; fi
                fi
            done
        fi

        for ((y=3; y<FIELD_H; y++)); do
            cup $y $PLAYER_X; printf "${C_GRY}:${C_RST}"
        done
        
        for ((i=0; i<PATH_LEN; i++)); do
            if [[ ${PATH_X[$i]} -eq $PLAYER_X ]]; then
                cup ${PATH_Y[$i]} ${PATH_X[$i]}
                if [[ $i -eq $((PATH_LEN-1)) ]]; then printf "${C_R}@${C_RST}"
                else printf "${C_GRY}.${C_RST}"; fi
            fi
        done

        OLD_PLAYER_X=$PLAYER_X
    fi

    cup $FIELD_H $((PLAYER_X - 1))
    case $NEXT_COLOR in
        R) cc=$C_R ;; G) cc=$C_G ;; B) cc=$C_B ;; Y) cc=$C_Y ;;
    esac
    printf "/${cc}${NEXT_COLOR}${C_RST}\\"

    for b in "${!B_X[@]}"; do
        cup ${B_Y[$b]} ${B_X[$b]}
        case ${B_C[$b]} in
            R) cc=$C_R ;; G) cc=$C_G ;; B) cc=$C_B ;; Y) cc=$C_Y ;;
        esac
        printf "${cc}O${C_RST}"
    done

    tail_pos=$((SNAKE_HEAD_POS - ${#SNAKE[@]}))
    if (( tail_pos >= 0 && tail_pos < PATH_LEN )); then
        cup ${PATH_Y[$tail_pos]} ${PATH_X[$tail_pos]}
        if [[ $tail_pos -eq $((PATH_LEN-1)) ]]; then printf "${C_R}@${C_RST}"
        else printf "${C_GRY}.${C_RST}"; fi
    fi

    for ((i=0; i<${#SNAKE[@]}; i++)); do
        pos=$((SNAKE_HEAD_POS - i))
        if (( pos >= 0 && pos < PATH_LEN )); then
            cup ${PATH_Y[$pos]} ${PATH_X[$pos]}
            case ${SNAKE[$i]} in
                R) cc=$C_R ;; G) cc=$C_G ;; B) cc=$C_B ;; Y) cc=$C_Y ;;
            esac
            printf "${cc}O${C_RST}"
        fi
    done
}

show_end_screen() {
    clear
    cup 8 $((FIELD_W/2 - 8))
    if [[ "$GAME_STATE" == "WIN" ]]; then printf "${C_G}*** ВЫ ПОБЕДИЛИ! ***${C_RST}"
    elif [[ "$GAME_STATE" == "LOSE" ]]; then printf "${C_R}*** ИГРА ОКОНЧЕНА ***${C_RST}"
    fi
    cup 10 $((FIELD_W/2 - 8)); printf "Ваш счет: $SCORE"
    cup 12 $((FIELD_W/2 - 12)); printf "Нажмите любую клавишу..."
    read -rsn1
}

main() {
    init_engine
    show_menu

    while [ $GAME_RUNNING -eq 1 ]; do
        handle_input
        update_logic
        draw_dynamic
        ((TICK_COUNT++))
    done

    if [[ "$GAME_STATE" != "MENU" && "$GAME_STATE" != "PLAYING" ]]; then
        show_end_screen
    fi
    cleanup
}

main
