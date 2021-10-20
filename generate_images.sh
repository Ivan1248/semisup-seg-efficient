#!/bin/bash

set -e

cd "$(pwd | grep -o '.*/scripts')"  # moves to the directory that contains the run.py script

output_path=/tmp/semisup  # where the output is to be saved
n=12  # number of examples

echo "Reproducing the figure with outputs of models trained on half-resolution Cityscapes train with 1/4 of the labels..."

echo "1. Checking whether there are trained parameters, training if there are no..."

# common arguments that identify the algorithm
args_robust=( "train,train_u,test:Cityscapes(downsampling=2){train,val}:(folds(d[0].permute(53),4)[0],d[0],d[1])" "standardize(cityscapes_mo)" "SwiftNet,backbone_f=t(depth=18)" "ext.configs.swiftnet_cityscapes_halfres,ext.configs.semisup_cons_phtps20,train_step=ext.steps.MeanTeacherStep(alpha=0.5),lr_scheduler_f=lr.QuarterCosLR,epoch_count=800,batch_size=[8,8]" --params "resnet:backbone->backbone.backbone:resnet18" )
args_baseline=( "train,test:Cityscapes(downsampling=2){train,val}:(d[0].permute(53)[:744],d[1])" "standardize(cityscapes_mo)" "SwiftNet,backbone_f=t(depth=18)" "ext.configs.swiftnet_cityscapes_halfres,lr_scheduler_f=lr.QuarterCosLR,epoch_count=800,batch_size=8" --params "resnet:backbone->backbone.backbone:resnet18" )

# training and testing commands
train_robust=( python run.py train ${args_robust[@]} )
train_baseline=( python run.py train ${args_baseline[@]} )
test_robust=( python run.py test ${args_robust[@]} )
test_baseline=( python run.py test ${args_baseline[@]} )

# runs training or evaluates performance if it is already complete
${train_baseline[@]} --no_init_eval --no_train_eval -r ?
${train_robust[@]} --no_init_eval --no_train_eval -r ?

echo "2. Generating clean and perturbed examples in ${output_path} to be used by generate_results..."
${test_robust[@]} -r --module "papers.semisup_efficient_mva21.generate_images:generate_inputs,e,n=${n},dir='${output_path}'"

echo "3. Generating result visualizations (semi-supervised MT-PhTPS)..."
${test_robust[@]} -r --module "papers.semisup_efficient_mva21.generate_images:generate_results,e,dir='${output_path}'"

echo "4. Generating result visualizations (supervised baseline)..."
${test_baseline[@]} -r --module "papers.semisup_efficient_mva21.generate_images:generate_results,e,dir='${output_path}',suffix='sup'"

echo "5. Producing LaTeX code for the figure..."
${test_baseline[@]} -r --module "papers.semisup_efficient_mva21.generate_images:latex_grid,n=${n},dir='${output_path}'"

echo Output path: $output_path