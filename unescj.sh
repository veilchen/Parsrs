#!/bin/sh

######################################################################
#
# UNESCJ.SH
#   A Unicode Escape Sequence Decoder for JSON
#
# === What is This? ===
# * This command converts Unicode escape sequence strings to UTF-8.
# * But the command is a converter not for original JSONs but for
#   beforehand extracted strings from JSONs.
# * Basically, this command is for the text data (JSONPath-value) after
#   converting by "parsrj.sh" command.
# * When you convert JSONPath-value, you have to use "-n" option to
#   avoid being broken as a JSONPath-value format by being inserted into
#   <0x0A>s which has been converted from "\ux000a"s.
#
# === Usage ===
# Usage: unescj.sh [-n] [JSONPath-value_textfile]
#
#
# Written by 321516 (@shellshoccarjpn) / 2017-01-27 14:53:31 JST
#
# This is a public-domain software (CC0). It measns that all of the
# people can use this for any purposes with no restrictions at all.
# By the way, I am fed up the side effects which are broght about by
# the major licenses.
#
######################################################################


######################################################################
# Initial configuration
######################################################################

# === Initialize shell environment ===================================
set -eu
export LC_ALL=C
export PATH="$(command -p getconf PATH):${PATH:-}"

# === Usage printing function ========================================
print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage : ${0##*/} [-n] [JSONPath-value_textfile]
	2017-01-29 16:08:12 JST
	USAGE
  exit 1
}


######################################################################
# Prepare for the Main Routine
######################################################################

# === Define some chrs. to escape some special chrs. temporarily =====
BS=$( printf '\010' )              # Back Space
TAB=$(printf '\011' )              # Tab
LFs=$(printf '\\\n_');LFs=${LFs%_} # Line Feed (for sed command)
FF=$( printf '\014' )              # New Pafe (Form Feed)
CR=$( printf '\015' )              # Carridge Return
ACK=$(printf '\006' )              # Escape chr. for "\\"

# === Get the options and the filepath ===============================
nopt=0
case "$#" in [!0]*) case "$1" in '-n') nopt=1;shift;; esac;; esac
case "$#" in
  0) file='-'
     ;;
  1) if [ -f "$1" ] || [ -c "$1" ] || [ -p "$1" ] || [ "_$1" = '_-' ]; then
       file=$1
     fi
     ;;
  *) print_usage_and_exit
     ;;
esac


######################################################################
# Main Routine (Convert and Generate)
######################################################################

# === Open the data source =================================================== #
cat "$file"                                                                    |
#                                                                              #
# === Escape "\\" to ACK temporarily ========================================= #
sed 's/\\\\/'"$ACK"'/g' 2>/dev/null                                            |
#                                                                              #
# === Mark the original <0x0A> with <0x0A>+"\N" after it ===================== #
sed 's/$/'"$LFs"'\\N/'                                                         |
#                                                                              #
# === Insert <0x0A> into the behind of "\uXXXX" ============================== #
sed 's/\(\\u[0-9A-Fa-f]\{4\}\)/'"$LFs"'\1/g'                                   |
#                                                                              #
# === Unescape "\uXXXX" into UTF-8 =========================================== #
#     (But the following ones are transfer the following strings               #
#      \u000a -> \n, \u000d -> \r, \u005c -> \\, \u0000 -> \0, \u0006 -> \A)   #
awk '                                                                          #
BEGIN {                                                                        #
  OFS=""; ORS="";                                                              #
  for(i=255;i>0;i--) {                                                         #
    s=sprintf("%c",i);                                                         #
    bhex2chr[sprintf("%02x",i)]=s;                                             #
    bhex2int[sprintf("%02x",i)]=i; # (a)                                       #
  }                                                                            #
  bhex2chr["00"]="\\0" ;                                                       #
  bhex2chr["06"]="\\A" ;                                                       #
  bhex2chr["0a"]="\\n" ;                  # Both (a) and (b) are also the      #
  bhex2chr["0d"]="\\r" ;                  # transferring table from a 2 bytes  #
  bhex2chr["5c"]="\\\\";                  # of hex number to a decimal one.    #
  #for(i=65535;i>=0;i--) {          # (b) # (a) is to use 256 keys twice. (b)  #
  #  whex2int[sprintf("%02x",i)]=i; #  :  # is to use 65536 keys once. And (a) #
  #}                                #  :  # was a litter faster than (b).      #
                                                                               #
  while (getline l) {                                                          #
    if (l=="\\N") {print "\n"; continue; }                                     #
    if (match(l,/^\\u00[0-7][0-9a-fA-F]/)) {                                   #
      print bhex2chr[tolower(substr(l,5,2))], substr(l,7);                     #
      continue;                                                                #
    }                                                                          #
    if (match(l,/^\\u0[0-7][0-9a-fA-F][0-9a-fA-F]/)) {                         #
      #i=whex2int[tolower(substr(l,3,4))]; # <-(a) V(b)                        #
      i=bhex2int[tolower(substr(l,3,2))]*256+bhex2int[tolower(substr(l,5,2))]; #
      printf("%c%c",192+int(i/64),128+i%64);                                   #
      print substr(l,7);                                                       #
      continue;                                                                #
    }                                                                          #
    if (match(l,/^\\u[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]/)) {         #
      #i=whex2int[tolower(substr(l,3,4))]; # <-(a) V(b)                        #
      i=bhex2int[tolower(substr(l,3,2))]*256+bhex2int[tolower(substr(l,5,2))]; #
      printf("%c%c%c",224+int(i/4096),128+int((i%4096)/64),128+i%64);          #
      print substr(l,7);                                                       #
      continue;                                                                #
    }                                                                          #
    print l;                                                                   #
  }                                                                            #
}'                                                                             |
# === Unsscape escaped strings except "\n", "\0" and "\\" ==================== #
sed 's/\\"/"/g'                                                                |
sed 's/\\\//\//g'                                                              |
sed 's/\\b/'"$BS"'/g'                                                          |
sed 's/\\f/'"$FF"'/g'                                                          |
sed 's/\\r/'"$CR"'/g'                                                          |
sed 's/\\t/'"$TAB"'/g'                                                         |
#                                                                              #
# === Also unescape "\0", "\n", "\\" when "-n" option is not given =========== #
case "$nopt" in                                                                #
  0) sed 's/\\0//g'                             |  # - "\0" should be deleted  #
     sed 's/\\n/'"$LFs"'/g'                     |  #   without conv to <0x00>  #
     sed 's/'"$ACK"'/\\\\/g'                    |  # - Unescaoe escaped "\\"s  #
     sed 's/\([^\\]\(\\\\\)*\)\\A/\1'"$ACK"'/g' |  #   and then restore "\A"s  #
     sed 's/\([^\\]\(\\\\\)*\)\\A/\1'"$ACK"'/g' |  #   to <ACK>s               #
     sed 's/^\(\(\\\\\)*\)\\A/\1'"$ACK"'/g'     |  #   :                       #
     sed 's/\\\\/\\/g'                          ;; # - Unescape "\\"s into "\"s#
  *) sed 's/'"$ACK"'/\\\\/g'                    |                              #
     sed 's/\([^\\]\(\\\\\)*\)\\A/\1'"$ACK"'/g' |                              #
     sed 's/\([^\\]\(\\\\\)*\)\\A/\1'"$ACK"'/g' |                              #
     sed 's/^\(\(\\\\\)*\)\\A/\1'"$ACK"'/g'     ;;                             #
esac
