#!/bin/bash

###########################
#
#  Prepare track.cmd file
#  accordingly
#  You need GMT
#
############################

# User input:
YEAR=2021
REF=argr

# Processing script:
echo
echo "Working on SITE $SITE in YEAR - $YEAR"
echo "Creating link to RINEX files"
YR=${YEAR: -2}
RINEX=../rinex/$YEAR

for SITE in arg6
do
  # Select first and last DOY
  for DOY in $(seq 1 365)
  do
    # Variables for DOY
    DOY=$(printf "%03d" $DOY)
    WK=$(doy $YEAR $DOY | awk '$1 == "GPS" {print $3 $7}')
    WEEK=${WK:0:5}

    # Variables for DOY1
    DOY1=$(gmt math -Q $DOY 1 SUB =)
    DOY1=$(printf "%03d" $DOY1)
    WK1=$(doy $YEAR $DOY1 | awk '$1 == "GPS" {print $3 $7}')
    WEEK1=${WK1:0:5}

    # Variables for DOY3
    DOY3=$(gmt math -Q $DOY 1 ADD =)
    DOY3=$(printf "%03d" $DOY3)
    WK3=$(doy $YEAR $DOY3 | awk '$1 == "GPS" {print $3 $7}')
    WEEK3=${WK3:0:5}

    echo "INFORMATION: Preceding day DOY = $DOY1 in WEEK = $WEEK1"
    echo "INFORMATION: Actual day DOY = $DOY in WEEK = $WEEK"
    echo "INFORMATION: Following day DOY = $DOY3 in WEEK = $WEEK3"
    echo
    echo "INFORMATION: Preparing data for DOYS $DOY1, $DOY, and $DOY3"
    
    for DAY in $DOY1 $DOY $DOY3
    do
      cp $RINEX/${SITE}${DAY}0.${YR}o .
      cp $RINEX/${REF}${DAY}0.${YR}o .
    done

    echo "INFORMATION: Catting 3 days for the survey site $SITE"
    N2=$(grep -n 'END OF HEADER' ${SITE}${DOY}0.${YR}o | cut -d ":" -f 1)
    N3=$(grep -n 'END OF HEADER' ${SITE}${DOY3}0.${YR}o | cut -d ":" -f 1)
    NL2=$(gmt math -Q $N2 1 ADD =)
    NL3=$(gmt math -Q $N3 1 ADD =)
    mv ${SITE}${DOY1}0.${YR}o rnx_${DOY1}.tmp
    tail -n +$NL2 ${SITE}${DOY}0.${YR}o > rnx_${DOY}.tmp
    tail -n +$NL3 ${SITE}${DOY3}0.${YR}o > rnx_${DOY3}.tmp
    cat rnx_${DOY1}.tmp rnx_${DOY}.tmp rnx_${DOY3}.tmp > ${SITE}${DOY}0.${YR}o

    echo "INFORMATION: Catting 3 days for the reference site $REF"
    N2=$(grep -n 'END OF HEADER' ${REF}${DOY}0.${YR}o | cut -d ":" -f 1)
    N3=$(grep -n 'END OF HEADER' ${REF}${DOY3}0.${YR}o | cut -d ":" -f 1)
    NL2=$(gmt math -Q $N2 1 ADD =)
    NL3=$(gmt math -Q $N3 1 ADD =)
    mv ${REF}${DOY1}0.${YR}o ${DOY1}.tmp
    tail -n +$NL2 ${REF}${DOY}0.${YR}o > ${DOY}.tmp
    tail -n +$NL3 ${REF}${DOY3}0.${YR}o > ${DOY3}.tmp
    cat ${DOY1}.tmp ${DOY}.tmp ${DOY3}.tmp > ${REF}${DOY}0.${YR}o

    echo "sh_get_orbits: Downloading and merging sp3 files"
    for DAY in $DOY1 $DOY $DOY3
    do
      sh_get_orbits -orbit igsf -yr $YEAR -doy $DAY -nofit
    done
    mv igs${WEEK}.sp3 igs${DOY}.sp3
    cat igs${WEEK1}.sp3 igs${DOY}.sp3 igs${WEEK3}.sp3 > igs${WEEK}.sp3

    echo "sh_get_ion: Downloading and merging ion files"
    for DAY in $DOY1 $DOY $DOY3
    do
      sh_get_ion -yr $YEAR -doy $DAY
    done
    mv igsg${DOY}0.${YR}i igsg${WEEK}0.${YR}i
    cat igsg${DOY1}0.${YR}i igsg${WEEK}0.${YR}i igsg${DOY3}0.${YR}i > igsg${DOY}0.${YR}i

    echo "TRACK: Started processing DOY $DOY"
    track -f track.cmd -d $DOY -week $WEEK -s $YEAR $YR $REF $SITE > ${SITE}_${YEAR}-${DOY}.log

    echo "TRACK: Output file is ${SITE}_${YEAR}-${DOY}.log"
    echo "TRACK: Position statistics"
    grep 'PRMS' ${SITE}_${YEAR}-${DOY}.sum

    # Calculate horizontal velocity
    OUTPUTFILE="${REF}_${YEAR}*.DHU.${SITE}.L1"

    # Round seconds
    echo "Rounding seconds..."
    sed -i -e 's/30.000000/30/' \
           -e 's/0.000000/00/' \
           -e 's/0.000001/00/' \
           -e 's/29.999999/30/' \
           -e 's/29.999998/30/' $OUTPUTFILE

    # Remove comment lines and NaNs
    echo "Removing comment lines and NaNs..."
    grep -v '*' $OUTPUTFILE | grep -v 'NaN' > f3.tmp

    # Make file GMT-readable
    echo "Making file GMT-readable..."
    awk '{print $1"-"$2"-"$3"T"$4":"$5":"$6"\t"$7"\t"$8"\t"$9"\t"$10"\t"$11"\t"$12"\t"$13"\t"$14"\t"$20}' f3.tmp > ${SITE}_${YEAR}_${DOY}_${REF}.pos
    sed -i 's/:300/:30/' ${SITE}_${YEAR}_${DOY}_${REF}.pos
    echo "File ${SITE}_${YEAR}_${DOY}_${REF}.pos was created."

###########       Seasonal-Trend decomposition         ################
# Here if you want to apply STL filtering, it is easier to perform in python
#import pandas as pd
#import statsmodels.api as sm
#pos = pd.read_table('${SITE}_${YEAR}_${DOY}_${REF}.pos', delim_whitespace=True, header=None, names=['Time', 'N', 'E', 'U'])
#pos['Time'] = pd.to_datetime(pos.Time)
## Seasonal-Trend decomposition
#north = sm.tsa.seasonal_decompose(pos['N'], model='additive', period=2872)  # Sidereal day frequency in seconds
## Time series without seasonal component
#north_filt = pos['N'] - north.seasonal
## Seasonal-Trend decomposition
#east = sm.tsa.seasonal_decompose(pos['E'], model='additive', period=2872)  # Sidereal day frequency in seconds
## Time series without seasonal component
#east_filt = pos['E'] - east.seasonal
## Seasonal-Trend decomposition
#up = sm.tsa.seasonal_decompose(pos['U'], model='additive', period=2872)  # Sidereal day frequency in seconds
## Time series without seasonal component
#up_filt = pos['U'] - up.seasonal
#####################

    # Sort out pos file
    echo "Sorting out pos file..."
    POS=${SITE}_${YEAR}_${DOY}_${REF}.pos
    INFO=($(gmt info -C $POS))
    T="-T${INFO[0]}/${INFO[1]}"

    # Apply Gaussian filter
    echo "Applying Gaussian filter..."
    GF=64800
    INT=30
    GX=30
    gmt filter1d $POS $T/$INT -i0,1 -L$INT -Fg$GF -f0T -N0 --TIME_UNIT=s > ngf.tmp
    gmt filter1d $POS $T/$INT -i0,3 -L$INT -Fg$GF -f0T -N0 --TIME_UNIT=s > egf.tmp

    # Apply Moving average
    echo "Applying Moving average..."
    MA=60
    gmt filter1d ngf.tmp $T/$INT -L$INT -gx$GX -Fb$MA -f0T -N0 --TIME_UNIT=s > nma.tmp
    gmt filter1d egf.tmp $T/$INT -L$INT -gx$GX -Fb$MA -f0T -N0 --TIME_UNIT=s > ema.tmp

    # Calculate velocities
    echo "Calculating velocities..."
    gmt math nma.tmp DIFF SQR = ndiff.tmp
    gmt math ema.tmp DIFF SQR = ediff.tmp
    gmt math ndiff.tmp ediff.tmp ADD SQRT $INT DIV 3600 MUL = ${SITE}_${YEAR}_${DOY}_${REF}.vel
    echo "Velocity file ${SITE}_${YEAR}_${DOY}_${REF}.vel was created."

    # Clean up intermediate files
    echo "Deleting intermediate files..."
    rm *tmp $OUTPUTFILE
    rm *.${YR}o *.sp3
    rm get*log *tmp

  done
done

