#!/bin/bash

# User input:
# Select year
YEAR=2020

# Indicate first and last DOY
for DOY in {1..365}
do
    # Start gamit processing:

    # Make 3-digit DOY
    DOY=$(printf "%03d" $DOY)

    echo "Processing DOY $DOY in $YEAR"

    # choose one of the available periods and comment out the rest

    # 24-hour processing
    sh_gamit -expt arge -gnss G -d $YEAR $DOY -orbit igsf -yrext -netext _24h > gamit_${YEAR}_${DOY}_24h.log

    # 6-hour processing
    for i in {0..3}; do
        sh_gamit -expt arge -gnss G -d $YEAR $DOY -sessinfo 30 720 $((i * 6)) 0 -orbit igsf -yrext -netext _"$((i+1))"_6h > gamit_${YEAR}_${DOY}_$((i+1))_6h.log
    done

    # 4-hour processing
    for i in {0..5}; do
        sh_gamit -expt arge -gnss G -d $YEAR $DOY -sessinfo 30 480 $((i * 4)) 0 -orbit igsf -yrext -netext _"$((i+1))"_4h > gamit_${YEAR}_${DOY}_$((i+1))_4h.log
    done

done

