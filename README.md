# ensembleCNV

## Method Description

EnsembleCNV, which first detect CNV by aggregating the complementary strengths from multiple existing callers, followed by re-genotype and boundary refinement.  

## Table of Contents

- [01 initial all](#01-initial-all)
  - [prepare chr-based LRR matrix and BAF matrix](#prepare-chr-based-lrr-matrix-and-baf-matrix)
  - [prepare data for running IPQ](#prepare-data-for-running-IPQ)
  - [call PennCNV](#call-penncnv)
  - [call QuantiSNP](#call-quantisnp)
  - [call iPattern](#call-ipattern)
- [02 batch effect](#02-batch-effect)
  - [snp-level LRR statics](#snp-level-lrr-statics)
  - [sample-level IPQ 10 statics](#sample-level-ipq-10-statics)
- [03 CNVR](#03-CNVR)
- [04 genotype](#04-genotype)
- [05 boundary refinement](#05-boundary-refinement)
- [06 result](#06-result)
  - [compare duplicate pairs consistency rate](#compare-duplicate-pairs-consistency-rate)


## 01 initial all

prepare all BAF and LRR matrix 

call iPattern, PennCNV and QuantiSNP

### prepare chr-based matrix (LRR and BAF)

Before running this script, the following data must by supplied.
1, generate LRR and BAF (tab format) matrix from finalreport
```perl
perl finalreport_to_matrix_LRR_and_BAF.pl \
path_to_finalreport \
path_to_save_matrix_in_tab_format
```
2, tansform tab format matrix to .rds format
```sh
./tranform_from_tab_to_rds.R path_input path_output chr_start chr_end
```

### prepare data for IPQ

iPattern
```sh
perl finalreport_to_iPattern.pl \
-prefix path_to_save_ipattern_input_file \
-suffix .txt \
path_to_finalreport
```

PennCNV
```sh
perl finalreport_to_PennCNV.pl \
-prefix path_to_save_penncnv_input_file \
-suffix .txt \
path_to_finalreport
```

QuantiSNP
```sh
perl finalreport_to_QuantiSNP.pl \
-prefix path_to_save_quantisnp_input_file \
-suffix .txt \
path_to_finalreport
```

### call PennCNV

Here, calling PennCNV including following 5 steps:

prepare files containing SNP.pfb and SNp.gcmodel for running PennCNV:
```sh
step.0.prepare.files.sh contains all commands 
```

run PennCNV through submiting jobs:
```sh 
./step.1.run.PennCNV.jobs.R \
-a path/to/dat \
-b path/to/res_job \
-c path/to/SNP.pfb \
-d path/to/SNP.gcmodel \
-e path/to/penncnv/2011Jun16/lib/hhall.hmm
```

check jobs and resubmit unfinishing callings:
```sh
./step.2.check.PennCNV.R \
-a path/to/dat \
-b path/to/res_job \
-c path/to/SNP.pfb \
-d path/to/SNP.gcmodel \
-e path/to/penncnv/2011Jun16/lib/hhall.hmm
```

combine all PennCNV calling results (sample based):
```sh
perl step.3.combine.PennCNV.pl \
--in_dir path/to/res/ \
--out_dir path/to/output/
```

clean PennCNV and generate final results:
```sh
./step.4.clean.PennCNV.R \
-i path/to/result/folder \
-p path/to/SNP.pfb \
-n saving_name
```

### call QuantiSNP

Here, calling QuantiSNP including 3 steps:

prepare QuantiSNP and submit jobs:
```sh
./step.1.prepare.QuantiSNP.R \
-i path/to/data/folder \
-o path/to/result/folder
```
check jobs and resubmit:
```sh
./step.2.check_QuantiSNP.R \
-d path/to/data/folder \
-r path/to/callingCNV/folder 
```

combine CNV calling results:
running this script, you need to add "in_dir", "out_dir", "out_file" information in the script.
```sh
perl step.3.combine.QuantiSNP.pl
```


### call iPattern

sample script for calling iPattern:
```sh
script "run.R" contains all needed running command.
```


## 02 batch effect

### PCA on snp-level LRR statics from randomly select 100000 snps

```sh
./step.1.randomly.select.snp.R file_snps path_output

perl step.2.generate.snps.LRR.matrix.pl (add "file_snps_selected", "finalreport", "file_matrix_LRR")

step.3.pca.new.R ( add "filename_matrix", "path_input")
``` 

### PCA on sample-level iPattern, PennCNV and QuantiSNP generated 10 statics

```sh

generate iPattern, PennCNV and QuantiSNP calling sample level statics data using step.1.generate.data.R script

do PCA using step.2.pca.R
```

## 03 CNVR

contain one method and IPQ merge

## 04 genotype

genotyping for all CNVRs


## 05 boundary refinement

boundary refinement

```sh
./boundary_refinement.R -c 1 \
-r path/to/cnvr.rds -l path/to/chr-lrr-matrix \
-p path/to/snp.pfb -m path/to/chr-centromere.rds \
-g path/to/save/png -o path/to/save/detail-results \
-s path/to/rcpp
```
you need to source following script.

```r
refine_step1.cpp
```

## 06 result

summary compare results

### compare duplicate pairs consistency rate
