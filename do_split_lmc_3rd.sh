#!/bin/bash 

trial=0 # If >0, trial run only, else mpi will be executed.
sbid=1997 #1979 
path="/scratch2/askap/askapops/askap-scheduling-blocks/$sbid/"
#msdata="2016-09-02_222426.ms" #1979  
msdata="2016-09-04_145436.ms" #1997  
outpath=/scratch2/astronomy856/sbhandari/cass/DATA/$sbid/MSDATA_SPLIT/
mkdir -p $outpath 
slurmOutDir=slurmOutput
mkdir -p $slurmOutDir

bfield=0
efield=0
bbeam=0
ebeam=29

task=splitLMC3
source=LMC_02_T0-0
#================================================================================
for interleave in A B C
do
       #for (( ifield=$bfield;ifield<=$efield;ifield++ ))
       #do
	       #fieldname=$source\F$ifield$interleave
	       fieldname=$source$interleave
	       for (( ibeam=$bbeam;ibeam<=$ebeam;ibeam++ ))
	       do
	               # Name the file to be used as input by ASKAPsoft codes: 
	               parset=$task\_$fieldname\_bm-$ibeam.in
	               logfile=$task\_$fieldname\_bm-$ibeam
	               outmsfile=$fieldname\_bm-$ibeam.ms
		       slurmfile=$task\_$fieldname\_bm-$ibeam.sbatch
	               echo "
# Input measurement set
vis=$path$msdata
# Output measurement set
outputvis   = $outpath$outmsfile
channel     = 1-2592
# Select just a single beam for this obs
beams        = [$ibeam]
fieldnames   = [$fieldname]
#scans        = [$iscan]
# Set a larger bucketsize
stman.bucketsize  = 65536
stman.tilenchan   = 54
	" >$parset 
	               # Write the SlurmFile now: 
		       echo "#!/usr/bin/env bash
#SBATCH --partition=workq
#SBATCH --time=12:00:00
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --job-name=splitFieldBeam
#SBATCH --export=ASKAP_ROOT,AIPSPATH
#SBATCH --output=$slurmOutDir/$logfile-%j.out

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

#. /home/raj030/ACES/askapsoft/scripts/utils.sh
log=$logfile.\${SLURM_JOB_ID}.log

aprun -n 1 -N 1 mssplit -c ${parset} > \${log}
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


