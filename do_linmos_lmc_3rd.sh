#!/bin/bash 
# Modifications made: 
#    + iter-4 from SBID 1206, all iteratios from SBID 1207 
#    

trial=0 # If >0, trial run only, else mpi will be executed.
sbid=1997 #1979
#sbid2=1997
path=/scratch2/astronomy856/sbhandari/cass/DATA/$sbid/MSDATA_SPLIT/BPCAL/FLAGGED_DYNAMIC/AVERAGED/FLAGGED_DYNAMIC/IMAGE_BM-21_LARGE/
#path=IMAGE_BFMFS/
#path2=/scratch2/askap/raj030/LMC3/IMAGE_NMAJ5/$sbid2/

clean_scheme=HOGBOM

#outpath=/scratch2/askap/raj030/LMC3/IMAGE/$sbid/LINMOS/
outpath=/scratch2/astronomy856/sbhandari/cass/DATA/$sbid/MSDATA_SPLIT/BPCAL/FLAGGED_DYNAMIC/AVERAGED/FLAGGED_DYNAMIC/IMAGE_BM-21_LARGE/LINMOS/
#outpath=LINMOS/HOGBOM_BFMFS_LAST_ITER/$sbid/ 
mkdir -p $outpath

bfield=0
efield=0
bbeam=0
ebeam=29

task_slurm=linmos
logfile=$task_slurm

nranks_linmos=1
# Self cal loops: 
niter=4 
bloop=0 
eloop=$niter 

source=LMC_02_T0-0
# Choose the imager you wish to use: 
linmos=linmos 
task=linmosLMC 
#imager=/work/raj030/ASKAPsoft/Code/Components/Synthesis/synthesis/current/apps/cimager.sh 
#calib=/work/raj030/ASKAPsoft/Code/Components/Synthesis/synthesis/current/apps/ccalibrator.sh 
#selavy=/work/raj030/ASKAPsoft/Code/Components/Analysis/analysis/current/apps/selavy.sh

for ((iloop=$bloop;iloop<=$eloop;iloop++))
do 
	job_name=$task_slurm\-$iloop
	slurmfile=$task_slurm\_$source\iter-$iloop.sbatch
	mkdir -p slurmOutput
	parset_linmos=$task\_$source\iter-$iloop.in 
	logfile_linmos=$task\_$source\iter-$iloop.log  
	outname=$outpath\image.i.$source\iter-$iloop.$task\_$clean_scheme_$sbid
	outweight=$outpath\weight.i.$source\iter-$iloop.$task\_$clean_scheme_$sbid
	# Write the parset file: 
	echo "# Parameters for $task 
linmos.outname = $outname 
linmos.outweight = $outweight 
linmos.weighttype = FromPrimaryBeamModel
linmos.weightstate = inherent #corrected
linmos.cutoff = 0.2
        " >$parset_linmos 
	# ===============================================================
	# We will start with our slurmfile here: 
        # (Just the set-up/definition bit here)
	# Write the SlurmFile now: 
        # Write the SlurmFile now: 
        echo "#!/usr/bin/env bash
#SBATCH --partition=workq
#SBATCH --time=12:00:00
#SBATCH --ntasks=$nranks_linmos 
#SBATCH --ntasks-per-node=1
#SBATCH --job-name=$job_name
#SBATCH --export=ASKAP_ROOT,AIPSPATH
#SBATCH --output=slurmOutput/$logfile-%j.out

# Make a copy of this file for this instance of slurmJobId
slurmdir=Slurmfiles/$task_slurm 
parsetdir=PARSETS/$task_slurm 
logdir=LOGS/$task_slurm 
# Incorporate a check if the directory already exists. If not, create it. 
mkdir -p \$slurmdir 
mkdir -p \$parsetdir 
mkdir -p \$logdir 

sedstr=\"s/sbatch/\${SLURM_JOB_ID}\.sbatch/g\"
cp -a $slurmfile \`echo $slurmfile | sed -e \$sedstr\`
mv \`echo $slurmfile | sed -e \$sedstr\` \$slurmdir/.


sedstr=\"s/in/\${SLURM_JOB_ID}\.in/g\"
cp -a $parset_linmos \`echo $parset_linmos | sed -e \$sedstr\`
mv \`echo $parset_linmos | sed -e \$sedstr\` \$parsetdir/.
log=$logfile_linmos.\${SLURM_JOB_ID}.log

aprun -n $nranks_linmos -N 1 $linmos -c ${parset_linmos} > \${log}
mv \$log \$logdir/.

err=\$?
extractStats \${log} \${SLURM_JOB_ID} ${task_slurm}_${source}iter-${iloop} \"txt,csv\"
if [ \$err != 0 ]; then
	exit \$err
fi
		               " >$slurmfile
	# Initialise the inname parameter: 
	inname='[ '
	delim=','

        for interleave in A B C
        do
               for (( ifield=$bfield;ifield<=$efield;ifield++ ))
               do
 	               #fieldname=$source\F$ifield$interleave
 	               fieldname=$source$interleave
  	               for (( ibeam=$bbeam;ibeam<=$ebeam;ibeam++ ))
 	               do
			       ## avoid the beam with failed imaging: F2A_BM-6
			       ##if ( [ $ibeam -eq 6 ] && [ $ifield -eq 2 ] && [ $interleave == "A" ] && [ $sbid == 1206 ])
			       #if ( [ $ibeam -eq 6 ] && [ $ifield -eq 2 ] && [ $interleave == "A" ] )
			       #then
			       #       echo "${fieldname}_bm-${ibeam} missing! So won't use it for linmos."
			       #      # Comment line below for single SBID processing: 
                               #     inname=$inname\ $path\image.i.$fieldname\_bm-$ibeam\_iter-$iloop.taylor.0.restored$delim
			       #else
				       # Update the parset file for linmos 
                                       inname=$inname\ $path\image.i.$fieldname\_bm-$ibeam\_iter-$iloop.taylor.0.restored$delim
                                       #inname=$inname\ $path2\image.i.$fieldname\_bm-$ibeam\_iter-$iloop.taylor.0.restored$delim
				       # Combine only iter-4 from 1206: 
                                       #inname=$inname\ $path2\image.i.$fieldname\_bm-$ibeam\_iter-4.taylor.0.restored$delim
			       #fi
		       done   
		       #==========================================================
	       done
	done # Loop for interleave 
	# Update the parset file for linmos: 
	# Remove the last "comma" and add a " ]": 
	inname=$inname\misaw
	sedstr="s/,misaw/\]/g"
	inname=`echo $inname | sed -e $sedstr`
	echo "linmos.names = $inname
        " >>$parset_linmos 

	if [ $trial -gt 0 ]
        then 
		echo "This was a set-up only run". Check your parsets now...
	else
		sbatch $slurmfile
	fi
done # Loop for self cal iterations ends


