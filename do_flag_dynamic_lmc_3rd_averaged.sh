#!/bin/bash 

trial=0 # If >0, trial run only, else mpi will be executed.
sbid=1997 
path=/scratch2/astronomy856/sbhandari/cass/DATA/$sbid/MSDATA_SPLIT/BPCAL/FLAGGED_DYNAMIC/AVERAGED/
flaggedpath=/scratch2/astronomy856/sbhandari/cass/DATA/$sbid/MSDATA_SPLIT/BPCAL/FLAGGED_DYNAMIC/AVERAGED/FLAGGED_DYNAMIC/
#flaggedpath=JUNK/
# Incorporate a check if the flagged directory already exists. If not, create it. 
mkdir -p $flaggedpath 

bfield=0
efield=0
bbeam=0
ebeam=29

task=cflag_dynamic_avg
jobname=flgDyn
source=LMC_02_T0-0
for interleave in A B C
do
       #for (( ifield=$bfield;ifield<=$efield;ifield++ ))
       #do
	       #fieldname=$source\F$ifield$interleave
	       fieldname=$source$interleave
	       for (( ibeam=$bbeam;ibeam<=$ebeam;ibeam++ ))
	       do
		       jobname=flgDyn$ibeam$interleave
	               # Name the file to be used as input by ASKAPsoft codes: 
	               parset=$task\_$fieldname\_bm-$ibeam.in
	               logfile=$task\_$fieldname\_bm-$ibeam
	               msfile=$fieldname\_bm-$ibeam.ms
		       slurmfile=$task\_$fieldname\_bm-$ibeam.sbatch
                       # Remove an old flagged file and start afresh from the raw: 
                       #rm -rf $flaggedpath$msfile
                       #cp -a $path$msfile $flaggedpath.
	               echo "
# Input measurement set
Cflag.dataset                           = $flaggedpath$msfile 

# Amplitude based flagging with dynamic thresholds
#  This finds a statistical threshold in the spectrum of each
#  time-step, then applies the same threshold level to the integrated
#  spectrum at the end.
Cflag.amplitude_flagger.enable           = true
Cflag.amplitude_flagger.dynamicBounds    = true
Cflag.amplitude_flagger.threshold        = 4.0
Cflag.amplitude_flagger.integrateSpectra = true
Cflag.amplitude_flagger.integrateSpectra.threshold = 4.0

# The following flags out the requested antennas:
Cflag.selection_flagger.rules           = [rule2]
Cflag.selection_flagger.rule2.autocorr   = true
#Cflag.selection_flagger.rule3.timerange   = 2016/08/17/04:45:00.0~2016/08/17/05:00:00.0 
#Cflag.selection_flagger.rule1.antenna   = ak01&&ak03
Cflag.stokesv_flagger.enable               = true
Cflag.stokesv_flagger.threshold            = 4.0 
Cflag.stokesv_flagger.useRobustStatistics  = true
Cflag.stokesv_flagger.integrateSpectra            = false
Cflag.stokesv_flagger.integrateSpectra.threshold  = 4.0 
Cflag.stokesv_flagger.integrateTimes              = true 
Cflag.stokesv_flagger.integrateTimes.threshold    = 4.0 

	" >$parset 
	               # Write the SlurmFile now: 
		       echo "#!/usr/bin/env bash
#SBATCH --partition=workq
#SBATCH --time=2:00:00
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --job-name=$jobname
#SBATCH --export=ASKAP_ROOT,AIPSPATH
#SBATCH --output=slurmOutput/$logfile-%j.out

rm -rf $flaggedpath$msfile
cp -a $path$msfile $flaggedpath.
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

aprun -n 1 -N 1 cflag -c ${parset} > \${log}
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
#	done
done


