#!/bin/bash 

trial=0 # If >0, trial run only, else mpi will be executed.
sbid=1997 #1979 
path=/scratch2/astronomy856/sbhandari/cass/DATA/$sbid/MSDATA_SPLIT/ #FLAGGED_DYNAMIC/ 
outpath=/scratch2/astronomy856/sbhandari/cass/DATA/$sbid/MSDATA_SPLIT/BPCAL/ 
# Incorporate a check if the flagged directory already exists. If not, create it. 
mkdir -p $outpath 
slurmOutDir=slurmOutput/
mkdir -p $slurmOutDir

nbeams=30 
bfield=0
efield=0
bbeam=0
ebeam=29 #21

task=ccalapply
#bpcal_file=BPCAL_SOLUTIONS/1975/cbpcal_1934_bm0-bm21_bp.tab
bpcal_file=/scratch2/astronomy856/sbhandari/cass/WORK/cbpcal_1934_bm0-bm29_bp.tab

source=LMC_02_T0-0 
for interleave in A B C
do
       #for (( ifield=$bfield;ifield<=$efield;ifield++ ))
       #do
	       #fieldname=$source\F$ifield$interleave
	       fieldname=$source$interleave
	       for (( ibeam=$bbeam;ibeam<=$ebeam;ibeam++ ))
	       do
		       jobname=bpcalApp$ibeam$interleave
		       iscan=$ibeam 
	               # Name the file to be used as input by ASKAPsoft codes: 
	               parset=$task\_$fieldname\_bm-$ibeam.in
	               logfile=$task\_$fieldname\_bm-$ibeam
	               msfile=$fieldname\_bm-$ibeam.ms
		       slurmfile=$task\_$fieldname\_bm-$ibeam.sbatch
                       # Remove an old flagged file and start afresh from the raw: 
		       # Put these rm/cp command inside the sbatch file to enhance speed 
                       #rm -rf $outpath$msfile
                       #cp -a $path$msfile $outpath.
	               echo "
# Input measurement set
# Default: <no default>
Ccalapply.dataset                         = $outpath$msfile
#
# Allow flagging of vis if inversion of Mueller matrix fails
Ccalapply.calibrate.allowflag             = true
#
Ccalapply.calibaccess                     = table
Ccalapply.calibaccess.table.maxant        = 12
Ccalapply.calibaccess.table.maxbeam       = $nbeams
Ccalapply.calibaccess.table.maxchan       = 2592
Ccalapply.calibaccess.table               = $bpcal_file 
	" >$parset 
	               # Write the SlurmFile now: 
		       echo "#!/usr/bin/env bash
#SBATCH --partition=workq
#SBATCH --time=12:00:00
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --job-name=$jobname
#SBATCH --export=ASKAP_ROOT,AIPSPATH
#SBATCH --output=$slurmOutDir$logfile-%j.out

# Make a copy of this file for this instance of slurmJobId
slurmdir=Slurmfiles/$task
parsetdir=PARSETS/$task
logdir=LOGS/$task

mkdir -p \$slurmdir
mkdir -p \$parsetdir
mkdir -p \$logdir 

# Remove an old flagged file and start afresh from the raw: 
rm -rf $outpath$msfile
cp -a $path$msfile $outpath.

sedstr=\"s/sbatch/\${SLURM_JOB_ID}\.sbatch/g\"
cp -a $slurmfile \`echo $slurmfile | sed -e \$sedstr\`
mv \`echo $slurmfile | sed -e \$sedstr\` \$slurmdir/.

sedstr=\"s/in/\${SLURM_JOB_ID}\.in/g\"
cp -a $parset \`echo $parset | sed -e \$sedstr\`
mv \`echo $parset | sed -e \$sedstr\` \$parsetdir/.

log=$logfile.\${SLURM_JOB_ID}.log

aprun -n 1 -N 1 ccalapply -c ${parset} > \${log}
err=\$?
extractStats \${log} \${SLURM_JOB_ID} $task\_${fieldname}_bm-$ibeam "txt,csv"
mv \$log \$logdir/.
if [ \$err != 0 ]; then
	    exit \$err
fi
" >$slurmfile
		       if [ $trial -gt 0 ]
		       then
			       echo "This was a set-up only run". Check your parsets now...
		       else
			       sbatch $slurmfile
		       fi
	       done
	#done
done


