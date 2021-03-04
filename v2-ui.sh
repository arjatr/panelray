#!/bin/bash


red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}error: ${plain}Este script debe ejecutarse como usuario root！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}versión del sistema, comuníquese con el autor del script！${plain}\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Utilice CentOS 7 o superior！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Utilice Ubuntu 16 o superior！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Utilice Debian 8 o superior！${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [defecto$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Ya sea para reiniciar el panel, reiniciar el panel también se reiniciará v2ray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Presione enter para regresar al menú principal: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/arjatr/panelray/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "Esta función reinstalará a la fuerza la última versión actual, los datos no se perderán, si continuar?" "n"
    if [[ $? != 0 ]]; then
        echo -e "${red}Cancelado{plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/arjatr/panelray/master/install.sh)
    if [[ $? == 0 ]]; then
        echo -e "${green}La actualización está completa y el panel se ha reiniciado automáticamente${plain}"
        exit
#        if [[ $# == 0 ]]; then
#            restart
#        else
#            restart 0
#        fi
    fi
}

uninstall() {
    confirm "¿Está seguro de que desea desinstalar el panel, v2ray también lo desinstalará?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop v2-ui
    systemctl disable v2-ui
    rm /etc/systemd/system/v2-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/v2-ui/ -rf
    rm /usr/local/v2-ui/ -rf
	rm /usr/bin/v2-ui -f
    echo ""
       echo -e "\033[0m\e[35m------------------------------------\033[1;37m"
	    echo -e "\033[0m\e[1;32m     SE desintalo con exto!"
	    echo -e "\033[0m\e[35m------------------------------------\033[1;37m"


    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "¿Está seguro de que desea restablecer el nombre de usuario y la contraseña a admin" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/v2-ui/v2-ui resetuser
    echo -e "El nombre de usuario y la contraseña se restablecieron a ${green} admin 
	${plain}. Reinicie el panel ahora."
    confirm_restart
}

reset_config() {
    confirm "
¿Está seguro de que desea restablecer todas las configuraciones del panel? 
Los datos de la cuenta no se perderán, el nombre de usuario y la contraseña no se cambiarán" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/v2-ui/v2-ui resetconfig
    echo -e "
Todos los paneles se han restablecido a los valores predeterminados, 
reinicie los paneles ahora y use el puerto predeterminado 
${green} 65432 ${plain} para acceder a los paneles"
    confirm_restart
}

set_port() {
    echo && echo -n -e "Ingrese el número de puerto[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        echo -e "${yellow}Cancelado${plain}"
        before_show_menu
    else
        /usr/local/v2-ui/v2-ui setport ${port}
        echo -e "Después de configurar el puerto, reinicie el panel y use el puerto recién configurado
		${green} ${port} ${plain} para acceder al panel"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}El panel ya se está ejecutando, no es necesario comenzar de nuevo,
 si necesita reiniciar, seleccione reiniciar${plain}"
    else
        systemctl start v2-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}v2-ui Inicio exitoso${plain}"
        else
            echo -e "${red}El panel no pudo iniciarse. Puede deberse a que la hora de inicio supera los dos segundos.
			Verifique la información de registro más tarde.${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        echo -e "${green}El panel se ha detenido, no es necesario volver a parar${plain}"
    else
        systemctl stop v2-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            echo -e "${green}v2-ui Detener con v2ray con éxito${plain}"
        else
            echo -e "${red}El panel no se detuvo. Puede deberse a que el tiempo de parada supera los dos segundos.
 Verifique la información de registro más tarde.${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart v2-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}v2-ui v2ray Reinicio exitoso${plain}"
    else
        echo -e "${red}El reinicio del panel falló, 
		puede deberse a que el tiempo de inicio supera los dos segundos,
		verifique la información de registro más tarde${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status v2-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable v2-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}v2-ui Configure el inicio automático de encendido correctamente${plain}"
    else
        echo -e "${red}v2-ui No se pudo configurar el inicio automático después del inicio${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable v2-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}v2-ui Cancelar el inicio automático de encendido con éxito${plain}"
    else
        echo -e "${red}v2-ui Cancelar falla de inicio${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    echo && echo -n -e "Es posible que se generen muchos registros de ADVERTENCIA durante el uso del panel.
	Si no hay ningún problema con el uso del panel, no hay problema.
	Presione Enter para continuar: " && read temp
    tail -500f /etc/v2-ui/v2-ui.log
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/sprov065/blog/master/bbr.sh)
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}instalación bbr 成功${plain}"
    else
        echo ""
        echo -e "${red}下No se pudo cargar el script de instalación de bbr,
		verifique si la máquina se puede conectarGithub${plain}"
    fi

    before_show_menu
}

update_shell() {
    wget -O /usr/bin/v2-ui -N --no-check-certificate https://raw.githubusercontent.com/arjatr/panelray/master/v2-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}No se pudo cargar el script,
 verifique si la máquina se puede conectar${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/v2-ui
        echo -e "${green}La secuencia de comandos de actualización se ha realizado correctamente.
 Vuelva a ejecutar la secuencia de comandos.${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/v2-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status v2-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled v2-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}El panel se ha instalado, no lo instale repetidamente${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Primero instale el panel${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Estado del panel: ${green}se está ejecutando{plain}"
            show_enable_status
            ;;
        1)
            echo -e "Estado del panel: ${yellow}No corriendo{plain}"
            show_enable_status
            ;;
        2)
            echo -e "Estado del panel: ${red}No está instalado{plain}"
    esac
    show_v2ray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Ya sea para comenzar automáticamente después de arrancar: ${green}Es{plain}"
    else
        echo -e "Ya sea para comenzar automáticamente después de arrancar: ${red}No{plain}"
    fi
}

check_v2ray_status() {
    count=$(ps -ef | grep "v2ray-v2-ui" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_v2ray_status() {
    check_v2ray_status
    if [[ $? == 0 ]]; then
        echo -e "v2ray estado: ${green}Ejecutar${plain}"
    else
        echo -e "v2ray estado: ${red}No corras${plain}"
    fi
}



show_menu() {

echo -e "\033[1;32m[00]\033[1;31m|> \033[1;33mSalir de la secuencia de comandos"
echo -e "\033[1;32m[01]\033[1;31m|> \033[1;33minstalar v2-ui"
echo -e "\033[1;32m[02]\033[1;31m|> \033[1;33mactualización v2-ui"
echo -e "\033[1;32m[03]\033[1;31m|> \033[1;33mdesinstalar v2-ui"
echo -e "\033[1;32m[04]\033[1;31m|> \033[1;33mRestablecer nombre de usuario y contraseña"
echo -e "\033[1;32m[05]\033[1;31m|> \033[1;33mRestablecer la configuración del panel"
echo -e "\033[1;32m[06]\033[1;31m|> \033[1;33mEstablecer el puerto del panel"
echo -e "\033[1;32m[07]\033[1;31m|> \033[1;33mstart v2-ui"
echo -e "\033[1;32m[08]\033[1;31m|> \033[1;33mstop v2-ui"
echo -e "\033[1;32m[09]\033[1;31m|> \033[1;33mreiniciar v2-ui"
echo -e "\033[1;32m[10]\033[1;31m|> \033[1;33mVer estado v2-ui"
echo -e "\033[1;32m[11]\033[1;31m|> \033[1;33mVer registro v2-ui"
echo -e "\033[1;32m[12]\033[1;31m|> \033[1;33mconfigura v2-ui para que se inicie automáticamente después de arrancar"
echo -e "\033[1;32m[13]\033[1;31m|> \033[1;33mCancelar el arranque v2-ui desde el principio"
echo -e "\033[1;32m[014]\033[1;31m|> \033[1;33mInstalación con un clic de bbr (el último kernel)"


    show_status
    echo && read -p "Por favor ingrese la selección [0-14]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && reset_user
        ;;
        5) check_install && reset_config
        ;;
        6) check_install && set_port
        ;;
        7) check_install && start
        ;;
        8) check_install && stop
        ;;
        9) check_install && restart
        ;;
        10) check_install && status
        ;;
		12) check_install && enable
        ;;
        13) check_install && disable
        ;;
        14) install_bbr
        ;;
        *) echo -e "${red}Ingrese el número correcto [0-14]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        *) show_usage
    esac
else
    show_menu
fi
