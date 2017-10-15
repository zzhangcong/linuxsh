#!/bin/bash
y=5
while [ $y -ge 1 ]
do
	for (( x=5;$x >= $y;x-- ))
	do
	echo -n $x
	done 
echo
let  y--
done
