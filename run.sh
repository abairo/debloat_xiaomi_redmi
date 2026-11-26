#!/usr/bin/env bash
set -uo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly CONF_DIR="${SCRIPT_DIR}/conf"
declare -A SELECTED=() INSTALLED=() KNOWN=() THIRD_PARTY=() SYSTEM=() DISABLED=()

die() { echo "ERRO: $*" >&2; exit 1; }
trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

select_device() {
    local -a devices=()
    local serial state rest
    command -v adb >/dev/null 2>&1 || die "Instale o Android Platform Tools (adb)."
    adb start-server </dev/null >/dev/null || die "Nao foi possivel iniciar o ADB."
    while read -r serial state rest; do
        [[ -z "${serial:-}" || "$serial" == "List" ]] && continue
        [[ "$state" == "device" ]] && devices+=("$serial")
    done < <(adb devices -l </dev/null)
    ((${#devices[@]} == 1)) || {
        adb devices -l </dev/null >&2
        die "Conecte e autorize exatamente um dispositivo."
    }
    DEVICE_SERIAL="${devices[0]}"
}

detect_device() {
    local manufacturer brand
    manufacturer="$(adb -s "$DEVICE_SERIAL" shell getprop ro.product.manufacturer </dev/null | tr -d '\r')"
    brand="$(adb -s "$DEVICE_SERIAL" shell getprop ro.product.brand </dev/null | tr -d '\r')"
    DEVICE_MODEL="$(adb -s "$DEVICE_SERIAL" shell getprop ro.product.model </dev/null | tr -d '\r')"
    ANDROID_VERSION="$(adb -s "$DEVICE_SERIAL" shell getprop ro.build.version.release </dev/null | tr -d '\r')"
    case "${manufacturer,,}:${brand,,}" in
        *samsung*) DEVICE_VENDOR="samsung" ;;
        *xiaomi*|*redmi*|*poco*) DEVICE_VENDOR="xiaomi" ;;
        *motorola*) DEVICE_VENDOR="motorola" ;;
        *) DEVICE_VENDOR="" ;;
    esac
}

choose_options() {
    local choice answer ask_base=true
    case "$DEVICE_VENDOR" in
        samsung)
            echo "AVISO: listas Samsung historicas e ainda nao validadas em One UI atual."
            printf '\nPerfil Samsung:\n  1) Basico\n  2) Moderado\n  3) Pesado\n  4) Sair\n'
            read -r -p "Escolha [1-4]: " choice
            case "$choice" in
                1) PROFILE_LEVEL="basic" ;; 2) PROFILE_LEVEL="light" ;;
                3) PROFILE_LEVEL="heavy" ;; 4) exit 0 ;; *) die "Opcao invalida." ;;
            esac
            ;;
        xiaomi)
            PROFILE_LEVEL="basic"
            PROFILE_SCOPE="all"
            echo "Perfil Xiaomi basico selecionado."
            ;;
        motorola)
            printf '\nPerfil Motorola:\n  1) Aplicativos de terceiros revisados\n  2) Sistema revisado (experimental)\n  3) Sair\n'
            read -r -p "Escolha [1-3]: " choice
            case "$choice" in
                1)
                    PROFILE_LEVEL="basic"
                    PROFILE_SCOPE="third-party"
                    ;;
                2)
                    PROFILE_LEVEL="system-reviewed"
                    PROFILE_SCOPE="system"
                    INCLUDE_BASE=false
                    ask_base=false
                    echo "Somente os pacotes de sistema revisados serao carregados."
                    ;;
                3) exit 0 ;;
                *) die "Opcao invalida." ;;
            esac
            ;;
        *) die "Ainda nao existe perfil para este fabricante." ;;
    esac

    if [[ "$ask_base" == true ]]; then
        echo
        echo "A camada base contem redes sociais, streaming, jogos e apps Google."
        echo "Ela pode incluir aplicativos instalados por voce."
        read -r -p "Incluir a camada base? [s/N]: " answer
        case "${answer,,}" in s|sim|y|yes) INCLUDE_BASE=true ;; *) INCLUDE_BASE=false ;; esac
    fi

    printf '\nAcao:\n  1) Apenas visualizar\n  2) Desativar\n  3) Desinstalar para o usuario principal\n  4) Restaurar/habilitar\n  5) Sair\n'
    read -r -p "Escolha [1-5]: " choice
    case "$choice" in
        1) ACTION="preview" ;; 2) ACTION="disable" ;; 3) ACTION="uninstall" ;;
        4) ACTION="restore" ;; 5) exit 0 ;; *) die "Opcao invalida." ;;
    esac

    [[ -n "${PROFILE_SCOPE:-}" ]] || PROFILE_SCOPE="all"
}

load_config() {
    local file="$1" line package
    [[ -f "$file" ]] || die "Configuracao nao encontrada: $file"
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        package="$(trim "$line")"
        [[ -z "$package" ]] && continue
        [[ "$package" =~ ^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$ ]] ||
            die "Pacote invalido em $file: $package"
        SELECTED["$package"]=1
    done < "$file"
}

load_packages() {
    load_config "${CONF_DIR}/vendors/${DEVICE_VENDOR}/packages/${PROFILE_LEVEL}.conf"
    [[ "$INCLUDE_BASE" == true ]] && load_config "${CONF_DIR}/base/packages.conf"
}

read_package_state() {
    local line package
    while IFS= read -r line; do
        package="${line#package:}"; [[ -n "$package" ]] && INSTALLED["$package"]=1
    done < <(adb -s "$DEVICE_SERIAL" shell pm list packages --user 0 </dev/null | tr -d '\r')
    while IFS= read -r line; do
        package="${line#package:}"; [[ -n "$package" ]] && KNOWN["$package"]=1
    done < <(adb -s "$DEVICE_SERIAL" shell pm list packages -u --user 0 </dev/null | tr -d '\r')
    while IFS= read -r line; do
        package="${line#package:}"; [[ -n "$package" ]] && THIRD_PARTY["$package"]=1
    done < <(adb -s "$DEVICE_SERIAL" shell pm list packages -3 -u --user 0 </dev/null | tr -d '\r')
    while IFS= read -r line; do
        package="${line#package:}"; [[ -n "$package" ]] && SYSTEM["$package"]=1
    done < <(adb -s "$DEVICE_SERIAL" shell pm list packages -s -u --user 0 </dev/null | tr -d '\r')
    while IFS= read -r line; do
        package="${line#package:}"; [[ -n "$package" ]] && DISABLED["$package"]=1
    done < <(adb -s "$DEVICE_SERIAL" shell pm list packages -d --user 0 </dev/null | tr -d '\r')
}

in_profile_scope() {
    local package="$1"
    case "$PROFILE_SCOPE" in
        all) return 0 ;;
        third-party) [[ -n "${THIRD_PARTY[$package]+x}" ]] ;;
        system) [[ -n "${SYSTEM[$package]+x}" ]] ;;
        *) return 1 ;;
    esac
}

show_selection() {
    local package state count=0 considered=0
    echo; echo "Pacotes do perfil encontrados no aparelho:"
    while IFS= read -r package; do
        in_profile_scope "$package" || continue
        ((considered += 1))
        if [[ -n "${DISABLED[$package]+x}" ]]; then state="desativado"
        elif [[ -n "${INSTALLED[$package]+x}" ]]; then state="instalado"
        elif [[ -n "${KNOWN[$package]+x}" ]]; then state="removido para o usuario"
        else continue; fi
        printf '  %-65s %s\n' "$package" "$state"
        ((count += 1))
    done < <(printf '%s\n' "${!SELECTED[@]}" | sort)
    echo; echo "Total aplicavel: $count de $considered entradas no escopo $PROFILE_SCOPE."
    APPLICABLE_COUNT="$count"
}

package_enabled_state() {
    adb -s "$DEVICE_SERIAL" shell dumpsys package "$1" </dev/null |
        awk '/^[[:space:]]*User 0:.*[[:space:]]installed=true[[:space:]]/ {
            for (i = 1; i <= NF; i++)
                if ($i ~ /^enabled=[0-3]$/) print substr($i, 9)
        }'
}

run_action() {
    local package output confirmation state disable_output success=0 failed=0 skipped=0
    [[ "$ACTION" == "preview" ]] && return 0
    ((APPLICABLE_COUNT > 0)) || die "Nenhum pacote aplicavel foi encontrado."
    echo; echo "A acao '$ACTION' modificara o dispositivo $DEVICE_MODEL."
    read -r -p "Digite SIM para continuar: " confirmation
    [[ "$confirmation" == "SIM" ]] || die "Operacao cancelada."

    while IFS= read -r -u 3 package; do
        in_profile_scope "$package" || continue
        if [[ "$ACTION" == "restore" ]]; then
            [[ -n "${KNOWN[$package]+x}" ]] || { ((skipped += 1)); continue; }
        else
            [[ -n "${INSTALLED[$package]+x}" ]] || { ((skipped += 1)); continue; }
        fi
        if [[ "$ACTION" == "disable" && -n "${DISABLED[$package]+x}" ]]; then
            printf '[IGNORADO] %s: ja esta desativado\n' "$package"
            ((skipped += 1))
            continue
        fi
        case "$ACTION" in
            disable) output="$(adb -s "$DEVICE_SERIAL" shell pm disable-user --user 0 "$package" </dev/null 2>&1)" ;;
            uninstall) output="$(adb -s "$DEVICE_SERIAL" shell pm uninstall --user 0 "$package" </dev/null 2>&1)" ;;
            restore)
                output="$(adb -s "$DEVICE_SERIAL" shell cmd package install-existing --user 0 "$package" </dev/null 2>&1)"
                [[ "$output" == *Failure* ]] ||
                    adb -s "$DEVICE_SERIAL" shell pm enable --user 0 "$package" </dev/null >/dev/null 2>&1 || true
                ;;
        esac
        if [[ "$output" == *Success* || "$output" == Package*installed* || "$output" == *"new state:"* ]]; then
            printf '[OK] %s\n' "$package"; ((success += 1))
        else
            if [[ "$ACTION" == "uninstall" && "$PROFILE_LEVEL" == "system-reviewed" &&
                  ( "$package" == "com.amazon.appmanager" || "$package" == "com.payjoy.access" ) ]]; then
                state="$(package_enabled_state "$package")" || state=""
                case "$state" in
                    2|3)
                        printf '[IGNORADO] %s: ja desativado, continua instalado\n' "$package"
                        ((skipped += 1))
                        continue
                        ;;
                    0|1)
                        printf 'A desinstalacao de %s falhou: %s\n' "$package" "$output"
                        if read -r -p "Desativar $package? Digite SIM para confirmar: " confirmation &&
                           [[ "$confirmation" == "SIM" ]]; then
                            disable_output="$(adb -s "$DEVICE_SERIAL" shell pm disable-user --user 0 "$package" </dev/null 2>&1)"
                            state="$(package_enabled_state "$package")" || state=""
                            if [[ "$state" == 2 || "$state" == 3 ]]; then
                                printf '[OK] %s: desativado, continua instalado\n' "$package"
                                ((success += 1))
                                continue
                            fi
                            output="desinstalacao falhou: $output; desativacao nao confirmada: $disable_output"
                        fi
                        ;;
                esac
            fi
            printf '[FALHA] %s: %s\n' "$package" "$output"; ((failed += 1))
        fi
    done 3< <(printf '%s\n' "${!SELECTED[@]}" | sort)
    echo; echo "Resumo: $success sucesso(s), $failed falha(s), $skipped ignorado(s)."
    ((failed == 0))
}

main() {
    select_device; detect_device
    echo "Dispositivo: $DEVICE_MODEL"; echo "Android: $ANDROID_VERSION"
    echo "Fabricante detectado: ${DEVICE_VENDOR:-nao suportado}"
    choose_options; load_packages; read_package_state; show_selection; run_action
}

main "$@"
