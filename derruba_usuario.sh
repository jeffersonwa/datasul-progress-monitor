#!/bin/bash
#***************************************************************************
# File..................: derruba_usuario.sh
# Description...........: Listar e derrubar usuarios Progress por banco
# Baseado em............: script original Robson Muniz (2014)
#***************************************************************************

tput clear
export DLC=/usr/dlc128
export PATH=$DLC/bin:$PATH

BANCOS="dtviewer eai ems2adt ems2cad ems2mov ems2mp ems5cad ems5mov emsdes emsfnd emsinc hcm"
DB_DIR=/bancos/DATABASE-JA-8380

echo "==========================================="
echo "  GERENCIADOR DE USUARIOS PROGRESS - 8380  "
echo "==========================================="
echo ""
echo "Opcoes:"
echo "  1) Listar todos os usuarios conectados"
echo "  2) Derrubar usuario pelo nome"
echo "  3) Derrubar todos os usuarios de um banco"
echo ""
echo -n "Escolha [1/2/3]: "
read opcao

listar_usuarios() {
    echo ""
    echo "=== USUARIOS CONECTADOS ==="
    printf "%-12s %-6s %-20s %-20s %s\n" "BANCO" "USR#" "USUARIO" "WORKSTATION" "HORA"
    echo "--------------------------------------------------------------------------------------------"
    for db in $BANCOS; do
        [ ! -f $DB_DIR/${db}.db ] && continue
        _mprshut $DB_DIR/$db -C list 2>/dev/null | while read line; do
            usr=$(echo "$line" | awk '{print $1}')
            nome=$(echo "$line" | awk '{print $2}')
            ws=$(echo "$line" | awk '{print $3}')
            hora=$(echo "$line" | awk '{print $4, $5}')
            [ -z "$usr" ] && continue
            printf "%-12s %-6s %-20s %-20s %s\n" "$db" "$usr" "$nome" "$ws" "$hora"
        done
    done
    echo ""
}

derrubar_por_nome() {
    echo -n "Nome do usuario a derrubar: "
    read usuario
    [ -z "$usuario" ] && echo "Nome invalido." && exit 1
    > /tmp/desconectados
    for db in $BANCOS; do
        [ ! -f $DB_DIR/${db}.db ] && continue
        echo "  Verificando $db..."
        _mprshut $DB_DIR/$db -C list 2>/dev/null | grep -i "$usuario" > /tmp/res.txt
        awk -v db="$DB_DIR/$db" '{print "_mprshut " db " -C disconnect " $1}' /tmp/res.txt >> /tmp/desconectados
    done
    if [ ! -s /tmp/desconectados ]; then
        echo "Nenhuma sessao encontrada para: $usuario"
    else
        echo ""
        echo "Derrubando sessoes de '$usuario'..."
        sh /tmp/desconectados && echo "OK: usuario $usuario desconectado." || echo "ERRO ao desconectar."
    fi
}

derrubar_banco() {
    echo "Bancos disponiveis: $BANCOS"
    echo -n "Nome do banco: "
    read db
    [ ! -f $DB_DIR/${db}.db ] && echo "Banco $db nao encontrado." && exit 1
    echo "Listando usuarios em $db..."
    _mprshut $DB_DIR/$db -C list 2>/dev/null | awk -v db="$DB_DIR/$db" '{print "_mprshut " db " -C disconnect " $1}' > /tmp/desconectados_banco
    if [ ! -s /tmp/desconectados_banco ]; then
        echo "Nenhum usuario conectado em $db."
    else
        echo "Derrubando todos os usuarios de $db..."
        sh /tmp/desconectados_banco && echo "OK: todos os usuarios de $db desconectados."
    fi
}

case $opcao in
    1) listar_usuarios ;;
    2) listar_usuarios; derrubar_por_nome ;;
    3) listar_usuarios; derrubar_banco ;;
    *) echo "Opcao invalida." ;;
esac
