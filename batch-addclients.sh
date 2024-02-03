#!/bin/bash

for CLIENT in $(cat $1);
do 
  echo $CLIENT
  bash ./addclient.sh $CLIENT

done