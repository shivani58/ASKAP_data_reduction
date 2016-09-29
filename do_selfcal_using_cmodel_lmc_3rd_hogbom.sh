#!/bin/bash 
# What did I change (x means changes reverted to original) : 
#        + Interval = 300 seconds (5 mins) 
#        + Iteration 5: ncycle 15, clipping = 0.06
#        x Iteration 6: NO pre-conditioning, ncycle 15, clipping = 0.06
#        + Added Gaussian Taper, and preconditioning back (Iter-6) 
#        + Added Gaussian Taper, and preconditioning back, Increased psfwidth (Iter-6) 
#        + Iteration for BFMFS: Trouble with ncycle 15, setting ncycle=5 back again 
trial=0 # If >0, trial run only, else mpi will be executed.
nbeams=30 
sbid=1997 #1979 
path=/scratch2/astronomy856/sbhandari/cass/DATA/$sbid/MSDATA_SPLIT/BPCAL/FLAGGED_DYNAMIC/AVERAGED/FLAGGED_DYNAMIC/ #FLAGGED_DYNAMIC/
#outpath=/scratch2/askap/raj030/LMC3/IMAGE/$sbid/
#outpath=IMAGE_HOGBOM_WITH_GAUSSIAN_TAPER_40/
outpath=/scratch2/astronomy856/sbhandari/cass/DATA/$sbid/MSDATA_SPLIT/BPCAL/FLAGGED_DYNAMIC/AVERAGED/FLAGGED_DYNAMIC/IMAGE_BM-21_LARGE/ #IMAGE_BFMFS_WITH_GAUSSIAN_TAPER_40/

# Incorporate a check if the AVERAGED directory already exists. If not, create it. 
mkdir -p $outpath 

# BACKUP DIRS: 
slurmOutput=slurmOutput
PARSETS=PARSETS
LOGS=LOGS
Slurmfiles=Slurmfiles


bfield=0
efield=0
bbeam=0 #0
ebeam=29 #29

#task_slurm=PhaScalCmodRobust 
task_slurm=HOGBOM #BFMFS #HOGBOM 
#task_slurm=HOGBOM_$sbid #BFMFS_$sbid 
logfile=$task_slurm

task_ccal=ccal
#task_ccal=ccal_selfcal_phase_only_hogbom_60arcsec
nranks_ccal=1

task_cimage=cimage
#task_cimage=cimage_selfcal_phase_only_hogbom_60arcsec
nranks_cimage=145 

task_selavy=selavy
#task_selavy=selavy_selfcal_phase_only_hogbom_60arcsec
nranks_selavy=31 

task_cmodel=cmodel
#task_cmodel=cmodel_selfcal_phase_only_hogbom_60arcsec
nranks_cmodel=31 
# Self cal loops: 
niter=4
bloop=0
eloop=$niter 
npix_ra=2048 #1280
npix_dec=2048 #1280
npix_psf=2048 #2560 #2048
nres_ra=6 #arcsec
nres_dec=6 #arcsec

source=LMC_02_T0-0
# Choose the imager you wish to use: 
imager=cimager 
calib=ccalibrator 
cmodel=cmodel
selavy=selavy 
#imager=/group/astronomy856/raj030/ASKAPsoft/Code/Components/Synthesis/synthesis/current/apps/cimager.sh  
#calib=/group/astronomy856/raj030/ASKAPsoft/Code/Components/Synthesis/synthesis/current/apps/ccalibrator.sh 
#cmodel=/group/astronomy856/raj030/ASKAPsoft/Code/Components/CP/pipelinetasks/current/apps/cmodel.sh 
#cmodel=cmodel 

# For cmodel, what fraction of the brightest source's flux you wish to include in your model image: 
frac=0.5 
# Unique tags for setup files and logs that we would want to save: 
dd=`date +%d`
mon=`date +%b`
yyyy=`date +%Y`
hh=`date +%H`
mm=`date +%M`
ss=`date +%S`

for interleave in A B C 
do
       for (( ifield=$bfield;ifield<=$efield;ifield++ ))
       do
	       #fieldname=$source\F$ifield$interleave
	       fieldname=$source$interleave
               # Time to get RA and Dec of beam zero, as well as all other beams
               # making use of footprint.py etc. :
               # (We will use the wrapper "get_ra_dec_for_all_beam_pointing.sh") 
               get_ra-dec_for_all_beam_pointing.sh $path$fieldname\_bm-0.ms $fieldname.beams.pnt
	       for (( ibeam=$bbeam;ibeam<=$ebeam;ibeam++ ))
	       do
		       # parameters independent of self cal cycles: 
                       #======================================================== 
                       # Read the pointing direction for the current beam: 
                       iline=`echo $ibeam + 1 |bc`
                       IFS="(),"  # Recognising patterns for delimiters 
                       tmpline=`sed -n $iline\p $fieldname.beams.pnt `
                       tmparray=($tmpline)
                       ra=${tmparray[4]}
                       dec=${tmparray[5]}

                       unset IFS
                       IFS=":"
                       ra_array=($ra)
                       rah=${ra_array[0]}
                       ram=${ra_array[1]}
                       ras=${ra_array[2]}
                       unset IFS
                       IFS=":"
                       dec_array=($dec)
                       decd=${dec_array[0]}
                       decm=${dec_array[1]}
                       decs=${dec_array[2]}
                       unset IFS
		       # The first pass of self cal may use a standard sky model
        	       #model_image=/u/raj030/LMC/sb1206-1207_newms_spw0/
        	       msfile=$fieldname\_bm-$ibeam.ms
	               slurmfile=$task_slurm\_$fieldname\_bm-$ibeam.sbatch
		       mkdir -p $slurmOutput
		       
		       # Prepare the slurm file now outside the self cal loops: 
		       job_name=${task_slurm}$ibeam$interleave
                       echo "#!/usr/bin/env bash
#SBATCH --partition=workq
#SBATCH --time=12:00:00
#SBATCH --ntasks=145 
#SBATCH --ntasks-per-node=15
#SBATCH --job-name=$job_name
#SBATCH --export=ASKAP_ROOT,AIPSPATH
#SBATCH --output=$slurmOutput/$logfile-%j.out

# Make a copy of this file for this instance of slurmJobId
slurmdir=$Slurmfiles/$task_slurm 
parsetdir=$PARSETS/$task_slurm 
logdir=$LOGS/$task_slurm 
# Incorporate a check if the directory already exists. If not, create it. 
mkdir -p \$slurmdir 
mkdir -p \$parsetdir 
mkdir -p \$logdir 

sedstr=\"s/sbatch/\${SLURM_JOB_ID}\.sbatch/g\"
cp -a $slurmfile \`echo $slurmfile | sed -e \$sedstr\`
mv \`echo $slurmfile | sed -e \$sedstr\` \$slurmdir/.

" >$slurmfile
		       for ((iloop=$bloop;iloop<=$eloop;iloop++))
		       do 
			       # ===============================================================
			       # We will start with our slurmfile here: 
                               # (Just the set-up/definition bit here)
			       # Write the SlurmFile now: 
                               outname=$fieldname\_bm-$ibeam\_iter-$iloop
			       # Output component file/parset from selavy: 
                               selavyImage=image.i.$outname.taylor.0.restored  # Input image to Selavy
                               selavyComponents=$selavyImage.cleancomps
                               selavyVOTable=selavy-results_$outname.components.xml # warning: Intricately connected with Selavy.resultsFile nomenclature 
                               selavyOutImage=$selavyImage.cmodel # Output image from cmodel using selavy votable 
			       # The model should be derived from a previous iteration: 
			       jloop=`echo "$iloop - 1" |bc`
                               ##model_image=$outpath\image.i.$fieldname\_bm-$ibeam\_iter-$jloop.taylor.0.restored
                               #model_image=$outpath\image.i.$fieldname\_bm-$ibeam\_iter-$jloop.taylor.0
                               model_image=$outpath\image.i.$fieldname\_bm-$ibeam\_iter-$jloop.taylor.0.restored.cmodel
			       #model_image=image.i.LMC_iter-2.linmos_noselavy # Temporary test with a wide field image as model
                               model_comp=$outpath\image.i.$fieldname\_bm-$ibeam\_iter-$jloop.taylor.0.restored.cleancomps
			       # remember that $model_comp is $selavyComponents from the previous iteration. 
			       # ===============================================================
			       # Skip calibration on the first pass (no model exists): 
			       if (( $iloop >= 1 ))
			       then
				       # =======================================================
			               # Calibration Cycles for SELFCAL: 
		                       # =======================================================
        		               task=$task_ccal
        	                       parset_ccal=$task\_$fieldname\_bm-$ibeam\_iter-$iloop.in
        	                       logfile_ccal=$task\_$fieldname\_bm-$ibeam\_iter-$iloop.log 
                                       out_table=$fieldname\_bm-$ibeam\_iter-$iloop.tab 
	                               echo "Ccalibrator.dataset                                     = $path$msfile
Ccalibrator.sources.names                               = $outname 
Ccalibrator.sources.$outname.model                      = $model_image 
#Ccalibrator.sources.definition                          = $model_comp 
# TODO:Something to find out: What happens if one does not specify the parameter below to parallelise processing along channels? 
#Ccalibrator.Channels                                    = [1, %w]

Ccalibrator.gridder                                     = WProject
Ccalibrator.gridder.WProject.wmax                       = 2600
Ccalibrator.gridder.WProject.nwplanes                   = 33 
Ccalibrator.gridder.WProject.oversample                 = 4
Ccalibrator.gridder.snapshotimaging                     = true
Ccalibrator.gridder.snapshotimaging.clipping            = 0.06 #0.02
Ccalibrator.gridder.snapshotimaging.wtolerance          = 2600
Ccalibrator.gridder.WProject.diameter                   = 12m
Ccalibrator.gridder.WProject.blockage                   = 2m
Ccalibrator.gridder.WProject.maxfeeds                   = $nbeams
Ccalibrator.gridder.WProject.maxsupport                 = 512
Ccalibrator.gridder.WProject.variablesupport            = true
Ccalibrator.gridder.WProject.offsetsupport              = true
Ccalibrator.gridder.WProject.frequencydependent         = true
Ccalibrator.calibaccess                                 = "table" 
Ccalibrator.solve                                       = antennagains
Ccalibrator.normalisegains                              = true 
#Ccalibrator.interval                                    = 300.0s
Ccalibrator.nant                                        = 12 
Ccalibrator.refantenna                                  = 2 
Ccalibrator.calibaccess.table                           = $out_table 
Ccalibrator.ncycles                                     = 45
Ccalibrator.nterms                                      = 1
		                       " >$parset_ccal 
                                       # Write the SlurmFile now: 
	                               echo "#

sedstr=\"s/in/\${SLURM_JOB_ID}\.in/g\"
cp -a $parset_ccal \`echo $parset_ccal | sed -e \$sedstr\`
mv \`echo $parset_ccal | sed -e \$sedstr\` \$parsetdir/.
log=$logfile_ccal.\${SLURM_JOB_ID}.log
aprun -n $nranks_ccal -N 1 $calib -c ${parset_ccal} > \${log}
mv \$log \$logdir/.
" >>$slurmfile
				       yorn="true"
			       else
				       yorn="false"
	                       fi
		               # =======================================================

	                       # CIMAGE Begins: 
        		       task=$task_cimage
        	               parset_cimage=$task\_$fieldname\_bm-$ibeam\_iter-$iloop.in
        	               logfile_cimage=$task\_$fieldname\_bm-$ibeam\_iter-$iloop.log 
                               #======================================================== 
	                       echo "Cimager.dataset                                = $path$msfile
#
Cimager.datacolumn                             = DATA
Cimager.Channels                               = [1, %w]
#
Cimager.Images.Names                           = [image.i.$outname] 
Cimager.Images.shape                           = [$npix_ra,$npix_dec]
Cimager.Images.cellsize                        = [${nres_ra}arcsec, ${nres_dec}arcsec]
# Need attention 
Cimager.Images.image.i.$outname.direction      = [${rah}h${ram}m$ras, $decd.$decm.$decs, J2000]
#Cimager.Images.image.i.$outname.frequency      = [1.0105e+09,1.0105e+09]
#Cimager.nUVWMachines                           = 1
# Facets
#Cimager.Images.image.i.$outname.nfacets        = 16
#Cimager.Images.image.i.$outname.facetstep      = 256
#
# This is how many channels to write to the image - just a single one for continuum
Cimager.Images.image.i.$outname.nchan          = 1 
# The following are needed for MFS clean
# This one defines the number of Taylor terms
Cimager.Images.image.i.$outname.nterms         = 2
# This one assigns one worker for each of the Taylor terms
Cimager.nworkergroups                          = 3 #1
# Leave 'Cimager.visweights' to be determined by Cimager, based on nterms
# Leave 'Cimager.visweights.MFS.reffreq' to be determined by Cimager
#

Cimager.gridder.alldatapsf                     = true
Cimager.gridder.snapshotimaging                = true
Cimager.gridder.snapshotimaging.clipping       = 0.06 # 0.02
Cimager.gridder.snapshotimaging.wtolerance     = 2600
#Cimager.gridder                                = SphFunc #WProject
Cimager.gridder                                = WProject
Cimager.gridder.WProject.wmax                  = 2600
Cimager.gridder.WProject.nwplanes              = 33
Cimager.gridder.WProject.oversample            = 4
Cimager.gridder.WProject.diameter              = 12m
Cimager.gridder.WProject.blockage              = 2m
Cimager.gridder.WProject.maxfeeds              = $nbeams
Cimager.gridder.WProject.maxsupport            = 512
Cimager.gridder.WProject.variablesupport       = true
Cimager.gridder.WProject.offsetsupport         = true
Cimager.gridder.WProject.frequencydependent    = true
#
Cimager.solver                                 = Clean
Cimager.solver.Clean.algorithm                 = Hogbom #BasisfunctionMFS #Hogbom  
Cimager.solver.Clean.niter                     = 20000
Cimager.solver.Clean.gain                      = 0.1
Cimager.solver.Clean.scales                    = [0,3,10]
Cimager.solver.Clean.verbose                   = True
Cimager.solver.Clean.tolerance                 = 0.01
Cimager.solver.Clean.weightcutoff              = zero
Cimager.solver.Clean.weightcutoff.clean        = false
Cimager.solver.Clean.psfwidth                  = $npix_psf #1024
Cimager.solver.Clean.logevery                  = 100
Cimager.threshold.minorcycle                   = [30%,8.0mJy] #[30%,0.2mJy] #[30%,2.0mJy]
Cimager.threshold.majorcycle                   = [1.0mJy] #0.1mJy #1.0mJy #5.0mJy
Cimager.threshold.masking                      = 0.9 #-1
Cimager.ncycles                                = 5 #20
Cimager.Images.writeAtMajorCycle               = false
#
Cimager.restore                                = true
#Cimager.restore.beam                           = fit  #[45arcsec, 45arcsec, 0deg]
Cimager.restore.beam                           = [35arcsec, 35arcsec, 0deg]
#
Cimager.calibrate                              = $yorn 
Cimager.calibrate.ignorebeam                   = true  
Cimager.calibaccess                            = "table" 
Cimager.calibaccess.table                      = $out_table 
# 
#Cimager.preconditioner.Names                   = None #[Wiener, GaussianTaper]
Cimager.preconditioner.Names                   = [Wiener, GaussianTaper]
Cimager.preconditioner.GaussianTaper           = [40arcsec, 40arcsec, 0deg]
#Cimager.preconditioner.WienerTaper             = [512, 512]
Cimager.preconditioner.Wiener.robustness       = -0.5
#Cimager.gentlepreconditioner                   = true 
Cimager.preconditioner.preservecf              = true 
	" >$parset_cimage 
                               # Write the SlurmFile now: 
                               echo "#

sedstr=\"s/in/\${SLURM_JOB_ID}\.in/g\"
cp -a $parset_cimage \`echo $parset_cimage | sed -e \$sedstr\`
mv \`echo $parset_cimage | sed -e \$sedstr\` \$parsetdir/.
log=$logfile_cimage.\${SLURM_JOB_ID}.log
aprun -n $nranks_cimage -N 15 $imager -c ${parset_cimage} > \${log}
#aprun -n $nranks_cimage -N 15 $imager -c ${parset_cimage} -l my_askap_log_preference.cfg > \${log}
mv \$log \$logdir/.
" >>$slurmfile
			       #==========================================================
			       # SELAVY Begins: 
			       # Detect clean components from the clean+restored image and 
			       # note them for possible use with ccalibrator: 
			       #
        		       task=$task_selavy
        	               parset_selavy=$task\_$fieldname\_bm-$ibeam\_iter-$iloop.in
        	               logfile_selavy=$task\_$fieldname\_bm-$ibeam\_iter-$iloop.log 

                               # Remove an old flagged file and start afresh from the raw: 
                               #======================================================== 
                               ## Shallow source-finding with selavy
	                       echo " # The image to be searched
Selavy.image                                    = ${selavyImage}
#
# We could divide it up for distributed processing, with the
#  number of subdivisions in each direction, and the size of the
#  overlap region in pixels
Selavy.nsubx                                    = 5
Selavy.nsuby                                    = 6
Selavy.overlapx                                 = 50
Selavy.overlapy                                 = 60
#
# The search threshold, in units of sigma
Selavy.snrCut                                   = 10 
# Grow the detections to a secondary threshold
Selavy.flagGrowth                               = true
Selavy.growthCut                                = 4
#
# Turn on the variable threshold option
Selavy.VariableThreshold                        = true
Selavy.VariableThreshold.boxSize                = 50
Selavy.VariableThreshold.ThresholdImageName     = detThresh.$outname.img
Selavy.VariableThreshold.NoiseImageName         = noiseMap.$outname.img
Selavy.VariableThreshold.AverageImageName       = meanMap.$outname.img
Selavy.VariableThreshold.SNRimageName           = snrMap.$outname.img
#
# Parameters to switch on and control the Gaussian fitting
Selavy.Fitter.doFit                             = true
# Fit all 6 parameters of the Gaussian
Selavy.Fitter.fitTypes                          = [full]
# Limit the number of Gaussians to 1
Selavy.Fitter.maxNumGauss = 1
# Do not use the number of initial estimates to determine how many Gaussians to fit
Selavy.Fitter.numGaussFromGuess = true #false
# The fit may be a bit poor, so increase the reduced-chisq threshold
Selavy.Fitter.maxReducedChisq = 15.
#
# Allow islands that are slightly separated to be considered a single 'source'
Selavy.flagAdjacent = false
# The separation in pixels for islands to be considered 'joined'
Selavy.threshSpatial = 7
#
# Naming the output results files: 
Selavy.resultsFile = selavy-results_$outname.txt 
# Saving the fitted components to a parset for use by ccalibrator
Selavy.outputComponentParset                    = true
Selavy.outputComponentParset.filename           = ${selavyComponents}
# Only use the brightest components in the parset
Selavy.outputComponentParset.maxNumComponents   = 1 #2
#
# Size criteria for the final list of detected islands
Selavy.minPix                                   = 3
Selavy.minVoxels                                = 3
Selavy.minChannels                              = 1
#
# How the islands are sorted in the final catalogue - by
#  integrated flux in this case
Selavy.sortingParam                             = -iflux
			       " >$parset_selavy 

                               #======================================================== 
                               ## Create model image of the brightest sources detected using selavy
        		       task=$task_cmodel
        	               parset_cmodel=$task\_$fieldname\_bm-$ibeam\_iter-$iloop.in
        	               logfile_cmodel=$task\_$fieldname\_bm-$ibeam\_iter-$iloop.log 
	                       echo " # Use the VOT file output from selavy
Cmodel.gsm.database       = votable
Cmodel.gsm.file           = $selavyVOTable 
Cmodel.gsm.ref_freq       = 1.4GHz

# General parameters
Cmodel.bunit              = Jy/beam #Jy/pixel
Cmodel.frequency          = 1.4GHz
Cmodel.increment          = 48MHz
#Cmodel.flux_limit         = 400mJy #100mJy
Cmodel.shape              = [$npix_ra, $npix_dec]
Cmodel.cellsize           = [${nres_ra}arcsec, ${nres_dec}arcsec]
Cmodel.direction          = [${rah}h${ram}m$ras, $decd.$decm.$decs, J2000]
Cmodel.stokes             = [I]
Cmodel.nterms             = 1

# Output specific parameters
Cmodel.output             = casa
Cmodel.filename           = $selavyOutImage
			       " >$parset_cmodel 
                               # Write the SlurmFile now: 
                               echo "#

sedstr=\"s/in/\${SLURM_JOB_ID}\.in/g\"
cp -a $parset_selavy \`echo $parset_selavy | sed -e \$sedstr\`
mv \`echo $parset_selavy | sed -e \$sedstr\` \$parsetdir/.
log=$logfile_selavy.\${SLURM_JOB_ID}.log

aprun -n $nranks_selavy -N 15 $selavy -c ${parset_selavy} > \${log}
mv \$log \$logdir/.

# Extract information on the brightest source from the output cleancomps file 
# file of selavy, and use only components above p% of this brightest source 
# for cmodel. 
# Flux information about brightest source in 3rd line of components file, hence "-3p" below: 
tmpline=\`sed -n 3p $selavyComponents\`
tmparray=(\$tmpline)
my_flux_limit=\`echo \${tmparray[2]}*$frac |bc -l\`

# Update the cmodel parset with this new flux limiti from inside the slurmfile: 
echo \"
Cmodel.flux_limit         = \${my_flux_limit}Jy 
\" >>$parset_cmodel

sedstr=\"s/in/\${SLURM_JOB_ID}\.in/g\"
cp -a $parset_cmodel \`echo $parset_cmodel | sed -e \$sedstr\`
mv \`echo $parset_cmodel | sed -e \$sedstr\` \$parsetdir/.
log=$logfile_cmodel.\${SLURM_JOB_ID}.log

aprun -n $nranks_cmodel -N 15 $cmodel -c ${parset_cmodel} > \${log}
mv \$log \$logdir/.
rm -rf $outpath*.$outname* 
mv -f *$outname*taylor* $outpath.
		               " >>$slurmfile
        
		       done  # Loop for self cal ends 
		       echo "#

err=\$?
extractStats \${log} \${SLURM_JOB_ID} ${task_slurm}_${fieldname}_bm-$ibeam \"txt,csv\"
if [ \$err != 0 ]; then
	exit \$err
fi
					" >>$slurmfile
        	       if [ $trial -gt 0 ]
                       then
			       echo "This was a set-up only run". Check your parsets now...
		       else
	        	       sbatch $slurmfile
	               fi
		       #==========================================================
	       done
	done
done


