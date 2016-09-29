#!/bin/bash 

#---------------------------------------------------------------------------------
# This script finds the pointing centers for all beam0 data and uses footprint.py 
# to derive pointing centers for all the other beams coresponding to a given 
# pointing phase center. 
# 
#   1.       mslist: derive the RA and Dec for the beam0 ms dataset. 
#   2. footprint.py: derives pointing centers for all other beams
#
#                                       --wr, 22 Dec 2015
#---------------------------------------------------------------------------------

if [ $# -lt 2 ];
then 
      echo "Usage: "
      echo "$0 <input msfile> <output beam pointing file>"
      exit 0 
else 
      echo "Finding RA Dec for: "$1
      outfile=$2
      echo "The pointing directions will be written to: "$outfile
fi
echo " "
nbeams=36 
mslist --full $1 2>mslist.tmp 
cat mslist.tmp | grep -A1 'Decl' |grep -v 'Decl' >radec.tmp
ra=`sed -n 1p radec.tmp |awk '{print $7}'`
dec=`sed -n 1p radec.tmp |awk '{print $8}'`

IFS=":"
ra_array=($ra)
rah=${ra_array[0]}
ram=${ra_array[1]}
ras=${ra_array[2]}
echo " RA: "$rah':'$ram':'$ras

IFS="."
dec_array=($dec)
decd=${dec_array[0]}
decm=${dec_array[1]}
decs=${dec_array[2]}
decss=${dec_array[3]}
unset IFS

echo " " 
echo "Dec: "$decd':'$decm':'$decs.$decss

# Get the values of RA and Dec for the other beams: 
#module load aces 
footprint.py -n closepack36 -b 2 -p 1.0 -a 0 -r "$rah:$ram:$ras,$decd:$decm:$decs.$decss" >footprint.tmp
cat footprint.tmp | grep -A$nbeams 'RA' |grep -v 'RA' >$outfile


# Test section for reading the output file: 
#IFS="()"
#for (( ibeam=0; ibeam<=8; ibeam++ ))
#do
#     nbeam=`echo $ibeam + 1 |bc`
#     radec=`sed -n $nbeam\p junk.tmp ` #|awk '{print $7}'`
#     array=($radec)
#     echo ${array[4]}
#     #echo $radec 
#done
