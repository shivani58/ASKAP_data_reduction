# ASKAP_data_reduction
This repository includes scripts for ASKAP data reduction. Following are the steps for reducing ASKAP data:
1) splitting 1934 (Calibrator) data into respective number of beams
2) flagging 1934
3) Obtaining bandpass solutions from 1934
4) Splitting target field into respective beams
5) Applying bandpass solutions obtained from the calibrator to target field
6) Flagging target data
7) Averaging in frequency
8) Flagging bad data if needed after averaging.
9) Imaging - by running do_selfcal script
10) Creating a mosaic by running linmos
