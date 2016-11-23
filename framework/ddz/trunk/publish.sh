#!/bin/bash
#===============================================================================
#      FILENAME: publish.sh
#
#   DESCRIPTION: ---
#         NOTES: ---
#        AUTHOR: leoxiang, xiangkun@ximigame.com
#       COMPANY: XiMi Co.Ltd
#      REVISION: 2014-12-31 by leoxiang
#===============================================================================

function usage
{
  echo "./publish [name]"
  exit
}

PATH="$(dirname $0)/lbf/lbf:$PATH"
source lbf_init.sh

[ "$1" = "" ] && usage

echo "please select which to pack: "
echo "0)  all-packs"
echo "1)  logindbsvrd"
echo "2)  loginsvrd"
echo "3)  gatesvrd"
echo "4)  roomsvrd"
echo "5)  datadbsvrd"
echo "6)  tablestatesvrd"
echo "7)  httpsvrd"
echo "8)  logsvrd"
echo "9)  globaldbsvrd"
echo "10) gmsvrd"
echo "11) rechargesvrd"
echo "12) rechargedbsvrd"
echo "13) dbtool"
echo "14) proto"
echo "15) config"
echo "16) corecommon"
echo "17) common"




read -p "please select which to pack: " var_select_list

var_pack_list=""
var_common_path="../../common/"
var_luac_path="../../common/skynet/3rd/lua/luac"
var_tmp_path="../tmp"
if [ ! -d $var_tmp_path ]; then
  `mkdir $var_tmp_path`
fi
var_pwd=`pwd`
echo "Current Path:"$var_pwd
var_pro_tmp=`dirname $var_pwd`
trunk_dir=`basename $var_pwd`
project_dir=`basename $var_pro_tmp`
echo "Project:"$project_dir
echo "Trunk:"$trunk_dir



for _var_select in ${var_select_list}; do
  case ${_var_select} in
    0)  echo "copy ../../common ...."
        `cp -r $var_common_path $var_tmp_path`
        echo "compile lua-script............"
        Luas=`find ${var_tmp_path} -name *.lua`
        for line in ${Luas};
        do
            `$var_luac_path -o $line $line`
            echo $line
        done
        ;;
    *)  echo "unknown tpye ${_var_select}"; exit 0;;
  esac
done

#echo "================="
#echo "delete privious files"
#var_dir="../package"
#svn up  ${var_dir} --accept theirs-full
#svn revert ${var_dir} -R
#svn del ${var_dir}/* --force
#
#echo "================="
#echo "begin pack"
#var_file="${var_dir}/texas_$1_$(date '+%Y%m%d%H%M%S').zip"
#zip -r ${var_file} ${var_pack_list} --exclude \*.svn\*
#
#echo "================="
#echo "calc md5"
#echo http://insvn.ximigame.net/svn/serversvn/codebase/games/texas/package/$(basename ${var_file})
#md5sum ${var_file}
#
#echo "================="
#echo "upload svn"
#svn add ${var_file}
#svn ci  ${var_dir} -m "texas package ${var_file}"
#
## vim:ts=2:sw=2:et:
#`rm -rf ../tmp`
