#!/bin/bash
y=5
until [ $y -lt 1 ]
do
	x=5
	while [ $x -ge $y ]
	do
	echo -n $x
	let x--
	done
echo
let y--
done
