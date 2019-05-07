#!/bin/bash
set -euo pipefail

## Script for calling exome depth and adding vcf headers
## Only to be used as part of gatk snakemake pipeline.


BAM_LIST=$1
REF=$2
BED=$3
SEQID=$4
PREFIX=$5
DICT=$6
LOW_BAM_LIST=$7

# If we have at least four bams with high coverage (more than 20x)
if [[ -e $BAM_LIST ]] && [[ $(wc -l $BAM_LIST | awk '{print $1}') -gt 2 ]]; then


	 #call CNVs using read depth
    Rscript scripts/ExomeDepth.R \
    -b $BAM_LIST\
    -f $REF \
    -r $BED \
    -p $PREFIX \
    2>&1 | tee $PREFIX/ExomeDepth.log

    #print ExomeDepth metrics
    echo -e "BamPath\tFragments\tCorrelation" > $PREFIX/"$SEQID"_ExomeDepth_Metrics.txt
    paste $BAM_LIST \
    <(grep "Number of counted fragments" $PREFIX/ExomeDepth.log | cut -d' ' -f6) \
    <(grep "Correlation between reference and tests count" $PREFIX/ExomeDepth.log | cut -d' ' -f8) >> $PREFIX/"$SEQID"_ExomeDepth_Metrics.txt

 	#add CNV vcf headers and move to sample folder
    for vcf in $(ls $PREFIX/*_cnv.vcf); do

        sampleId=$(basename ${vcf%.*})

        #add VCF headers
        picard UpdateVcfSequenceDictionary \
        I="$vcf" \
        O="$PREFIX"/"$sampleId"_fixed.vcf \
        SD=$DICT

        #gzip and tabix
        bgzip "$PREFIX"/"$sampleId"_fixed.vcf
        tabix -p vcf "$PREFIX"/"$sampleId"_fixed.vcf.gz

        rm $vcf

    done

    # Get rid of intermediate files
    rm $PREFIX/*_cnv.txt

    # Make empty files for low coverage - snakemake needs this
    for i in $(cat $LOW_BAM_LIST); do

        sampleId=$(basename ${i%.*})

        echo 'NO CNVS' > "$PREFIX"/"$sampleId"_cnv_fixed.vcf.gz
        echo 'NO CNVS' > "$PREFIX"/"$sampleId"_cnv_fixed.vcf.gz.tbi

    done

# If we do not have more than 4 bams with high coverage
else

    # create emptry files for all samples
    for i in $(cat $LOW_BAM_LIST); do

        sampleId=$(basename ${i%.*})

        echo 'NO CNVS' > "$PREFIX"/"$sampleId"_cnv_fixed.vcf.gz
        echo 'NO CNVS' > "$PREFIX"/"$sampleId"_cnv_fixed.vcf.gz.tbi

    done

    # and for high coverage bams
    for i in $(cat $BAM_LIST); do

        sampleId=$(basename ${i%.*})

        echo 'NO CNVS' > "$PREFIX"/"$sampleId"_cnv_fixed.vcf.gz
        echo 'NO CNVS' > "$PREFIX"/"$sampleId"_cnv_fixed.vcf.gz.tbi

    done   


fi