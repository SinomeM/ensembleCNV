#!/bin/bash

## create new project
wkdir=$1

## create working directory
mkdir -p $wkdir

## data: final report, sample table, centromere position, and duplicate pairs [optional]
## put in this directory
mkdir -p ${wkdir}/data

## 01_initial_call
cp -ru ./01_initial_call $wkdir
mkdir -p ${wkdir}/01_initial_call/finalreport_to_matrix_LRR_and_BAF/RDS

mkdir -p ${wkdir}/01_initial_call/run_iPattern/data
mkdir -p ${wkdir}/01_initial_call/run_iPattern/data_aux
mkdir -p ${wkdir}/01_initial_call/run_iPattern/results

mkdir -p ${wkdir}/01_initial_call/run_PennCNV/data
mkdir -p ${wkdir}/01_initial_call/run_PennCNV/data_aux
mkdir -p ${wkdir}/01_initial_call/run_PennCNV/results

mkdir -p ${wkdir}/01_initial_call/run_QuantiSNP/data
mkdir -p ${wkdir}/01_initial_call/run_QuantiSNP/results
mkdir -p ${wkdir}/01_initial_call/run_QuantiSNP/results/res

## 02_batch_effect
cp -ru ./02_batch_effect $wkdir

## 03_create_CNVR      
cp -ru ./03_create_CNVR $wkdir

echo "New project directory has been created at: $wkdir"
echo "Please put (or create symbolic link to) input data in the directory: $wkdir/data"

