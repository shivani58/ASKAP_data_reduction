#!/bin/bash 
trial=0 # If >0, trial run only, else mpi will be executed.
#sbid=1975 #Only 22 beams (0-21) seems to be okay! 
sbid=1995 #Only 30 beams (0-21) seems to be okay! 

bscan=0
escan=34
path=/scratch2/askap/askapops/askap-scheduling-blocks/$sbid/ 
#msdata="2016-09-02_091428.ms/" #Sbid: 1975
msdata="2016-09-04_072049.ms/"  #Sbid: 1995 
outpath=/scratch2/askap/raj030/LMC3/MSDATA_SPLIT/$sbid/
mkdir -p $outpath 

jobname=spl1934_$sbid

source=1934

task=split 

for (( iscan=$bscan;iscan<=$escan;iscan++ ))
do
	ibeam=$iscan  # Assunming i-th beam points to source during i-th scan 
	# Name the file to be used as input by ASKAPsoft codes: 
	parset=$task\_$source\_bm-$ibeam\_scan-$iscan.in
	logfile=$task\_$source\_bm-$ibeam\_scan-$iscan.log
	slurmfile=$task\_$source\_bm-$ibeam\_scan-$iscan.sbatch 

	outmsfile=$source\_bm-$ibeam\_scan-$iscan.ms
        slurmOutput=slurmOutput/ 
	mkdir -p $slurmOutput
	echo "
# Input measurement set
vis=$path$msdata
# Output measurement set
outputvis   = $outpath$outmsfile
channel     = 1-2592
# Select just a single beam for this obs
beams        = [$ibeam]
scans        = [$iscan]
# Set a larger bucketsize
stman.bucketsize  = 65536
stman.tilenchan   = 54
	" >$parset 
	# Write the SlurmFile
		       echo "#!/usr/bin/env bash
#SBATCH --partition=workq
#SBATCH --time=12:00:00
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --job-name=$jobname 
#SBATCH --export=ASKAP_ROOT,AIPSPATH
#SBATCH --output=$slurmOutput$logfile-%j.out

# Make a copy of this file for this instance of slurmJobId
slurmdir=Slurmfiles/$task
parsetdir=PARSETS/$task
logdir=LOGS/$task
# Incorporate a check if the directory already exists. If not, create it. 
mkdir -p \$slurmdir 
mkdir -p \$parsetdir 
mkdir -p \$logdir 

sedstr=\"s/sbatch/\${SLURM_JOB_ID}\.sbatch/g\"
cp -a $slurmfile \`echo $slurmfile | sed -e \$sedstr\`
mv \`echo $slurmfile | sed -e \$sedstr\` \$slurmdir/.

sedstr=\"s/in/\${SLURM_JOB_ID}\.in/g\"
cp -a $parset \`echo $parset | sed -e \$sedstr\`
mv \`echo $parset | sed -e \$sedstr\` \$parsetdir/.

log=$logfile.\${SLURM_JOB_ID}.log

aprun -n 1 -N 1 mssplit -c ${parset} > \${log}
err=\$?
extractStats \${log} \${SLURM_JOB_ID} $task\_${source}_bm-$ibeam "txt,csv"
mv \$log \$logdir/.
if [ \$err != 0 ]; then
	    exit \$err
fi
" >$slurmfile
	if [ $trial -gt 0 ] 
	then
		echo "This was a set-up only run. You may check your input parsets..." 
	else
		sbatch $slurmfile 
	fi
done

