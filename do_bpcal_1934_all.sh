#!/bin/bash 
trial=0 # If >0, trial run only, else mpi will be executed.
bscan=0
escan=29
sbid=1995 #1975
path=/scratch2/askap/raj030/LMC3/MSDATA_SPLIT/$sbid/FLAGGED_DYNAMIC/

nbeams=30  
task=cbpcal
jobname=bpcalib_$sbid

nranks_cbpcal=1826

source=1934
# Currently cbpcalibrator requires all 9 beams to be specified in the dataset parameter 
# using comma separated lists. However it will write out a single bp-table for all beams. 
# In the following loop, we generate the string variable containing comma-separated list 
# of all the 9 datasets for the 9 beams:  
msdata=" ]" # initialise msdata 
for (( iscan=$escan;iscan>=$bscan+1;iscan-- ))
do
	ibeam=$iscan  # Assunming i-th beam points to source during i-th scan 
	# Name the file to be used as input by ASKAPsoft codes: 
	msdata=", "$path$source\_bm-$ibeam\_scan-$iscan.ms$msdata
done

iscan=$bscan 
ibeam=$bscan
msdata="[ "$path$source\_bm-$ibeam\_scan-$iscan.ms$msdata

parset=$task\_$source\_bm$bscan-bm$escan.in
logfile=$task\_$source\_bm$bscan-bm$escan.log
slurmfile=$task\_$source\_bm$bscan-bm$escan.sbatch

outbptab=cbpcal_$source\_bm$bscan-bm$escan\_bp.tab
slurmOutput=slurmOutput/
mkdir -p $slurmOutput 

echo "Finding BandPass solutions for beams: $beam , using $msdata" 
echo " "
echo $outbptab 

	echo "
# Input measurement set
Cbpcalibrator.dataset                         = $msdata
Cbpcalibrator.nAnt                            = 12
Cbpcalibrator.nBeam                           = $nbeams
Cbpcalibrator.nChan                           = 2592
Cbpcalibrator.refantenna                      = 2
#
Cbpcalibrator.calibaccess                     = table
Cbpcalibrator.calibaccess.table.maxant        = 12
Cbpcalibrator.calibaccess.table.maxbeam       = $nbeams
Cbpcalibrator.calibaccess.table.maxchan       = 2592
Cbpcalibrator.calibaccess.table               = $outbptab
#
Cbpcalibrator.sources.names                   = [field1]
Cbpcalibrator.sources.field1.direction        = [19h39m25.036, -63.42.45.63, J2000]
Cbpcalibrator.sources.field1.components       = src
Cbpcalibrator.sources.src.calibrator          = 1934-638
#
Cbpcalibrator.gridder                         = SphFunc
#
Cbpcalibrator.ncycles                         = 25
	" >$parset 


	# Write the SlurmFile
		       echo "#!/usr/bin/env bash
#SBATCH --partition=workq
#SBATCH --time=12:00:00
#SBATCH --ntasks=$nranks_cbpcal  
#SBATCH --ntasks-per-node=20 
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

aprun -n $nranks_cbpcal -N 20 cbpcalibrator -c ${parset} > \${log}
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



