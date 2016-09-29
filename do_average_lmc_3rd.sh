#!/bin/bash 

trial=0 # If >0, trial run only, else mpi will be executed.
sbid=1997 
path=/scratch2/astronomy856/sbhandari/cass/DATA/$sbid/MSDATA_SPLIT/BPCAL/FLAGGED_DYNAMIC/
outpath=/scratch2/astronomy856/sbhandari/cass/DATA/$sbid/MSDATA_SPLIT/BPCAL/FLAGGED_DYNAMIC/AVERAGED/
# Incorporate a check if the AVERAGED directory already exists. If not, create it. 
mkdir -p $outpath 

bfield=0
efield=0
bbeam=0
ebeam=29

task=average
source=LMC_02_T0-0
for interleave in A B C 
do
       for (( ifield=$bfield;ifield<=$efield;ifield++ ))
       do
	       #fieldname=$source\F$ifield$interleave
	       fieldname=$source$interleave 
	       for (( ibeam=$bbeam;ibeam<=$ebeam;ibeam++ ))
	       do
		       job_name=ave$ibeam$interleave 
	               # Name the file to be used as input by ASKAPsoft codes: 
	               parset=$task\_$fieldname\_bm-$ibeam.in
	               logfile=$task\_$fieldname\_bm-$ibeam
	               msfile=$fieldname\_bm-$ibeam.ms
		       slurmfile=$task\_$fieldname\_bm-$ibeam.sbatch
	               echo "
# Input measurement set
# Default: <no default>
vis                         = $path$msfile 

# Output measurement set
# Default: <no default>
outputvis                   = $outpath$msfile 

# The channel range to split out into its own measurement set
# Can be either a single integer (e.g. 1) or a range (e.g. 1-300). The range
# is inclusive of both the start and end, indexing is one-based.
# Default: <no default>
# Note that we don't use CHAN_RANGE_SCIENCE, since the splitting out
# has already been done. We instead set this to 1-NUM_CHAN_SCIENCE
channel     = "1-2592"

# Defines the number of channel to average to form the one output channel
# Default: 1
width       = 54
	" >$parset 
	               # Write the SlurmFile now: 
		       echo "#!/usr/bin/env bash
#SBATCH --partition=workq
#SBATCH --time=12:00:00
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --job-name=$job_name
#SBATCH --export=ASKAP_ROOT,AIPSPATH
#SBATCH --output=slurmOutput/$logfile-%j.out

# Make a copy of this file for this instance of slurmJobId
slurmdir=Slurmfiles/$task
parsetdir=PARSETS/$task
logdir=LOGS/$task
# Incorporate a check if the directory already exists. If not, create it. 
mkdir -p \$slurmdir
mkdir -p \$parsetdir
mkdir -p \$logdir

# Remove an old flagged file and start afresh from the raw: 
rm -rf $outpath$msfile

sedstr=\"s/sbatch/\${SLURM_JOB_ID}\.sbatch/g\"
cp -a $slurmfile \`echo $slurmfile | sed -e \$sedstr\`
mv \`echo $slurmfile | sed -e \$sedstr\` \$slurmdir/.

sedstr=\"s/in/\${SLURM_JOB_ID}\.in/g\"
cp -a $parset \`echo $parset | sed -e \$sedstr\`
mv \`echo $parset | sed -e \$sedstr\` \$parsetdir/.

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
	done
done


